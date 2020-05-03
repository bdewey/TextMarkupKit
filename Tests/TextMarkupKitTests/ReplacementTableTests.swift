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
  private let sampleString = NSAttributedString(string: "yo")

  func testSingleRange() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(ReplacementTable.Replacement(range: NSRange(location: 2, length: 2), replacement: sampleString))
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 4))
    XCTAssertEqual(replacements.count, 1)
    XCTAssertEqual(replacements, [ReplacementTable.Replacement(range: NSRange(location: 2, length: 2), replacement: sampleString)])
  }

  func testMultipleRanges() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 4, length: 2),
        replacement: sampleString
      )
    )
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 100))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 2, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 4, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testFilterRanges() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 4, length: 2),
        replacement: sampleString
      )
    )
    let replacements = replacementTable.replacements(in: NSRange(location: 4, length: 2))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 4, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testRangesRespondToInserts() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 10, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 20, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.wipeCharacters(in: NSRange(location: 6, length: 0), replacementLength: 3)
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 100))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 2, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 13, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 23, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testRangesRespondToDeletions() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 10, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 20, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.wipeCharacters(in: NSRange(location: 9, length: 3), replacementLength: 0)
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 100))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 2, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 17, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testCanDeleteFirstRange() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 10, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 20, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.wipeCharacters(in: NSRange(location: 0, length: 4), replacementLength: 0)
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 100))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 6, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 16, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testCanDeleteLastRange() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 10, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 20, length: 2),
        replacement: sampleString
      )
    )
    replacementTable.wipeCharacters(in: NSRange(location: 20, length: 4), replacementLength: 0)
    let replacements = replacementTable.replacements(in: NSRange(location: 0, length: 100))
    XCTAssertEqual(
      replacements,
      [
        ReplacementTable.Replacement(
          range: NSRange(location: 2, length: 2),
          replacement: sampleString
        ),
        ReplacementTable.Replacement(
          range: NSRange(location: 10, length: 2),
          replacement: sampleString
        ),
      ]
    )
  }

  func testAddressTranslation() {
    let replacementTable = ReplacementTable()
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 2, length: 4),
        replacement: sampleString
      )
    )
    replacementTable.insert(
      ReplacementTable.Replacement(
        range: NSRange(location: 10, length: 4),
        replacement: sampleString
      )
    )

    XCTAssertEqual(1, replacementTable.physicalIndex(for: 1))
    XCTAssertEqual(3, replacementTable.physicalIndex(for: 3))
    XCTAssertEqual(6, replacementTable.physicalIndex(for: 4))
    XCTAssertEqual(9, replacementTable.physicalIndex(for: 7))
    XCTAssertEqual(10, replacementTable.physicalIndex(for: 8))
    XCTAssertEqual(11, replacementTable.physicalIndex(for: 9))
    XCTAssertEqual(14, replacementTable.physicalIndex(for: 10))
    XCTAssertEqual(104, replacementTable.physicalIndex(for: 100))
  }
}
