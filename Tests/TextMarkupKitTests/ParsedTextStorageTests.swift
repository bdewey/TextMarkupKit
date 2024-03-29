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

import Foundation
import ObjectiveCTextStorageWrapper
import TextMarkupKit
import XCTest

final class ParsedTextStorageTests: XCTestCase {
  var textStorage: ObjectiveCTextStorageWrapper!

  override func setUp() {
    super.setUp()
    let formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: AnyParsedAttributedStringFormatter { $0.italic = true },
      .header: AnyParsedAttributedStringFormatter { $0.fontSize = 24 },
      .list: AnyParsedAttributedStringFormatter { $0.listLevel += 1 },
      .strongEmphasis: AnyParsedAttributedStringFormatter { $0.bold = true },
      .softTab: AnyParsedAttributedStringFormatter(substitution: "\t"),
      .image: AnyParsedAttributedStringFormatter(substitution: "\u{fffc}"),
    ]
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)
    let storage = ParsedAttributedString(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )
    textStorage = ObjectiveCTextStorageWrapper(storage: storage)
  }

  func testCanStoreAndRetrievePlainText() {
    textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Hello, world!")
    XCTAssertEqual(textStorage.string, "Hello, world!")
  }

  func testAppendDelegateMessages() {
    assertDelegateMessages(
      for: [.append(text: "Hello, world")],
      are: DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 12), changeInLength: 12)
    )
  }

  // TODO: With the new method of determining if attributes have changed, this is no longer an
  // effective test to ensure that incremental parsing is happening.
  func testEditMakesMinimumAttributeChange() {
    assertDelegateMessages(
      for: [
        .append(text: "# Header\n\nParagraph with almost **bold*\n\nUnrelated"),
        .replace(range: NSRange(location: 39, length: 0), replacement: "*"),
      ],
      are: Array([
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 50), changeInLength: 50),
        DelegateMessage.messagePair(editedMask: [.editedAttributes, .editedCharacters], editedRange: NSRange(location: 39, length: 1), changeInLength: 1),
      ].joined())
    )
  }

  func testTabSubstitutionHappens() {
    textStorage.append(NSAttributedString(string: "# This is a heading\n\nAnd this is a paragraph"))
    XCTAssertEqual(textStorage.string, "#\tThis is a heading\n\nAnd this is a paragraph")
  }

  func testCanAppendToAHeading() {
    assertDelegateMessages(
      for: [.append(text: "# Hello"), .append(text: ", world!\n\n")],
      are: Array([
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 7), changeInLength: 7),
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 7, length: 10), changeInLength: 10),
      ].joined())
    )
  }

  // TODO: Figure out a way to get access to the raw string contents
//  func testReplacementsAffectStringsButNotRawText() {
//    textStorage.append(NSAttributedString(string: "# This is a heading\n\nAnd this is a paragraph"))
//    XCTAssertEqual(textStorage.string, "#\tThis is a heading\n\nAnd this is a paragraph")
//    XCTAssertEqual(textStorage.storage.rawString, "# This is a heading\n\nAnd this is a paragraph")
//  }

  /// This used to crash because I was inproperly managing the `blank_line` nodes when coalescing them. It showed up when
  /// re-using memoized results.
  func testReproduceTypingBug() {
    let initialString = "# Welcome to Scrap Paper.\n\n\n\n##\n\n"
    textStorage.append(NSAttributedString(string: initialString))
    let stringToInsert = " A second heading"
    var insertionPoint = initialString.utf16.count - 2
    for charToInsert in stringToInsert {
      let str = String(charToInsert)
      textStorage.replaceCharacters(in: NSRange(location: insertionPoint, length: 0), with: str)
      insertionPoint += 1
    }
    XCTAssertEqual(textStorage.string, "#\tWelcome to Scrap Paper.\n\n\n\n##\tA second heading\n\n")
  }

  func testEditsAroundImages() {
    let initialString = "Test ![](image.png) image"
    textStorage.append(NSAttributedString(string: initialString))
    XCTAssertEqual(textStorage.string.count, 12)
    textStorage.replaceCharacters(in: NSRange(location: 5, length: 0), with: "x")
    // We should now have one more character than we did previously
    XCTAssertEqual(textStorage.string.count, 13)
  }

  func testDeleteEverything() {
    let initialString = "Test ![](image.png) image"
    textStorage.append(NSAttributedString(string: initialString))
    XCTAssertEqual(textStorage.string.count, 12)
    textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.string.utf16.count), with: "")
    XCTAssertEqual(textStorage.string.count, 0)
  }

  #if !os(macOS)
    /// Use the iOS convenience methods for manipulated AttributedStringAttributes to test that attributes are properly
    /// applied to ranges of the string.
    func testFormatting() {
      textStorage.append(NSAttributedString(string: "# Header\n\nParagraph with almost **bold*\n\nUnrelated"))
      var range = NSRange(location: NSNotFound, length: 0)
      let descriptor = textStorage.attributes(at: 0, effectiveRange: &range)
      var expectedAttributes: AttributedStringAttributes = [:]
      expectedAttributes.fontSize = 24
      XCTAssertEqual(expectedAttributes.font, descriptor.font)
    }
  #endif
}

// MARK: - Private

private extension ParsedTextStorageTests {
  func assertDelegateMessages(
    for operations: [TextOperation],
    are expectedMessages: [DelegateMessage],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let textStorage = ObjectiveCTextStorageWrapper(
      storage: ParsedAttributedString(
        grammar: MiniMarkdownGrammar(),
        defaultAttributes: AttributedStringAttributesDescriptor(fontSize: 12),
        formatters: [.softTab: AnyParsedAttributedStringFormatter(substitution: "\t")]
      )
    )
    let miniMarkdownRecorder = TextStorageMessageRecorder()
    textStorage.delegate = miniMarkdownRecorder
    let plainTextStorage = NSTextStorage()
    for operation in operations {
      operation.apply(to: textStorage)
      operation.apply(to: plainTextStorage)
    }
    XCTAssertEqual(
      miniMarkdownRecorder.delegateMessages,
      expectedMessages,
      file: file,
      line: line
    )
    if textStorage.string != plainTextStorage.string {
      print(textStorage.string.debugDescription)
      print(plainTextStorage.string.debugDescription)
    }
  }
}

private enum TextOperation {
  case append(text: String)
  case replace(range: NSRange, replacement: String)

  func apply(to textStorage: NSTextStorage) {
    switch self {
    case .append(let str):
      textStorage.append(NSAttributedString(string: str))
    case .replace(let range, let replacement):
      textStorage.replaceCharacters(in: range, with: replacement)
    }
  }
}

#if !os(macOS)
  typealias EditActions = NSTextStorage.EditActions
#else
  typealias EditActions = NSTextStorageEditActions
#endif

struct DelegateMessage: Equatable {
  let message: String
  let editedMask: EditActions
  let editedRange: NSRange
  let changeInLength: Int

  static func messagePair(
    editedMask: EditActions,
    editedRange: NSRange,
    changeInLength: Int
  ) -> [DelegateMessage] {
    return ["willProcessEditing", "didProcessEditing"].map {
      DelegateMessage(
        message: $0,
        editedMask: editedMask,
        editedRange: editedRange,
        changeInLength: changeInLength
      )
    }
  }
}

final class TextStorageMessageRecorder: NSObject, NSTextStorageDelegate {
  public var delegateMessages: [DelegateMessage] = []

  func textStorage(
    _ textStorage: NSTextStorage,
    willProcessEditing editedMask: EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    delegateMessages.append(
      DelegateMessage(
        message: "willProcessEditing",
        editedMask: editedMask,
        editedRange: editedRange,
        changeInLength: delta
      )
    )
  }

  func textStorage(
    _ textStorage: NSTextStorage,
    didProcessEditing editedMask: EditActions,
    range editedRange: NSRange,
    changeInLength delta: Int
  ) {
    delegateMessages.append(
      DelegateMessage(
        message: "didProcessEditing",
        editedMask: editedMask,
        editedRange: editedRange,
        changeInLength: delta
      )
    )
  }
}
