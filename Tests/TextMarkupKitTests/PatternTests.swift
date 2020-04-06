// 

import Foundation
import TextMarkupKit
import protocol TextMarkupKit.Pattern // disambiguate on the mac
import XCTest

final class PatternTests: XCTestCase {
  func testFindOneCharacter() {
    XCTAssertEqual(rangesOfPattern("*", in: "*"), [0..<1])
  }

  func testFindTwoCharacters() {
    XCTAssertEqual(rangesOfPattern("**", in: "**"), [0..<2])
  }

  func testDontFindOneCharacter() {
    XCTAssertEqual(rangesOfPattern("*", in: "mary had a little lamb"), [])
  }

  func testFindMultipleOccurrences() {
    XCTAssertEqual(rangesOfPattern("**", in: "**bold** text"), [0..<2, 6..<8])
  }

  func testHandleFalseStarts() {
    XCTAssertEqual(rangesOfPattern("**", in: "*x**y**"), [2..<4, 5..<7])
  }

  func testFindOverlappingMatches() {
    XCTAssertEqual(yesIndexesOfPattern("**", in: "****"), IndexSet(integersIn: 1..<4))
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
