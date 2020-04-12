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
      Choice(newline, dot.assertInverse())
    ).absorb(into: .text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = InOrder(
    styledText,
    paragraphTermination.repeating(0...1).wrapping(in: .text)
  ).wrapping(in: .paragraph).memoize()

  lazy var paragraphTermination = InOrder(
    newline,
    Characters(["#", "\n"]).assert()
  )

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
