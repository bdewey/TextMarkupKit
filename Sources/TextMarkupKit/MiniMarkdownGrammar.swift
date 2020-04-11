// 

import Foundation

public final class MiniMarkdownGrammar: PackratGrammar {
  public init() { }

  public let start: ParsingRule = rule(\.block).zeroOrMore().wrapping(in: .markdownDocument)

  var block = ParsingRules.choice(
    rule(\.blankLine),
    rule(\.header),
    rule(\.paragraph)
  )

  let blankLine = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["\n"]),
    ParsingRules.dot.assert()
  ).absorb(into: .blankLine)

  var header = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["#"]).repeating(1..<7).absorb(into: .delimiter),
    ParsingRules.sequence(
      ParsingRules.whitespace.zeroOrMore(),
      ParsingRules.sequence(CharacterSetMatcher(characters: ["\n"]).assertInverse(), ParsingRules.dot).zeroOrMore(),
      CharacterSetMatcher(characters: ["\n"])
    ).absorb(into: .text)
  ).wrapping(in: .header)

  lazy var paragraph = ParsingRules.sequence(
    ParsingRules.sequence(paragraphTermination.assertInverse(), ParsingRules.dot).repeating(1...),
    paragraphTermination.zeroOrMore()
  ).wrapping(in: .text).wrapping(in: .paragraph)

  let paragraphTermination = ParsingRules.sequence(
    CharacterSetMatcher(characters: ["\n"]),
    CharacterSetMatcher(characters: ["#", "\n"]).assert()
  )
}

func rule(_ keyPath: KeyPath<MiniMarkdownGrammar, ParsingRule>) -> ParsingRule {
  RuleMatcher(ruleIdentifier: keyPath)
}
