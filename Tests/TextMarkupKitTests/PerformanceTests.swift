// 

import Foundation
import TextMarkupKit
import XCTest

final class PerformanceTests: XCTestCase {
  func testCustomProcessor() {
    let pieceTable = PieceTable(TestStrings.markdownCanonical)
    measure {
      let tree = DocumentParser.miniMarkdown.parse(textBuffer: pieceTable, position: 0)
      if tree.range.endIndex != pieceTable.endIndex {
        let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'")
      }
    }
  }

  func testPackratParser() {
    let pieceTable = PieceTable(TestStrings.markdownCanonical)
    let parser = PackratParser(buffer: pieceTable, grammar: JustTextGrammar.shared)
    measure {
      do {
        let _ = try parser.parse()
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
