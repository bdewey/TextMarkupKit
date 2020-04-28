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

final class PieceTableTests: XCTestCase {
  func testOriginalLength() {
    let pieceTable = PieceTable("Hello, world")
    XCTAssertEqual(12, pieceTable.count)
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testAppendSingleCharacter() {
    let pieceTable = PieceTable("Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 12, length: 0), with: "!")
    XCTAssertEqual("Hello, world!", pieceTable.string)
  }

  func testInsertCharacterInMiddle() {
    let pieceTable = PieceTable("Hello world")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 0), with: ",")
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testDeleteCharacterInMiddle() {
    let pieceTable = PieceTable("Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 1), with: "")
    XCTAssertEqual("Hello world", pieceTable.string)
  }

  func testDeleteFromBeginning() {
    let pieceTable = PieceTable("_Hello, world")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 1), with: "")
    XCTAssertEqual("Hello, world", pieceTable.string)
  }

  func testInsertAtBeginning() {
    let pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 0), with: "¡")
    XCTAssertEqual("¡Hello, world!", pieceTable.string)
  }

  func testLeftOverlappingEditRange() {
    let pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 7, length: 0), with: "zCRuel ")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 10), with: "Goodbye, cr")
    XCTAssertEqual("Goodbye, cruel world!", pieceTable.string)
  }

  func testRightOverlappingEditRange() {
    let pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 4, length: 2), with: "a,")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 2), with: "!! ")
    XCTAssertEqual("Hella!! world!", pieceTable.string)
    XCTAssertEqual(pieceTable.utf16String, pieceTable.string)
  }

  func testDeleteAddedOverlappingRange() {
    let pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 7, length: 0), with: "nutty ")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 13), with: "")
    XCTAssertEqual("Hello!", pieceTable.string)
  }

  func testAppend() {
    let pieceTable = PieceTable("")
    pieceTable.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Hello, world!")
    XCTAssertEqual(pieceTable.string, "Hello, world!")
  }

  func testRepeatedAppend() {
    var pieceTable = PieceTable()
    let expected = "Hello, world!!"
    for ch in expected.utf16 {
      pieceTable.append(ch)
    }
    XCTAssertEqual(pieceTable.string, expected)
  }

  func testAppendPerformance() {
    measure {
      let pieceTable = PieceTable("")
      for i in 0 ..< 1024 {
        pieceTable.replaceCharacters(in: NSRange(location: i, length: 0), with: ".")
      }
    }
  }

  /// This does two large "local" edits. First it puts 512 characters sequentially into the buffer.
  /// Then it puts another 512 characters sequentially into the middle.
  /// Logically this can be represented in 3 runs so manipulations should stay fast.
  func testLargeLocalEditPerformance() {
    let expected = String(repeating: "A", count: 256) + String(repeating: "B", count: 512) + String(repeating: "A", count: 256)
    measure {
      let pieceTable = PieceTable("")
      for i in 0 ..< 512 {
        pieceTable.replaceCharacters(in: NSRange(location: i, length: 0), with: "A")
      }
      for i in 0 ..< 512 {
        pieceTable.replaceCharacters(in: NSRange(location: 256 + i, length: 0), with: "B")
      }
      XCTAssertEqual(pieceTable.string, expected)
    }
  }
}

// MARK: - Private

extension PieceTable {
  var utf16String: String {
    var chars = [unichar]()
    var i = 0
    while let ch = utf16(at: i) {
      chars.append(ch)
      i += 1
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }
}
