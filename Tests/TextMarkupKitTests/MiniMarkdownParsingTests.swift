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
@testable import TextMarkupKit
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
    "headerAndBody": ParsingTestCase(input: """
    # This is a header

    And this is a body.
    The two lines are part of the same paragraph.

    The line break indicates a new paragraph.

    """, compactStructure: "(document (header delimiter text) blank_line (paragraph text) blank_line (paragraph text))"),

    "justEmphasis": ParsingTestCase(input: "*This is emphasized text.*", compactStructure: "(document (paragraph (emphasis delimiter text delimiter)))"),
    "textWithEmphasis":
      .expect("(document (paragraph text (emphasis delimiter text delimiter)))", for: "This is text with *emphasis.*"),
    "textWithBold":
      .expect("(document (paragraph text (strong_emphasis delimiter text delimiter) text))", for: "This is text with **bold**."),
    "textAndHeader": .expect("(document (paragraph text) (header delimiter text))", for: "Text\n# Heading"),
    "textAndCode": .expect("(document (paragraph text (code delimiter text delimiter) text))", for: "This is text with `code`."),
  ]

  func testPackratOnHeaderAndBody() {
    for (name, testCase) in testCases {
      do {
        let pieceTable = PieceTable(testCase.input)
        let grammar = MiniMarkdownGrammar()
        let parser = PackratParser(buffer: pieceTable, grammar: grammar)
        let tree = try parser.parse()
        if tree.range.endIndex != pieceTable.endIndex {
          let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
          XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'")
        }
        if testCase.compactStructure != tree.compactStructure {
          print("### Failure: \(name)")
          print("Got:      " + tree.compactStructure)
          print("Expected: " + testCase.compactStructure)
          print("\n")
          print(tree.debugDescription(withContentsFrom: pieceTable))
          print("\n\n\n")
        }
        XCTAssertEqual(tree.compactStructure, testCase.compactStructure, "Test case \(name), unexpected structure")
      } catch {
        XCTFail("Unexpected error on test case \(name): \(error)")
      }
    }
  }

  func testFile() {
    let pieceTable = PieceTable(TestStrings.markdownCanonical)
    let grammar = MiniMarkdownGrammar()
    let parser = PackratParser(buffer: pieceTable, grammar: grammar)
    do {
      _ = try parser.parse()
    } catch {
      XCTFail("Unexpected error: \(error)")
      print(parser.traceBuffer)
    }
  }
}
