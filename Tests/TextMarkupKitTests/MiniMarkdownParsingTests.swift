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

struct ParsingTestCase {
  let input: String
  let compactStructure: String

  static func expect(_ compactStructure: String, for input: String) -> ParsingTestCase {
    ParsingTestCase(input: input, compactStructure: compactStructure)
  }
}

final class MiniMarkdownParsingTests: XCTestCase {
  let testCases: [String: ParsingTestCase] = [
//    "headerAndBody": ParsingTestCase(input: """
//    # This is a header
//
//    And this is a body.
//    The two lines are part of the same paragraph.
//
//    The line break indicates a new paragraph.
//
//    """, compactStructure: "(document (header delimiter text) blank_line (paragraph text) blank_line (paragraph text))"),
//
    "justEmphasis": ParsingTestCase(input: "*This is emphasized text.*", compactStructure: "(document (paragraph (emphasis delimiter text delimiter)))"),
//    "textWithEmphasis":
//      .expect("(document (paragraph text (emphasis delimiter text delimiter)))", for: "This is text with *emphasis.*"),
//    "textWithBold":
//      .expect("(document (paragraph text (strong_emphasis delimiter text delimiter) text))", for: "This is text with **bold**."),
//    "textAndHeader": .expect("(document (paragraph text) (header delimiter text))", for: "Text\n# Heading"),
//    "textAndCode": .expect("(document (paragraph text (code delimiter text delimiter) text))", for: "This is text with `code`."),
//    "headersHaveFormatting": .expect("(document (heading delimiter text (emphasis delimiter text delimiter)))", for: "# This is a heading with *emphasis*"),
  ]

  func __testOldParser() {
    runTests(on: DocumentParser.miniMarkdown, named: "old")
  }

  func testNewParser() {
    runTests(on: MiniMarkdownRecognizer(), named: "new")
  }

  func runTests(on parser: Parser, named parserName: String) {
    for (name, testCase) in testCases {
      let pieceTable = PieceTable(testCase.input)
      let tree = parser.parse(textBuffer: pieceTable, position: 0)
      if tree.range.endIndex != pieceTable.endIndex {
        let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
        XCTFail("Test case \(parserName).\(name): Unparsed text = '\(unparsedText.debugDescription)'")
      }
      if testCase.compactStructure != tree.compactStructure {
        print("### Failure: \(parserName).\(name)")
        print("Got:      " + tree.compactStructure)
        print("Expected: " + testCase.compactStructure)
        print(tree.debugDescription(withContentsFrom: pieceTable))
      }
      XCTAssertEqual(tree.compactStructure, testCase.compactStructure, "Test case \(parserName).\(name), unexpected structure")
    }
  }
}
