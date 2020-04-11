// 

import Foundation

public final class MiniMarkdownGrammar: PackratGrammar {
  public init() { }

  public private(set) lazy var start: ParsingRule = block
    .repeating(0...)
    .wrapping(in: .markdownDocument)

  lazy var block = ParsingRules.choice(
    blankLine,
    header,
    paragraph
  ).memoize()

  let blankLine = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["\n"]),
    ParsingRules.dot.assert()
  ).absorb(into: .blankLine).memoize()

  var header = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["#"]).repeating(1..<7).absorb(into: .delimiter),
    ParsingRules.sequence(
      ParsingRules.whitespace.repeating(0...),
      ParsingRules.sequence(CharacterSetMatcher(characters: ["\n"]).assertInverse(), ParsingRules.dot).repeating(0...),
      CharacterSetMatcher(characters: ["\n"])
    ).absorb(into: .text)
  ).wrapping(in: .header).memoize()

  lazy var paragraph = ParsingRules.sequence(
    ParsingRules.sequence(paragraphTermination.assertInverse(), ParsingRules.dot).repeating(1...),
    paragraphTermination.repeating(0...)
  ).wrapping(in: .text).wrapping(in: .paragraph).memoize()

  let paragraphTermination = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["\n"]),
    CharacterSetMatcher(characters: ["#", "\n"]).assert()
  )
}
