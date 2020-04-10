// 

import Foundation

public protocol PackratMatcher {
  func match(parser: PackratParser, index: Int) -> PackratResult
}

public extension PackratMatcher {
  func zeroOrMore() -> PackratMatcher {
    return ZeroOrMoreMatcher(innerMatcher: self)
  }

  func absorb(into nodeType: NodeType) -> PackratMatcher {
    return AbsorbingMatcher(nodeType: nodeType, innerMatcher: self)
  }
}

/// The output of trying to match a rule at an offset into a PieceTable.
public struct PackratResult {
  /// Did the rule succeed?
  public var succeeded: Bool

  public var length: Int

  /// How far into the input sequence did we look to determine if we succeeded?
  public var examinedLength: Int

  /// If we succeeded, what are the parse results?
  public var nodes: [Node]

  public static let fail = PackratResult(succeeded: false, length: 0, examinedLength: 1, nodes: [])
}

public protocol PackratGrammar {
  var start: PackratMatcher { get }
}

public final class PackratParser {
  public init(buffer: PieceTable, grammar: PackratGrammar) {
    self.buffer = buffer
    self.grammar = grammar
  }

  public let buffer: PieceTable
  public let grammar: PackratGrammar

  public enum Error: Swift.Error {
    case incompleteParsing(length: Int)
    case ambiguousParsing(nodes: [Node])
  }

  public func parse() throws -> Node {
    let result = grammar.start.match(parser: self, index: 0)
    if result.length != buffer.endIndex {
      throw Error.incompleteParsing(length: result.length)
    }
    if result.nodes.count != 1 {
      throw Error.ambiguousParsing(nodes: result.nodes)
    }
    return result.nodes[0]
  }

  private struct MemoKey: Hashable {
    let rule: AnyKeyPath
    let index: Int
  }

  private var memoTable = [MemoKey: PackratResult]()

  func memoizedResult(rule: AnyKeyPath, index: Int) -> PackratResult? {
    return memoTable[MemoKey(rule: rule, index: index)]
  }

  func memoizeResult(_ result: PackratResult, rule: AnyKeyPath, index: Int) {
    memoTable[MemoKey(rule: rule, index: index)] = result
  }
}

struct FailMatcher: PackratMatcher {
  func match(parser: PackratParser, index: Int) -> PackratResult {
    return .fail
  }

  static let fail = FailMatcher()
}

public final class MiniMarkdownGrammar: PackratGrammar {
  public static let shared = MiniMarkdownGrammar()
  
  public var start: PackratMatcher {
    text.zeroOrMore().absorb(into: .text)
  }

  let text: PackratMatcher = CharacterSetMatcher(characters: .everything)

  func rule(_ keyPath: KeyPath<MiniMarkdownGrammar, PackratMatcher>) -> RuleMatcher<MiniMarkdownGrammar> {
    return RuleMatcher(rule: keyPath)
  }
}

struct CharacterSetMatcher: PackratMatcher {
  let characters: CharacterSet

  func match(parser: PackratParser, index: Int) -> PackratResult {
    guard let char = parser.buffer.utf16(at: index), characters.contains(char) else {
      return .fail
    }
    return PackratResult(succeeded: true, length: 1, examinedLength: 1, nodes: [])
  }
}

struct RuleMatcher<Grammar>: PackratMatcher {
  let rule: KeyPath<Grammar, PackratMatcher>

  func match(parser: PackratParser, index: Int) -> PackratResult {
    guard let grammar = parser.grammar as? Grammar else {
      preconditionFailure("Parser grammar was not of the expected type")
    }
    if let memoizedResult = parser.memoizedResult(rule: rule, index: index) {
      return memoizedResult
    }
    let matcher = grammar[keyPath: rule]
    let result = matcher.match(parser: parser, index: index)
    parser.memoizeResult(result, rule: rule, index: index)
    return result
  }
}

struct ZeroOrMoreMatcher: PackratMatcher {
  let innerMatcher: PackratMatcher

  func match(parser: PackratParser, index: Int) -> PackratResult {
    var result = PackratResult(succeeded: true, length: 0, examinedLength: 0, nodes: [])
    var currentIndex = index
    repeat {
      let innerResult = innerMatcher.match(parser: parser, index: currentIndex)
      guard innerResult.succeeded else { break }
      result.length += innerResult.length
      result.examinedLength += innerResult.examinedLength
      result.nodes.append(contentsOf: innerResult.nodes)
      currentIndex += innerResult.length
    } while true
    return result
  }
}

struct AbsorbingMatcher: PackratMatcher {
  let nodeType: NodeType
  let innerMatcher: PackratMatcher

  func match(parser: PackratParser, index: Int) -> PackratResult {
    var result = innerMatcher.match(parser: parser, index: index)
    if !result.succeeded { return result }
    let node = Node(type: nodeType, range: index ..< index + result.length)
    result.nodes = [node]
    return result
  }
}
