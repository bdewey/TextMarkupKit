// 

import Foundation

public final class MiniMarkdownGrammar: PackratGrammar {
  public init() { }

  public private(set) lazy var start: ParsingRule = block
    .repeating(0...)
    .wrapping(in: .markdownDocument)

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
    Characters(["#"]).repeating(1..<7).absorb(into: .delimiter),
    InOrder(
      ParsingRule.whitespace.repeating(0...),
      InOrder(newline.assertInverse(), .dot).repeating(0...),
      Characters(["\n"])
    ).absorb(into: .text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    InOrder(paragraphTermination.assertInverse(), ParsingRule.dot).repeating(1...),
    paragraphTermination.repeating(0...)
  ).wrapping(in: .text).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Characters(["#", "\n"]).assert()
  )

  let dot = DotRule()
  let newline = Characters(["\n"])
}
