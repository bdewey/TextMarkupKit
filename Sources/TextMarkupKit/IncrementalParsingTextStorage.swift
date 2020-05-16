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

  // MARK: - Public

  private var memoizedString: String?

  /// The character contents as a single String value.
  // TODO: Memoize
  public override var string: String {
    if let memoizedString = memoizedString {
      return memoizedString
    }
    var chars = buffer[0...]
    if case .success(let node) = buffer.result {
      node.applyTextReplacements(startingIndex: 0, to: &chars)
    }
    let result = String(utf16CodeUnits: chars, count: chars.count)
    memoizedString = result
    return result
  }

  /// The character contents as a single String value without any text replacements applied.
  public var rawText: String {
    let chars = buffer[0...]
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  /// Replaces the characters in the given range with the characters of the given string.
  public override func replaceCharacters(in range: NSRange, with str: String) {
    memoizedString = nil
    var changedAttributesRange: Range<Int>?
    beginEditing()
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
    node.attributedStringAttributes = attributes
    if node.children.isEmpty {
      // We are a leaf. Adjust leafNodeRange.
      let lowerBound = min(startingIndex, leafNodeRange?.lowerBound ?? Int.max)
      let upperBound = max(startingIndex + node.length, leafNodeRange?.upperBound ?? Int.min)
      leafNodeRange = lowerBound ..< upperBound
    }
    var childLength = 0
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
private enum NodeAttributesKey: NodePropertyKey {
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
