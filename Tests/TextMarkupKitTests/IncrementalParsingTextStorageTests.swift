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

final class IncrementalParsingTextStorageTests: XCTestCase {
  var textStorage: IncrementalParsingTextStorage!

  override func setUp() {
    super.setUp()
    textStorage = IncrementalParsingTextStorage(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: [:],
      formattingFunctions: [:]
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
}

// MARK: - Private

private extension IncrementalParsingTextStorageTests {
  func assertDelegateMessages(
    for operations: [TextOperation],
    are expectedMessages: [DelegateMessage],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let textStorage = IncrementalParsingTextStorage(grammar: MiniMarkdownGrammar(), defaultAttributes: [:], formattingFunctions: [:])
//    let textStorage = NSTextStorage()
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
    XCTAssertEqual(textStorage.string, plainTextStorage.string, file: file, line: line)
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
