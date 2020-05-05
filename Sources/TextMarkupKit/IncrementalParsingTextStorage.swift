//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

#if !os(macOS)
  import UIKit
#else
  import AppKit
#endif

/// Just a handy alias for NSAttributedString attributes
public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]

/// A function that modifies NSAttributedString attributes based the syntax tree.
public typealias FormattingFunction = (Node, inout AttributedStringAttributes) -> Void

/// A function that overlays replacements...
public typealias ReplacementFunction = (Node, Int, ArrayReplacementCollection<unichar>) -> Int

/// Uses an `IncrementalParsingBuffer` to implement `NSTextStorage`.
public final class IncrementalParsingTextStorage: NSTextStorage {
  public init(
    grammar: PackratGrammar,
    defaultAttributes: AttributedStringAttributes,
    formattingFunctions: [NodeType: FormattingFunction],
    replacementFunctions: [NodeType: ReplacementFunction]
  ) {
    self.defaultAttributes = defaultAttributes
    self.formattingFunctions = formattingFunctions
    self.replacementFunctions = replacementFunctions
    self.buffer = IncrementalParsingBuffer("", grammar: grammar)
    super.init()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  #if os(macOS)
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
      fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
  #endif

  // MARK: - Stored properties

  private let buffer: IncrementalParsingBuffer
  private let defaultAttributes: AttributedStringAttributes
  private let formattingFunctions: [NodeType: FormattingFunction]
  private let replacementFunctions: [NodeType: ReplacementFunction]
  private let replacementTable = ArrayReplacementCollection<unichar>()

  // MARK: - Public

  /// The character contents as a single String value.
  // TODO: Memoize
  public override var string: String {
    var chars = buffer[0...]
    for replacement in replacementTable.replacements(in: 0...).reversed() {
      chars.replaceSubrange(replacement.range, with: replacement.elements)
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  /// Replaces the characters in the given range with the characters of the given string.
  public override func replaceCharacters(in range: NSRange, with str: String) {
    let range = replacementTable.physicalRange(for: range)
    var changedAttributesRange: Range<Int>?
    beginEditing()
    replacementTable.removeReplacements(overlapping: range.lowerBound ..< range.upperBound)
    replacementTable.offsetReplacements(after: range.lowerBound, by: str.utf16.count - range.length)
    buffer.replaceCharacters(in: range, with: str)
    edited([.editedCharacters], range: range, changeInLength: str.utf16.count - range.length)
    if case .success(let node) = buffer.result {
      applyAttributes(
        to: node,
        attributes: defaultAttributes,
        startingIndex: 0,
        leafNodeRange: &changedAttributesRange
      )
    }
    // Deliver delegate messages
    if let range = changedAttributesRange {
      edited([.editedAttributes], range: NSRange(location: range.lowerBound, length: range.count), changeInLength: 0)
      for replacement in replacementTable.replacements(in: range) {
        edited(
          [.editedCharacters],
          range: NSRange(location: replacement.range.lowerBound, length: replacement.range.count), changeInLength: replacement.changeInLength
        )
      }
    }
    endEditing()
  }

  /// Returns the attributes for the character at a given index.
  /// - Parameters:
  ///   - location: The index for which to return attributes. This value must lie within the bounds of the receiver.
  ///   - range: Upon return, the range over which the attributes and values are the same as those at index. This range isn’t necessarily the maximum range covered, and its extent is implementation-dependent.
  /// - Returns: The attributes for the character at index.
  public override func attributes(
    at location: Int,
    effectiveRange range: NSRangePointer?
  ) -> [NSAttributedString.Key: Any] {
    guard let tree = try? buffer.result.get() else {
      range?.pointee = NSRange(location: 0, length: buffer.count)
      return defaultAttributes
    }
    let location = replacementTable.physicalIndex(for: location)
    // Crash on invalid location or if I didn't set attributes (shouldn't happen?)
    let (leaf, startIndex) = try! tree.leafNode(containing: location)
    range?.pointee = NSRange(location: startIndex, length: leaf.length)
    return leaf.attributedStringAttributes!
  }

  /// Sets the attributes for the characters in the specified range to the specified attributes.
  /// - Parameters:
  ///   - attrs: A dictionary containing the attributes to set.
  ///   - range: The range of characters whose attributes are set.
  public override func setAttributes(
    _ attrs: [NSAttributedString.Key: Any]?,
    range: NSRange
  ) {
    // TODO. Maybe just ignore? But this is how emojis and misspellings get formatted
    // by the system.
  }

  // MARK: - Private

  /// Associates AttributedStringAttributes with this part of the syntax tree.
  func applyAttributes(
    to node: Node,
    attributes: AttributedStringAttributes,
    startingIndex: Int,
    leafNodeRange: inout Range<Int>?
  ) {
    // If we already have attributes we don't need to do anything else.
    guard node[NodeAttributesKey.self] == nil else {
      return
    }
    var attributes = attributes
    formattingFunctions[node.type]?(node, &attributes)
    replacementTable.removeReplacements(overlapping: startingIndex ..< startingIndex + node.length)
    if let replacementFunction = replacementFunctions[node.type] {
      let replacedLength = replacementFunction(node, startingIndex, replacementTable)
      edited([.editedCharacters], range: NSRange(location: startingIndex, length: node.length), changeInLength: replacedLength - node.length)
    }
    node[NodeAttributesKey.self] = attributes
    var childLength = 0
    if node.children.isEmpty {
      // We are a leaf. Adjust leafNodeRange.
      let lowerBound = min(startingIndex, leafNodeRange?.lowerBound ?? Int.max)
      let upperBound = max(startingIndex + node.length, leafNodeRange?.upperBound ?? Int.min)
      leafNodeRange = lowerBound ..< upperBound
    }
    for child in node.children {
      applyAttributes(
        to: child,
        attributes: attributes,
        startingIndex: startingIndex + childLength,
        leafNodeRange: &leafNodeRange
      )
      childLength += child.length
    }
  }
}

/// Key for storing the string attributes associated with a node.
private struct NodeAttributesKey: NodePropertyKey {
  typealias Value = AttributedStringAttributes

  static let key = "attributes"
}

private extension Node {
  /// The attributes associated with this node, if set.
  var attributedStringAttributes: AttributedStringAttributes? {
    get {
      self[NodeAttributesKey.self]
    }
    set {
      self[NodeAttributesKey.self] = newValue
    }
  }
}
