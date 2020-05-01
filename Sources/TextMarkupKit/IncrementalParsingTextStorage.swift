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

/// Uses an `IncrementalParsingBuffer` to implement `NSTextStorage`.
public final class IncrementalParsingTextStorage: NSTextStorage {
  public init(
    grammar: PackratGrammar,
    defaultAttributes: AttributedStringAttributes,
    formattingFunctions: [NodeType: FormattingFunction]
  ) {
    self.defaultAttributes = defaultAttributes
    self.formattingFunctions = formattingFunctions
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

  // MARK: - Public

  /// The character contents as a single String value.
  // TODO: Memoize
  public override var string: String {
    buffer[0...]
  }

  /// Replaces the characters in the given range with the characters of the given string.
  public override func replaceCharacters(in range: NSRange, with str: String) {
    var changedAttributesRange: Range<Int>?
    buffer.replaceCharacters(in: range, with: str)
    if case .success(let node) = buffer.result {
      node.applyAttributes(
        attributes: defaultAttributes,
        formattingFunctions: formattingFunctions,
        startingIndex: 0,
        leafNodeRange: &changedAttributesRange
      )
    }
    // Deliver delegate messages
    edited([.editedCharacters], range: range, changeInLength: str.utf16.count - range.length)
    if let range = changedAttributesRange {
      edited([.editedAttributes], range: NSRange(location: range.lowerBound, length: range.count), changeInLength: 0)
    }
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
}
