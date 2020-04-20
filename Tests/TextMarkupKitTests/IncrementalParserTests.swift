// 

import Foundation
import TextMarkupKit
import XCTest

final class IncrementalParserTests: XCTestCase {
  func testSimpleEdit() {
    do {
      let parser = try IncrementalParser("Testing", grammar: MiniMarkdownGrammar())
      try parser.replaceCharacters(in: NSRange(location: 7, length: 0), with: ", testing")
      validateParser(parser, has: "(document (paragraph text))")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testInsertBold() {
    do {
      let parser = try IncrementalParser("Hello world", grammar: MiniMarkdownGrammar())
      validateParser(parser, has: "(document (paragraph text))")
      try parser.replaceCharacters(in: NSRange(location: 6, length: 0), with: "**awesome** ")
      validateParser(parser, has: "(document (paragraph text (strong_emphasis delimiter text delimiter) text))")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testInsertCanChangeFormatting() {
    do {
      let parser = try IncrementalParser("Hello **world*", grammar: MiniMarkdownGrammar())
      validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
      parser.parser.traceBuffer.traceEntries.removeAll()
      try parser.replaceCharacters(in: NSRange(location: 14, length: 0), with: "*")
      print(parser.pieceTable.utf16String)
      validateParser(parser, has: "(document (paragraph text (strong_emphasis delimiter text delimiter)))")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

// MARK: - Private

private extension IncrementalParserTests {
  @discardableResult
  func validateParser(_ parser: IncrementalParser, has expectedStructure: String, file: StaticString = #file, line: UInt = #line) -> Node? {
    let tree = parser.tree
    if tree.length != parser.length {
      let unparsedText = parser[NSRange(location: tree.length, length: parser.length - tree.length)]
      XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'", file: file, line: line)
    }
    if expectedStructure != tree.compactStructure {
      print("### Failure: \(name)")
      print("Got:      " + tree.compactStructure)
      print("Expected: " + expectedStructure)
      print("\n")
      print(tree.debugDescription(withContentsFrom: parser.pieceTable))
      print("\n\n\n")
    }
    XCTAssertEqual(tree.compactStructure, expectedStructure, "Unexpected structure", file: file, line: line)
    return tree
  }
}
