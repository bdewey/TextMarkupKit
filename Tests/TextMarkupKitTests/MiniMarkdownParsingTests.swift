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
}

final class MiniMarkdownParsingTests: XCTestCase {
  let testCases: [String: ParsingTestCase] = [
    "headerAndBody": ParsingTestCase(input: """
    # This is a header

    And this is a body.
    The two lines are part of the same paragraph.

    The line break indicates a new paragraph.

    """, compactStructure: "(document ((header (delimiter text)) blank_line (paragraph (text)) blank_line (paragraph (text))))"),

    "standaloneEmphasis": ParsingTestCase(input: "*This is emphasized text.*", compactStructure: "(document ((paragraph ((emphasis (delimiter text delimiter))))))"),
  ]

  func testRunner() {
    for (name, testCase) in testCases {
      let pieceTable = PieceTable(testCase.input)
      let tree = DocumentParser.miniMarkdown.parse(textBuffer: pieceTable, position: 0)
      if tree.range.endIndex != pieceTable.endIndex {
        let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'")
      }
      XCTAssertEqual(tree.compactStructure, testCase.compactStructure, "Test case \(name), unexpected structure")
    }
  }
}
