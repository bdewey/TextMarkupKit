// 

import Foundation

/// This is the simplest possible grammar: All content of the buffer gets parsed into a single node typed `text` with no
/// children. This represents the very best parsing performance you could get.
public final class JustTextGrammar: PackratGrammar {
  public static let shared = JustTextGrammar()

  public var start: ParsingRule {
    ParsingRules.dot.zeroOrMore().absorb(into: .text)
  }
}
