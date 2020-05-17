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
import TextMarkupKit
import XCTest

private func formatTab(
  node: Node,
  startIndex: Int
) -> [unichar] {
  return Array("\t".utf16)
}

private func formatHeader(
  node: Node,
  startIndex: Int
) -> [unichar] {
  return Array("H\(node.length)".utf16)
}

final class IncrementalParsingTextStorageTests: XCTestCase {
  var textStorage: IncrementalParsingTextStorage!

  override func setUp() {
    super.setUp()
    #if !os(macOS)
      let formattingFunctions: [NodeType: FormattingFunction] = [
        .emphasis: { $1.italic = true },
        .header: { $1.fontSize = 24 },
        .list: { $1.listLevel += 1 },
        .strongEmphasis: { $1.bold = true },
      ]
      var defaultAttributes: AttributedStringAttributes = [:]
      defaultAttributes.font = UIFont.preferredFont(forTextStyle: .body)
      defaultAttributes.color = .label
      defaultAttributes.headIndent = 28
      defaultAttributes.firstLineHeadIndent = 28
    #else
      let formattingFunctions: [NodeType: FormattingFunction] = [:]
      let defaultAttributes: AttributedStringAttributes = [:]
    #endif
    textStorage = IncrementalParsingTextStorage(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      formattingFunctions: formattingFunctions,
      replacementFunctions: [.softTab: formatTab]
    )
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

  func testEditMakesMinimumAttributeChange() {
    assertDelegateMessages(
      for: [
        .append(text: "# Header\n\nParagraph with almost **bold*\n\nUnrelated"),
        .replace(range: NSRange(location: 39, length: 0), replacement: "*"),
      ],
      are: Array([
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 50), changeInLength: 50),
        DelegateMessage.messagePair(editedMask: [.editedAttributes, .editedCharacters], editedRange: NSRange(location: 10, length: 31), changeInLength: 1),
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
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 17), changeInLength: 10),
      ].joined())
    )
  }

  func testAppendWithVariableLengthReplacement() {
    assertDelegateMessages(
      for: [.append(text: "# Hello"), .append(text: ", world!\n\n")],
      are: Array([
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 7), changeInLength: 7),
        DelegateMessage.messagePair(editedMask: [.editedCharacters, .editedAttributes], editedRange: NSRange(location: 0, length: 17), changeInLength: 10),
      ].joined()),
      replacementFunctions: [.softTab: formatTab, .headerDelimiter: formatHeader]
    )
  }

  func testReplacementsAffectStringsButNotRawText() {
    textStorage.append(NSAttributedString(string: "# This is a heading\n\nAnd this is a paragraph"))
    XCTAssertEqual(textStorage.string, "#\tThis is a heading\n\nAnd this is a paragraph")
    XCTAssertEqual(textStorage.rawText, "# This is a heading\n\nAnd this is a paragraph")
  }

  /// This used to crash because I was inproperly managing the blank_line nodes when coalescing them. It showed up when
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

  func testVariableLengthReplacement() {
    let variableTextStorage = IncrementalParsingTextStorage(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: [:],
      formattingFunctions: [.header: { $1.fontSize = 24 }],
      replacementFunctions: [.softTab: formatTab, .headerDelimiter: formatHeader]
    )
    variableTextStorage.setAttributedString(NSAttributedString(string: "### What happens if I set Markdown through this?"))
    let rawText = "# Main heading\n\n## Second heading\n\n### Third level header"
    variableTextStorage.setAttributedString(
      NSAttributedString(string: rawText)
    )
    XCTAssertEqual(variableTextStorage.string, "H1\tMain heading\n\nH2\tSecond heading\n\nH3\tThird level header")
    variableTextStorage.replaceCharacters(in: NSRange(location: 3, length: 4), with: "Top")
    XCTAssertEqual(variableTextStorage.string, "H1\tTop heading\n\nH2\tSecond heading\n\nH3\tThird level header")
    variableTextStorage.replaceCharacters(in: NSRange(location: 19, length: 6), with: "2nd")
    XCTAssertEqual(variableTextStorage.string, "H1\tTop heading\n\nH2\t2nd heading\n\nH3\tThird level header")
    variableTextStorage.replaceCharacters(in: NSRange(location: variableTextStorage.string.count, length: 0), with: "!!")
    XCTAssertEqual(variableTextStorage.string, "H1\tTop heading\n\nH2\t2nd heading\n\nH3\tThird level header!!")
    variableTextStorage.replaceCharacters(in: NSRange(location: 16, length: 0), with: "Just inserting a plain paragraph.\n\n")
    XCTAssertEqual(variableTextStorage.string, "H1\tTop heading\n\nJust inserting a plain paragraph.\n\nH2\t2nd heading\n\nH3\tThird level header!!")
  }

  #if !os(macOS)
    /// Use the iOS convenience methods for manipulated AttributedStringAttributes to test that attributes are properly
    /// applied to ranges of the string.
    func testFormatting() {
      textStorage.append(NSAttributedString(string: "# Header\n\nParagraph with almost **bold*\n\nUnrelated"))
      var range = NSRange(location: NSNotFound, length: 0)
      let attributes = textStorage.attributes(at: 0, effectiveRange: &range)
      var expectedAttributes: AttributedStringAttributes = [:]
      expectedAttributes.fontSize = 24
      XCTAssertEqual(expectedAttributes.font, attributes.font)
    }
  #endif
}

// MARK: - Private

private extension IncrementalParsingTextStorageTests {
  func assertDelegateMessages(
    for operations: [TextOperation],
    are expectedMessages: [DelegateMessage],
    replacementFunctions: [NodeType: ReplacementFunction] = [.softTab: formatTab],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let textStorage = IncrementalParsingTextStorage(grammar: MiniMarkdownGrammar(), defaultAttributes: [:], formattingFunctions: [:], replacementFunctions: replacementFunctions)
    let miniMarkdownRecorder = TextStorageMessageRecorder()
    textStorage.delegate = miniMarkdownRecorder
    let plainTextStorage = NSTextStorage()
    let plainTextRecorder = TextStorageMessageRecorder()
    plainTextStorage.delegate = plainTextRecorder
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
//    XCTAssertEqual(textStorage.string, plainTextStorage.string, file: file, line: line)
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
