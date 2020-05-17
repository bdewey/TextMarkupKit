// 

import Foundation

/// A function that returns a text replacement for a node in the syntax tree.
public typealias ReplacementFunction = (Node, Int) -> [unichar]?

public struct ReplacementDescription {
  let replacedRange: NSRange
  let changeInLength: Int
}

/// Gives the ability to record "text replacements" in the syntax tree and apply those to text.
/// Example use case: Replace a "soft tab" (some sort of whitespace) with an actual "\t" (which the layout system knows gets aligned to
/// tab-stops)
public extension Node {
  /// Walks the syntax tree looking for nodes that match types in `replacementFunctions` and records the replacement
  /// in the syntax tree.
  ///
  /// This must be called on only the root node of the syntax tree.
  ///
  /// - returns: Descriptions of all newly created replacements.
  func computeTextReplacements(
    using replacementFunctions: [NodeType: ReplacementFunction]
  ) -> [ReplacementDescription] {
    var replacements: [ReplacementDescription] = []
    self.computeTextReplacements(using: replacementFunctions, startingIndex: 0, replacements: &replacements)
    return replacements
  }

  func makeArrayReplacementCollection() -> ArrayReplacementCollection<unichar> {
    let arrayReplacementCollection = ArrayReplacementCollection<unichar>()
    addReplacements(to: arrayReplacementCollection, location: 0)
    return arrayReplacementCollection
  }

  private func addReplacements(to collection: ArrayReplacementCollection<unichar>, location: Int) {
    guard hasTextReplacement else { return }
    if let replacement = textReplacement {
      try! collection.insert(replacement, at: location ..< location + length)
      return
    }
    var location = location
    for child in children {
      child.addReplacements(to: collection, location: location)
      location += child.length
    }
  }

  /// Applies all replacements recorded in this node of the syntax tree to `array`
  ///
  /// Call only on the root node of the syntax tree.
  ///
  /// - parameter startingIndex: The starting index in `array` corresponding to this node.
  func applyTextReplacements(startingIndex: Int, to array: inout [unichar]) {
    guard hasTextReplacement else { return }
    if let replacement = textReplacement {
      array.replaceSubrange(startingIndex ..< startingIndex + length, with: replacement)
    }
    for (child, index) in childrenAndOffsets(startingAt: startingIndex).reversed() {
      child.applyTextReplacements(startingIndex: index, to: &array)
    }
  }

  /// Given an index into an unmodified unichar array, return an index that corresponds to the same location after performing
  /// the replacements encoded in the tree.
  ///
  /// Call only on the root node of the syntax tree.
  ///
  /// - parameter index: The index into the parsed contents represented by this syntax tree
  /// - returns: An index that corresponds to the same location after applying any text replacements encoded in the syntax tree.
  func indexAfterReplacements(_ index: Int) -> Int {
    return indexAfterReplacements(index, nodeLocation: 0, totalReplacementShift: 0)
  }

  /// Given an index into an array that was modified by applying the replacements encoded in this syntax tree, return an index that
  /// corresponds to the same location in the original parsed text.
  ///
  /// Call only on the root node of the syntax tree.
  ///
  /// - parameter index: The index into the parsed contents represented by this syntax tree
  /// - returns: An index that corresponds to the same location after applying any text replacements encoded in the syntax tree.
  func indexBeforeReplacements(_ index: Int) -> Int {
    return indexBeforeReplacements(index, nodeLocation: 0)
  }

  func rangeAfterReplacements(_ range: NSRange) -> NSRange {
    let lowerBound = indexAfterReplacements(range.lowerBound)
    let upperBound = indexAfterReplacements(range.upperBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  func rangeBeforeReplacements(_ range: NSRange) -> NSRange {
    let lowerBound = indexBeforeReplacements(range.lowerBound)
    let upperBound = indexBeforeReplacements(range.upperBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  /// True if either this node or any of its descendents contains a `textReplacement`
  private(set) var hasTextReplacement: Bool {
    get {
      self[NodeHasTextReplacementKey.self] ?? false
    }
    set {
      self[NodeHasTextReplacementKey.self] = newValue
    }
  }
}

// MARK: - Private

private extension Node {
  /// Recursive helper for computing text replacements.
  func computeTextReplacements(
    using replacementFunctions: [NodeType: ReplacementFunction],
    startingIndex: Int,
    replacements: inout [ReplacementDescription]
  ) {
    // Incremental parsing support! If we've already computed replacements for this node we don't
    // have to do anything new.
    guard self[NodeHasTextReplacementKey.self] == nil else {
      return
    }

    // If we are supposed to replace this node, we replace this node and don't even
    // consider children. They're replaced too!
    if let replacementFunction = replacementFunctions[type], let textReplacement = replacementFunction(self, startingIndex) {
      self.textReplacement = textReplacement
      hasTextReplacement = true
      textReplacementLengthChange = textReplacement.count - length

      let replacement = ReplacementDescription(
        replacedRange: NSRange(location: startingIndex, length: length),
        changeInLength: textReplacementLengthChange
      )
      replacements.append(replacement)
      return
    }

    var hasTextReplacement = false
    var totalLengthChange = 0
    var index = startingIndex
    for child in children {
      child.computeTextReplacements(using: replacementFunctions, startingIndex: index, replacements: &replacements)
      index += child.length
      hasTextReplacement = hasTextReplacement || child.hasTextReplacement
      totalLengthChange += child.textReplacementLengthChange
    }
    self.hasTextReplacement = hasTextReplacement
    textReplacementLengthChange = totalLengthChange
  }

  func indexAfterReplacements(_ index: Int, nodeLocation: Int, totalReplacementShift: Int) -> Int {
    var totalReplacementShift = totalReplacementShift
    var nodeLocation = nodeLocation
    if textReplacement != nil, index < nodeLocation + length {
      // index falls within the range of a node that has a replacement, so it maps to the beginning
      // of the replaced text.
      return nodeLocation + totalReplacementShift
    }
    for child in children {
      if index < nodeLocation + child.length {
        return child.indexAfterReplacements(index, nodeLocation: nodeLocation, totalReplacementShift: totalReplacementShift)
      } else {
        totalReplacementShift += child.textReplacementLengthChange
        nodeLocation += child.length
      }
    }
    return index + totalReplacementShift
  }

  func indexBeforeReplacements(_ index: Int, nodeLocation: Int) -> Int {
    var index = index
    var offset = nodeLocation
    if textReplacement != nil, index < nodeLocation + length + textReplacementLengthChange {
      // If `index` falls within the range of this node and we have a replacement, then
      // its location-before-replacement was the start of this node.
      return nodeLocation
    }
    for child in children {
      if index < offset + child.length + child.textReplacementLengthChange {
        return child.indexBeforeReplacements(index, nodeLocation: offset)
      } else {
        index -= child.textReplacementLengthChange
        offset += child.length
      }
    }
    return index
  }

  /// If non-nil, then the contents the parsed contents covered by this node should be replaced by `textReplacement` on display.
  var textReplacement: [unichar]? {
    get {
      self[NodeTextReplacementKey.self]
    }
    set {
      self[NodeTextReplacementKey.self] = newValue
    }
  }

  /// How much the length of the
  var textReplacementLengthChange: Int {
    get {
      self[NodeTextReplacementLengthChange.self] ?? 0
    }
    set {
      self[NodeTextReplacementLengthChange.self] = newValue
    }
  }

  func childrenAndOffsets(startingAt offset: Int) -> [(child: Node, offset: Int)] {
    var offset = offset
    var results = [(child: Node, offset: Int)]()
    for child in children {
      results.append((child: child, offset: offset))
      offset += child.length
    }
    return results
  }
}

// MARK: - Property keys

private enum NodeTextReplacementKey: NodePropertyKey {
  typealias Value = [unichar]
  static let key = "textReplacement"
}

private enum NodeHasTextReplacementKey: NodePropertyKey {
  typealias Value = Bool
  static let key = "hasTextReplacement"
}

private enum NodeTextReplacementLengthChange: NodePropertyKey {
  typealias Value = Int
  static let key = "textReplacementLengthChange"
}
