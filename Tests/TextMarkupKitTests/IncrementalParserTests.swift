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

  func testDeleteCanChangeFormatting() {
    do {
      let parser = try IncrementalParser("Hello * world*", grammar: MiniMarkdownGrammar())
      validateParser(parser, has: "(document (paragraph text))")
      parser.parser.traceBuffer.traceEntries.removeAll()
      try parser.replaceCharacters(in: NSRange(location: 7, length: 1), with: "")
      XCTAssertEqual(parser.pieceTable.utf16String, parser.pieceTable.string)
      validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testDeleteCanChangeFormattingRightFlank() {
    do {
      let parser = try IncrementalParser("Hello *world *", grammar: MiniMarkdownGrammar())
      validateParser(parser, has: "(document (paragraph text))")
      parser.parser.traceBuffer.traceEntries.removeAll()
      try parser.replaceCharacters(in: NSRange(location: 12, length: 1), with: "")
      XCTAssertEqual(parser.pieceTable.utf16String, parser.pieceTable.string)
      validateParser(parser, has: "(document (paragraph text (emphasis delimiter text delimiter)))")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func __testIncrementalParsingReusesNodesWhenPossible() {
    do {
      let text = """
      # Sample document

      I will be editing this **awesome** text and expect most nodes to be reused.
      """
      let parser = try IncrementalParser(text, grammar: MiniMarkdownGrammar())
      let tree = validateParser(parser, has: "(document (header delimiter text) blank_line (paragraph text (strong_emphasis delimiter text delimiter) text))")
      let emphasis = tree.node(at: [2, 1])
      XCTAssertEqual(emphasis?.type, .strongEmphasis)
      try parser.replaceCharacters(in: NSRange(location: text.utf16.count, length: 0), with: "Change paragraph!\n\nAnd add a new one.")
      let editedTree = validateParser(parser, has: "(document (header delimiter text) blank_line (paragraph text (strong_emphasis delimiter text delimiter) text) blank_line (paragraph text))")
      let editedEmphasis = editedTree.node(at: [2, 1])
      XCTAssertEqual(editedEmphasis?.type, .strongEmphasis)
      XCTAssert(emphasis === editedEmphasis)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

// MARK: - Private

private extension IncrementalParserTests {
  @discardableResult
  func validateParser(_ parser: IncrementalParser, has expectedStructure: String, file: StaticString = #file, line: UInt = #line) -> Node {
    let tree = parser.tree
    if tree.length != parser.count {
      let unparsedText = parser[NSRange(location: tree.length, length: parser.count - tree.length)]
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
