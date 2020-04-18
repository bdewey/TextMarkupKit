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

  /// Doesn't actually assert anything, but writes out performance counters for analysis if things get slow.
  func testPrintPieceTable() {
    // Ah, one of the problems I had is an old version of my grammar incorrectly parsed the canonical
    // markdown string -- it matched "**" literals that spanned multiple paragraphs. This meant that
    // in the broken version, it spent a big chunk of time parsing simpler rules (have I found the closing "**"?),
    // which ran fast. When I fixed this, suddenly a big chunk of text was now analyzed with more
    // complex rules ("which of the many available styles applies?"), which ran slower.
    //
    // For simplicity, it can help to analyze a long string of only "x" characters, which is just
    // a gigantic nonsensical paragraph.
    let localPieceTable = PieceTable(
//      String(repeating: TestStrings.markdownCanonical, count: 10)
      String(repeating: "x", count: 277930)
    )
    let grammar = MiniMarkdownGrammar()
    let parser = PackratParser(buffer: localPieceTable, grammar: grammar)
    _ = try! parser.parse()
    let overreadRatio = String(format: "%.2f%%", 100.0 * ((Double(localPieceTable.charactersRead) / Double(localPieceTable.endIndex)) - 1))
    print("Overread ratio: \(overreadRatio)")
    print(localPieceTable)
    print(parser)
    let counters = parser.grammar.start.allPerformanceCounters()
    let dedup = Dictionary(counters, uniquingKeysWith: { _, x in x })
    let topTotal = dedup.sorted(by: { $0.value.total > $1.value.total }).prefix(10).map(String.init(describing:)).joined(separator: "\n")
    let leastSuccessful = dedup.filter { $0.value.total > 0 }.sorted(by: { $0.value.successRate < $1.value.successRate }).prefix(10).map(String.init(describing:)).joined(separator: "\n")
    print("Top rules: \n\(topTotal)\n\n")
    print("Worst rules: \n\(leastSuccessful)\n\n")
  }
}
