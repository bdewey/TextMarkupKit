// 

import Foundation

public enum ParseError: Swift.Error {
  /// The parsing routine did not parse the entire document.
  case incompleteParsing(TextBuffer.Index)
}

public protocol ConditionalParser {
  func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node?
}

extension Sequence where Element: ConditionalParser {
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    for subparser in self {
      if let node = subparser.parse(textBuffer: textBuffer, position: position) {
        return node
      }
    }
    return nil
  }
}

public protocol UnconditionalParser {
  func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node
}

extension UnconditionalParser {
  public func parse(_ text: String) throws -> Node {
    let buffer = TextBuffer(text)
    let node = parse(textBuffer: buffer, position: buffer.startIndex)
    if node.range.upperBound != text.endIndex {
      throw ParseError.incompleteParsing(node.range.upperBound)
    }
    return node
  }
}

public protocol SequenceParser: ConditionalParser {
  var type: NodeType { get }
  var parseFunction: (TextBuffer, TextBuffer.Index) -> [Node] { get }
}

extension SequenceParser {
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    let children = parseFunction(textBuffer, position)
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: type, range: range, children: children)
  }
}

public protocol SentinelParser: ConditionalParser {
  var sentinels: CharacterSet { get }
}

public struct SentinelParserCollection {
  public init(_ parsers: [SentinelParser]) {
    self.parsers = parsers
    self.sentinels = parsers
      .map { $0.sentinels }
      .reduce(into: CharacterSet(), { $0.formUnion($1) })
  }

  private let parsers: [SentinelParser]
  public let sentinels: CharacterSet

  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    for subparser in parsers {
      if let node = subparser.parse(textBuffer: textBuffer, position: position) {
        return node
      }
    }
    return nil
  }
}
