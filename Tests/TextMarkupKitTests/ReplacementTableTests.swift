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

final class ReplacementTableTests: XCTestCase {
  private let sampleString = Array("yo".utf16)

  func testSingleRange() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.count, 1)
      XCTAssertEqual(replacements.map { $0.range }, [2 ..< 4])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testMultipleRanges() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 4 ..< 6)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.map { $0.range }, [2 ..< 4, 4 ..< 6])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFilterRanges() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 4 ..< 6)
      let replacements = replacementTable.replacements(in: 4 ..< 6)
      XCTAssertEqual(replacements.map { $0.range }, [4 ..< 6])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRangesRespondToInserts() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 10 ..< 12)
      try replacementTable.insert(sampleString, at: 20 ..< 22)

      replacementTable.offsetReplacements(after: 6, by: 3)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.map { $0.range }, [2 ..< 4, 13 ..< 15, 23 ..< 25])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRangesRespondToDeletions() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 10 ..< 12)
      try replacementTable.insert(sampleString, at: 20 ..< 22)

      replacementTable.removeReplacements(overlapping: 9 ..< 12)
      replacementTable.offsetReplacements(after: 9, by: -3)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.map { $0.range }, [2 ..< 4, 17 ..< 19])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testCanDeleteFirstRange() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 10 ..< 12)
      try replacementTable.insert(sampleString, at: 20 ..< 22)

      replacementTable.removeReplacements(overlapping: 0 ..< 4)
      replacementTable.offsetReplacements(after: 0, by: -4)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.map { $0.range }, [6 ..< 8, 16 ..< 18])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testCanDeleteLastRange() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      try replacementTable.insert(sampleString, at: 10 ..< 12)
      try replacementTable.insert(sampleString, at: 20 ..< 22)

      replacementTable.removeReplacements(overlapping: 20 ..< 24)
      replacementTable.offsetReplacements(after: 20, by: -4)
      let replacements = replacementTable.replacements(in: 0...)
      XCTAssertEqual(replacements.map { $0.range }, [2 ..< 4, 10 ..< 12])
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testOverlappingInsertsRaiseError() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 4)
      XCTAssertThrowsError(try replacementTable.insert(sampleString, at: 3 ..< 4))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAddressTranslation() {
    do {
      let replacementTable = ArrayReplacementCollection<unichar>()
      try replacementTable.insert(sampleString, at: 2 ..< 6)
      try replacementTable.insert(sampleString, at: 10 ..< 14)

      XCTAssertEqual(1, replacementTable.physicalIndex(for: 1))
      XCTAssertEqual(3, replacementTable.physicalIndex(for: 3))
      XCTAssertEqual(6, replacementTable.physicalIndex(for: 4))
      XCTAssertEqual(9, replacementTable.physicalIndex(for: 7))
      XCTAssertEqual(10, replacementTable.physicalIndex(for: 8))
      XCTAssertEqual(11, replacementTable.physicalIndex(for: 9))
      XCTAssertEqual(14, replacementTable.physicalIndex(for: 10))
      XCTAssertEqual(104, replacementTable.physicalIndex(for: 100))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
