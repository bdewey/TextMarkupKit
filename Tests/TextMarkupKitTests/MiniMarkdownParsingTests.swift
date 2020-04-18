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

final class MiniMarkdownParsingTests: XCTestCase {
  func testHeaderAndBody() {
    let markdown = """
    # This is a header

    And this is a body.
    The two lines are part of the same paragraph.

    The line break indicates a new paragraph.

    """
    parseText(
      markdown,
      expectedStructure: "(document (header delimiter text) blank_line (paragraph text) blank_line (paragraph text))"
    )
  }

  func testJustEmphasis() {
    parseText(
      "*This is emphasized text.*",
      expectedStructure: "(document (paragraph (emphasis delimiter text delimiter)))"
    )
  }

  func testTextWithEmphasis() {
    parseText(
      "This is text with *emphasis.*",
      expectedStructure: "(document (paragraph text (emphasis delimiter text delimiter)))"
    )
  }

  func testWithBold() {
    parseText(
      "This is text with **bold**.",
      expectedStructure: "(document (paragraph text (strong_emphasis delimiter text delimiter) text))"
    )
  }

  func testTextAndHeader() {
    parseText(
      "Text\n# Heading",
      expectedStructure: "(document (paragraph text) (header delimiter text))"
    )
  }

  func testTextAndCode() {
    parseText(
      "This is text with `code`.",
      expectedStructure: "(document (paragraph text (code delimiter text delimiter) text))"
    )
  }

  func testParagraphs() {
    parseText(
      "Paragraph\n\nX",
      expectedStructure: "(document (paragraph text) blank_line (paragraph text))"
    )
  }

  func testListWithMultipleItems() {
    let markdown = """
    - Item one
    - Item two
    """
    parseText(markdown, expectedStructure: "(document (list (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text))))")
  }

  func testListItemWithStyling() {
    parseText(
      "- This is a list item with **strong emphasis**",
      expectedStructure: "(document (list (list_item delimiter (paragraph text (strong_emphasis delimiter text delimiter)))))"
    )
  }

  func testEmphasisDoesNotSpanListItems() {
    let markdown = """
    - Item *one
    - Item *two
    """
    parseText(markdown, expectedStructure: "(document (list (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text))))")
  }

  func testAllUnorderedListMarkers() {
    let example = """
    - This is a list item.
    + So is this.
    * And so is this.

    """
    let tree = parseText(example, expectedStructure: "(document (list (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text))))")
    XCTAssertEqual(tree?.node(at: [0])?[ListTypeKey.self], .unordered)
  }

  func testOrderedListMarkers() {
    let example = """
    1. this is the first item
    2. this is the second item
    3) This is also legit.

    """
    let tree = parseText(example, expectedStructure: "(document (list (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text)) (list_item delimiter (paragraph text))))")
    XCTAssertEqual(tree?.node(at: [0])?[ListTypeKey.self], .ordered)
  }

  func testSingleLineBlockQuote() {
    let example = "> This is a quote with **bold** text."
    parseText(example, expectedStructure: "(document (blockquote delimiter (paragraph text (strong_emphasis delimiter text delimiter) text)))")
  }

  func testOrderedMarkerCannotBeTenDigits() {
    let example = """
    12345678900) This isn't a list.
    """
    parseText(example, expectedStructure: "(document (paragraph text))")
  }

  func testParseHashtag() {
    parseText("#hashtag\n", expectedStructure: "(document (paragraph hashtag text))")
  }

  func testFile() {
    let pieceTable = PieceTable(TestStrings.markdownCanonical)
    let grammar = MiniMarkdownGrammar()
    let parser = PackratParser(buffer: pieceTable, grammar: grammar)
    do {
      _ = try parser.parse()
    } catch {
      XCTFail("Unexpected error: \(error)")
      print(parser.traceBuffer)
    }
  }
}

// MARK: - Private

private extension MiniMarkdownParsingTests {
  @discardableResult
  func parseText(_ text: String, expectedStructure: String, file: StaticString = #file, line: UInt = #line) -> Node? {
    do {
      let pieceTable = PieceTable(text)
      let grammar = MiniMarkdownGrammar()
      let parser = PackratParser(buffer: pieceTable, grammar: grammar)
      let tree = try parser.parse()
      if tree.range.endIndex != pieceTable.endIndex {
        let unparsedText = pieceTable[tree.range.endIndex ..< pieceTable.endIndex]
        XCTFail("Test case \(name): Unparsed text = '\(unparsedText.debugDescription)'", file: file, line: line)
      }
      if expectedStructure != tree.compactStructure {
        print("### Failure: \(name)")
        print("Got:      " + tree.compactStructure)
        print("Expected: " + expectedStructure)
        print("\n")
        print(tree.debugDescription(withContentsFrom: pieceTable))
        print("\n\n\n")
      }
      XCTAssertEqual(tree.compactStructure, expectedStructure, "Unexpected structure", file: file, line: line)
      return tree
    } catch {
      XCTFail("Unexpected error: \(error)", file: file, line: line)
      return nil
    }
  }
}
