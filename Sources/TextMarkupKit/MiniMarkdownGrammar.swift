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
    paragraph
  ).memoize()

  lazy var blankLine = InOrder(
    newline,
    dot.assert()
  ).absorb(into: .blankLine).memoize()

  lazy var header = InOrder(
    Characters(["#"]).repeating(1 ..< 7).absorb(into: .delimiter),
    InOrder(
      ParsingRule.whitespace.repeating(0...),
      InOrder(newline.assertInverse(), .dot).repeating(0...),
      Choice(newline, dot.assertInverse())
    ).absorb(into: .text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    styledText,
    paragraphTermination.zeroOrOne().wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Characters(["#", "\n"]).assert()
  ).memoize()

  func delimitedText(_ nodeType: NodeType, delimiter: ParsingRule) -> ParsingRule {
    InOrder(
      delimiter.absorb(into: .delimiter),
      InOrder(delimiter.assertInverse(), dot).repeating(1...).absorb(into: .text),
      delimiter.absorb(into: .delimiter)
    ).wrapping(in: nodeType).memoize()
  }

  lazy var bold = delimitedText(.strongEmphasis, delimiter: Literal("**"))
  lazy var italic = delimitedText(.emphasis, delimiter: Literal("*"))
  lazy var code = delimitedText(.code, delimiter: Literal("`"))

  lazy var textStyles = Choice(
    bold,
    italic,
    code
  ).memoize()

  lazy var styledText = InOrder(
    InOrder(paragraphTermination.assertInverse(), textStyles.assertInverse(), dot).repeating(0...).absorb(into: .text),
    textStyles.repeating(0...)
  ).repeating(0...).memoize()

  let dot = DotRule()
  let newline = Characters(["\n"])
}
