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
    for (index, ch) in string.utf16.enumerated() {
      switch pattern.patternRecognized(after: ch) {
      case .no:
        mostRecentMaybe = nil
      case .maybe:
        if mostRecentMaybe == nil { mostRecentMaybe = index }
      case .yes:
        let startIndex = mostRecentMaybe ?? index
        results.append(startIndex ..< index + 1)
      }
    }
    return results
  }

  func yesIndexesOfPattern(_ pattern: StringLiteralPattern, in string: String) -> IndexSet {
    var indexSet = IndexSet()
    var pattern = pattern
    for (index, ch) in string.utf16.enumerated() {
      if pattern.patternRecognized(after: ch) == .yes {
        indexSet.insert(index)
      }
    }
    return indexSet
  }
}
