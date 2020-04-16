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
    measure {
      do {
        let grammar = MiniMarkdownGrammar()
        let parser = PackratParser(buffer: pieceTable, grammar: grammar)
        _ = try parser.parse()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testPrintPieceTable() {
    let localPieceTable = PieceTable(
      String(repeating: TestStrings.markdownCanonical, count: 10)
    )
    let grammar = MiniMarkdownGrammar()
    let parser = PackratParser(buffer: localPieceTable, grammar: grammar)
    _ = try! parser.parse()
    let overreadRatio = String(format: "%.2f%%", 100.0 * ((Double(localPieceTable.charactersRead) / Double(localPieceTable.endIndex)) - 1))
    print("Overread ratio: \(overreadRatio)")
    print(localPieceTable)
    print(parser)
  }
}
