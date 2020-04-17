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
  static let code: NodeType = "code"
  static let delimiter: NodeType = "delimiter"
  static let document: NodeType = "document"
  static let emphasis: NodeType = "emphasis"
  static let header: NodeType = "header"
  static let list: NodeType = "list"
  static let listItem: NodeType = "list_item"
  static let paragraph: NodeType = "paragraph"
  static let strongEmphasis: NodeType = "strong_emphasis"
  static let text: NodeType = "text"
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
    paragraph
  ).memoize()

  lazy var blankLine = InOrder(
    whitespace.repeating(0...),
    newline
  ).as(.blankLine).memoize()

  lazy var header = InOrder(
    Characters(["#"]).repeating(1 ..< 7).as(.delimiter),
    InOrder(
      whitespace.repeating(0...),
      InOrder(newline.assertInverse(), dot).repeating(0...),
      Choice(newline, dot.assertInverse())
    ).as(.text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    styledText,
    paragraphTermination.zeroOrOne().wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Choice(Characters(["#", "\n"]).assert(), unorderedListOpening.assert(), orderedListOpening.assert())
  )

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
  let textStyleSentinels = Characters(["*", "`"])

  lazy var bold = delimitedText(.strongEmphasis, delimiter: Literal("**"))
  lazy var italic = delimitedText(.emphasis, delimiter: Literal("*"))
  lazy var code = delimitedText(.code, delimiter: Literal("`"))

  lazy var textStyles = InOrder(
    textStyleSentinels.assert(),
    Choice(
      bold,
      italic,
      code
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
  let digit = Characters(.decimalDigits)

  // MARK: - Lists

  // https://spec.commonmark.org/0.28/#list-items

  let unorderedListSigil = Characters(["*", "-", "+"])

  lazy var unorderedListOpening = InOrder(
    whitespace.repeating(0...),
    unorderedListSigil,
    whitespace.repeating(1...4)
  ).as(.delimiter).memoize()

  lazy var unorderedListItem = InOrder(
    unorderedListOpening,
    styledText,
    paragraphTermination.zeroOrOne().as(.text)
  ).wrapping(in: .listItem).memoize()

  lazy var unorderedList = InOrder(
    unorderedListItem,
    blankLine.repeating(0...)
  ).repeating(1...).wrapping(in: .list).memoize()

  lazy var orderedListOpening = InOrder(
    whitespace.repeating(0...),
    InOrder(digit.repeating(1...9), Characters([".", ")"])),
    whitespace.repeating(1...4)
  ).as(.delimiter).memoize()

  lazy var orderedListItem = InOrder(
    orderedListOpening,
    styledText,
    paragraphTermination.zeroOrOne().as(.text)
  ).wrapping(in: .listItem).memoize()

  lazy var orderedList = InOrder(
    orderedListItem,
    blankLine.repeating(0...)
  ).repeating(1...).wrapping(in: .list).memoize()
}
