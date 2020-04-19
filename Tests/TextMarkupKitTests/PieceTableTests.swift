// 

import Foundation
import TextMarkupKit
import XCTest

final class PieceTableTests: XCTestCase {
  func testOriginalLength() {
    let pieceTable = PieceTable("Hello, world")
    XCTAssertEqual(12, pieceTable.endIndex)
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
  }

  func testDeleteAddedOverlappingRange() {
    let pieceTable = PieceTable("Hello, world!")
    pieceTable.replaceCharacters(in: NSRange(location: 7, length: 0), with: "nutty ")
    pieceTable.replaceCharacters(in: NSRange(location: 5, length: 13), with: "")
    XCTAssertEqual("Hello!", pieceTable.string)
  }
}
