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

public extension NodeType {
  static let blankLine: NodeType = "blank_line"
  static let blockquote: NodeType = "blockquote"
  static let code: NodeType = "code"
  static let delimiter: NodeType = "delimiter"
  static let document: NodeType = "document"
  static let emphasis: NodeType = "emphasis"
  static let hashtag: NodeType = "hashtag"
  static let header: NodeType = "header"
  static let image: NodeType = "image"
  static let list: NodeType = "list"
  static let listItem: NodeType = "list_item"
  static let paragraph: NodeType = "paragraph"
  static let strongEmphasis: NodeType = "strong_emphasis"
  static let text: NodeType = "text"
}

public enum ListType {
  case ordered
  case unordered
}

public enum ListTypeKey: NodePropertyKey {
  public typealias Value = ListType

  public static let key = "list_type"
}

public final class MiniMarkdownGrammar: PackratGrammar {
  public init(trace: Bool = false) {
    if trace {
      self.start = self.start.trace()
    }
  }

  public private(set) lazy var start: ParsingRule = block
    .repeating(0...)
    .wrapping(in: .document)

  lazy var block = Choice(
    blankLine,
    header,
    unorderedList,
    orderedList,
    blockquote,
    paragraph
  ).memoize()

  lazy var blankLine = InOrder(
    whitespace.repeating(0...),
    newline
  ).as(.blankLine).memoize()

  lazy var header = InOrder(
    Characters(["#"]).repeating(1 ..< 7).as(.delimiter),
    InOrder(
      whitespace.repeating(1...),
      InOrder(newline.assertInverse(), dot).repeating(0...),
      Choice(newline, dot.assertInverse())
    ).as(.text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    nonDelimitedHashtag.zeroOrOne(),
    styledText,
    paragraphTermination.zeroOrOne().wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Choice(Characters(["#", "\n"]).assert(), unorderedListOpening.assert(), orderedListOpening.assert(), blockquoteOpening.assert())
  )

  // MARK: - Inline styles

  func delimitedText(_ nodeType: NodeType, delimiter: ParsingRule) -> ParsingRule {
    InOrder(
      delimiter.as(.delimiter),
      InOrder(
        delimiter.assertInverse(),
        paragraphTermination.assertInverse(),
        dot
      ).repeating(1...).as(.text),
      delimiter.as(.delimiter)
    ).wrapping(in: nodeType).memoize()
  }

  /// This is an optimization -- if you're not looking at one of these characters, none of the text styles apply.
  let textStyleSentinels = Characters(["*", "`", " ", "!"])

  lazy var bold = delimitedText(.strongEmphasis, delimiter: Literal("**"))
  lazy var italic = delimitedText(.emphasis, delimiter: Literal("*"))
  lazy var code = delimitedText(.code, delimiter: Literal("`"))
  lazy var hashtag = InOrder(
    whitespace.as(.text),
    nonDelimitedHashtag
  )
  lazy var nonDelimitedHashtag = InOrder(Literal("#"), nonWhitespace.repeating(1...)).as(.hashtag).memoize()

  lazy var image = InOrder(
    Literal("!["),
    Characters(CharacterSet(charactersIn: "\n]").inverted).repeating(0...),
    Literal("]("),
    Characters(CharacterSet(charactersIn: "\n)").inverted).repeating(0...),
    Literal(")")
  ).as(.image).memoize()

  lazy var textStyles = InOrder(
    textStyleSentinels.assert(),
    Choice(
      bold,
      italic,
      code,
      hashtag,
      image
    )
  ).memoize()

  lazy var styledText = InOrder(
    InOrder(paragraphTermination.assertInverse(), textStyles.assertInverse(), dot).repeating(0...).as(.text),
    textStyles.repeating(0...)
  ).repeating(0...).memoize()

  // MARK: - Character primitives

  let dot = DotRule()
  let newline = Characters(["\n"])
  let whitespace = Characters(.whitespaces)
  let nonWhitespace = Characters(CharacterSet.whitespacesAndNewlines.inverted)
  let digit = Characters(.decimalDigits)

  // MARK: - Simple block quotes
  // TODO: Support single block quotes that span multiple lines, and block quotes with multiple
  //       paragraphs.

  lazy var blockquoteOpening = InOrder(
    whitespace.repeating(0...3),
    Characters([">"]),
    whitespace.zeroOrOne()
  ).as(.delimiter).memoize()

  lazy var blockquote = InOrder(
    blockquoteOpening,
    paragraph
  ).as(.blockquote).memoize()

  // MARK: - Lists

  // https://spec.commonmark.org/0.28/#list-items

  lazy var unorderedListOpening = InOrder(
    whitespace.repeating(0...),
    Characters(["*", "-", "+"]),
    whitespace.repeating(1...4)
  ).as(.delimiter).memoize()

  lazy var orderedListOpening = InOrder(
    whitespace.repeating(0...),
    InOrder(digit.repeating(1...9), Characters([".", ")"])),
    whitespace.repeating(1...4)
  ).as(.delimiter).memoize()

  func list(type: ListType, openingDelimiter: ParsingRule) -> ParsingRule {
    let listItem = InOrder(
      openingDelimiter,
      paragraph
    ).wrapping(in: .listItem).memoize()
    return InOrder(
      listItem,
      blankLine.repeating(0...)
    ).repeating(1...).wrapping(in: .list).property(key: ListTypeKey.self, value: type).memoize()
  }

  lazy var unorderedList = list(type: .unordered, openingDelimiter: unorderedListOpening)
  lazy var orderedList = list(type: .ordered, openingDelimiter: orderedListOpening)
}
