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

final class PerformanceTests: XCTestCase {
  let pieceTable = PieceTable(
    String(repeating: TestStrings.markdownCanonical, count: 10)
  )

  func testCustomProcessor() {
    measure {
      let tree = DocumentParser.miniMarkdown.parse(textBuffer: pieceTable, position: 0)
      if tree.range.endIndex != pieceTable.endIndex {
        let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'")
      }
    }
  }

  func testPackratParser() {
    let parser = PackratParser(buffer: pieceTable, grammar: JustTextGrammar.shared)
    measure {
      do {
        _ = try parser.parse()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testMiniMarkdownParser() {
    let grammar = MiniMarkdownGrammar()
    measure {
      do {
        let parser = PackratParser(buffer: pieceTable, grammar: grammar)
        _ = try parser.parse()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
