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
import protocol TextMarkupKit.Pattern // disambiguate on the mac
import XCTest

final class PatternTests: XCTestCase {
  func testFindOneCharacter() {
    XCTAssertEqual(rangesOfPattern("*", in: "*"), [0 ..< 1])
  }

  func testFindTwoCharacters() {
    XCTAssertEqual(rangesOfPattern("**", in: "**"), [0 ..< 2])
  }

  func testDontFindOneCharacter() {
    XCTAssertEqual(rangesOfPattern("*", in: "mary had a little lamb"), [])
  }

  func testFindMultipleOccurrences() {
    XCTAssertEqual(rangesOfPattern("**", in: "**bold** text"), [0 ..< 2, 6 ..< 8])
  }

  func testHandleFalseStarts() {
    XCTAssertEqual(rangesOfPattern("**", in: "*x**y**"), [2 ..< 4, 5 ..< 7])
  }

  func testFindOverlappingMatches() {
    XCTAssertEqual(yesIndexesOfPattern("**", in: "****"), IndexSet(integersIn: 1 ..< 4))
  }
}

private extension PatternTests {
  func rangesOfPattern(_ pattern: StringLiteralPattern, in string: String) -> [Range<Int>] {
    var pattern = pattern
    var mostRecentMaybe: Int?
    var results = [Range<Int>]()
    let pieceTable = PieceTable(string)
    var iterator = pieceTable.makeIterator()
    while let ch = iterator.next() {
      switch pattern.patternRecognized(after: ch, iterator: iterator) {
      case .no:
        mostRecentMaybe = nil
      case .maybe:
        if mostRecentMaybe == nil { mostRecentMaybe = iterator.index - 1 }
      case .yes:
        let startIndex = mostRecentMaybe ?? iterator.index - 1
        results.append(startIndex ..< iterator.index)
      }
    }
    return results
  }

  func yesIndexesOfPattern(_ pattern: StringLiteralPattern, in string: String) -> IndexSet {
    var indexSet = IndexSet()
    var pattern = pattern
    let pieceTable = PieceTable(string)
    var iterator = pieceTable.makeIterator()
    while let ch = iterator.next() {
      if pattern.patternRecognized(after: ch, iterator: iterator) == .yes {
        indexSet.insert(iterator.index - 1)
      }
    }
    return indexSet
  }
}
