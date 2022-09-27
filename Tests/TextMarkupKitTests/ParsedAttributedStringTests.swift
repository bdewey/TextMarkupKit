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

import TextMarkupKit
import XCTest

final class ParsedAttributedStringTests: XCTestCase {
  func testReplacementsAffectStringsButNotRawText() {
    let formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: AnyParsedAttributedStringFormatter { $0.italic = true },
      .header: AnyParsedAttributedStringFormatter { $0.fontSize = 24 },
      .list: AnyParsedAttributedStringFormatter { $0.listLevel += 1 },
      .strongEmphasis: AnyParsedAttributedStringFormatter { $0.bold = true },
      .softTab: AnyParsedAttributedStringFormatter(substitution: "\t"),
    ]
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)

    let textStorage = ParsedAttributedString(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )

    textStorage.append(NSAttributedString(string: "# This is a heading\n\nAnd this is a paragraph"))
    XCTAssertEqual(textStorage.string, "#\tThis is a heading\n\nAnd this is a paragraph")
    XCTAssertEqual(textStorage.rawString.string, "# This is a heading\n\nAnd this is a paragraph")
  }

  func testVariableLengthReplacements() {
    let noDelimiterTextStorage = Self.makeNoDelimiterStorage()
    noDelimiterTextStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "#### This is a heading")
    XCTAssertEqual(noDelimiterTextStorage.string, "\tThis is a heading")
    XCTAssertEqual(noDelimiterTextStorage.rawStringRange(forRange: NSRange(location: 0, length: 18)), NSRange(location: 0, length: 22))
    XCTAssertEqual(noDelimiterTextStorage.rawStringRange(forRange: NSRange(location: 0, length: 1)), NSRange(location: 0, length: 5))
    XCTAssertEqual(noDelimiterTextStorage.range(forRawStringRange: NSRange(location: 0, length: 5)), NSRange(location: 0, length: 1))
    XCTAssertEqual(noDelimiterTextStorage.range(forRawStringRange: NSRange(location: 5, length: 1)), NSRange(location: 1, length: 1))

    // Walk through the string, attribute by attribute. We should end exactly at the end location.
    var location = 0
    var effectiveRange: NSRange = .init(location: 0, length: 0)
    while location < noDelimiterTextStorage.length {
      _ = noDelimiterTextStorage.attributes(at: location, effectiveRange: &effectiveRange)
      XCTAssert(
        location + effectiveRange.length <= noDelimiterTextStorage.string.utf16.count,
        "End of effective range (\(location + effectiveRange.length)) is beyond end-of-string \(noDelimiterTextStorage.string.utf16.count)"
      )
      print(effectiveRange)
      location += effectiveRange.length
    }
  }

  func testListDelimiterRange() throws {
    let noDelimiterTextStorage = ParsedAttributedString(string: "* One\n* Two\n* ", style: MiniMarkdownGrammar.defaultEditingStyle())
    XCTAssertEqual(noDelimiterTextStorage.string, "•\tOne\n•\tTwo\n•\t")
    let nodePath = try noDelimiterTextStorage.path(to: 13)
    guard let delimiter = nodePath.first(where: { $0.node.type == .listDelimiter }) else {
      XCTFail()
      return
    }
    XCTAssertEqual(delimiter.range, NSRange(location: 12, length: 2))
    let visibleRange = noDelimiterTextStorage.range(forRawStringRange: delimiter.range)
    XCTAssertEqual(visibleRange, NSRange(location: 12, length: 2))
  }

  func testQandACardWithReplacements() {
    let markdown = "Q: Can Q&A cards have *formatting*?\nA: **Yes!** Even `code`!"
    let noDelimiterTextStorage = Self.makeNoDelimiterStorage()
    noDelimiterTextStorage.append(NSAttributedString(string: markdown))

    XCTAssertEqual(markdown.count - 8, noDelimiterTextStorage.length)
  }

  func testImageAndReplacements() {
    let markdown = """
    # _Tom Kundig: Houses_: Dung Ngo, Tom Kundig, Steven Holl, Rick Joy, Billie Tsien (2006)

    ![](./288c09ac036eef237952e10cb8f62626441ee8f5.jpeg)

    """

    let noDelimiterTextStorage = Self.makeNoDelimiterStorage()
    noDelimiterTextStorage.append(NSAttributedString(string: markdown))
    noDelimiterTextStorage.append(NSAttributedString(string: "\n\n#b"))
    XCTAssertEqual(noDelimiterTextStorage.length, 93)
  }

  func testDeleteMultipleAttributeRuns() {
    let storage = ParsedAttributedString(string: "# Header\n\nParagraph\n\n> Quote\n\n", style: MiniMarkdownGrammar.defaultEditingStyle())
    storage.replaceCharacters(in: NSRange(location: 2, length: 15), with: "")
    XCTAssertEqual(storage.string, "#\tph\n\n>\tQuote\n\n")
  }

  static func makeNoDelimiterStorage() -> ParsedAttributedString {
    let formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .emphasis: AnyParsedAttributedStringFormatter { $0.italic = true },
      .header: AnyParsedAttributedStringFormatter { $0.fontSize = 24 },
      .list: AnyParsedAttributedStringFormatter { $0.listLevel += 1 },
      .strongEmphasis: AnyParsedAttributedStringFormatter { $0.bold = true },
      .softTab: AnyParsedAttributedStringFormatter(substitution: "\t"),
      .image: AnyParsedAttributedStringFormatter(substitution: "\u{fffc}"),
      .delimiter: AnyParsedAttributedStringFormatter(substitution: ""),
    ]
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)
    return ParsedAttributedString(
      grammar: MiniMarkdownGrammar(),
      defaultAttributes: defaultAttributes,
      formatters: formatters
    )
  }
}
