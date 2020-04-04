// 

import Foundation

//let h2 = NodeType.header
//  .startsWith(.pattern("#", min: 1, max: 6))
//  .then([
//    .assert(.whitespace),
//    .styledText(),
//  ]),
//  .endsWith(unichar.newline)
//
//let p2 = NodeType.paragraph
//  .startsWith(.anything)
//  .then([.styledText()])
//  .endsWith(paragraphTermination)
//
//let e2 = NodeType.emphasis
//  .startsWith("*")
//  .then([.styledText()])
//  .endsWith("*")
//
//let c2 = NodeType.code
//  .startsWith("`")
//  .then(.anything)
//  .endsWith("`")

public typealias Recognizer = (TextBuffer, Int) -> Node?
public typealias SequenceRecognizer = (TextBuffer, Int) -> [Node]

func concat(_ recognizer: Recognizer?, _ sequence: @escaping SequenceRecognizer) -> SequenceRecognizer {
  guard let recognizer = recognizer else {
    return sequence
  }
  return { textBuffer, index in
    guard let initialNode = recognizer(textBuffer, index) else {
      return []
    }
    let remainder = sequence(textBuffer, initialNode.range.endIndex)
    return [initialNode] + remainder
  }
}

func bind(nodeType: NodeType, sequenceRecognizer: @escaping SequenceRecognizer) -> Recognizer {
  return { textBuffer, index in
    let children = sequenceRecognizer(textBuffer, index)
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: nodeType, range: range, children: children)
  }
}

public struct RuleBuilder {
  public let type: NodeType

  public init(_ type: NodeType) {
    self.type = type
  }

  public enum OpeningSequence: ExpressibleByStringLiteral {
    case anything
    case literal(String)
    case pattern(UnicodeScalar, min: Int, max: Int)

    public init(stringLiteral value: StringLiteralType) {
      self = .literal(value)
    }

    internal var sentinels: CharacterSet {
      switch self {
      case .anything:
        // TODO: This doesn't seem right
        return CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
      case .literal(let string):
        if let opening = string.unicodeScalars.first {
          return CharacterSet(charactersIn: opening...opening)
        } else {
          assertionFailure()
          return CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
        }
      case .pattern(let scalar, min: _, max: _):
        return CharacterSet(charactersIn: scalar...scalar)
      }
    }

    internal var recognizer: Recognizer? {
      switch self {
      case .anything:
        return nil
      case .literal(let delimiter):
        return { textBuffer, position in
          var currentPosition = position
          for character in delimiter.utf16 {
            guard character == textBuffer.utf16(at: currentPosition) else {
              return nil
            }
            currentPosition += 1
          }
          return Node(type: .delimiter, range: position ..< currentPosition)
        }
      case .pattern(let scalar, min: let min, max: let max):
        return { textBuffer, position in
          var currentPositon = position
          let utf16: unichar = scalar.utf16.first!
          var matchCount = 0
          while let ch = textBuffer.utf16(at: currentPositon), ch == utf16 {
            matchCount += 1
            currentPositon += 1
            if matchCount > max { return nil }
          }
          if matchCount < min { return nil }
          return Node(type: .delimiter, range: position ..< currentPositon)
        }
      }
    }
  }

  public var startsWith: OpeningSequence?

  public func startsWith(_ openingSequence: OpeningSequence) -> Self {
    var copy = self
    copy.startsWith = openingSequence
    return copy
  }

  public func startsWith(_ string: String) -> Self {
    var copy = self
    copy.startsWith = .literal(string)
    return copy
  }

  public var body: SequenceRecognizer?

  public func then(_ sequenceRecognizer: @escaping SequenceRecognizer) -> Self {
    var copy = self
    copy.body = sequenceRecognizer
    return copy
  }

  public enum EndingSequence: ExpressibleByStringLiteral {
    case literal(String)
    case block(ScopedTextBuffer.Scope)

    public init(stringLiteral value: StringLiteralType) {
      self = .literal(value)
    }

    var terminationBlock: ScopedTextBuffer.Scope? {
      switch self {
      case .block(let terminationBlock):
        return terminationBlock
      case .literal(let literal):
        return ScopedTextBuffer.endAfter(literal)
      }
    }
  }

  public func endsWith(_ endingSequence: EndingSequence) -> RuleCollection.Rule {
    let openingSequence = startsWith ?? .anything
    let sentinels = openingSequence.sentinels
    let body = self.body ?? { _, _ in [] }
    let recognizer = bind(
      nodeType: type,
      sequenceRecognizer: concat(openingSequence.recognizer, scopeRecognizer(body, with: endingSequence.terminationBlock))
    )
    return RuleCollection.Rule(sentinels, recognizer)
  }

  public func endsWith(_ block: @escaping ScopedTextBuffer.Scope) -> RuleCollection.Rule {
    return endsWith(.block(block))
  }

  public func endsWith(_ string: String) -> RuleCollection.Rule {
    return endsWith(.literal(string))
  }
}

private extension RuleBuilder {
  func scopeRecognizer(
    _ recognizer: @escaping Recognizer,
    with endingSequenceBlock: ScopedTextBuffer.Scope?
  ) -> Recognizer {
    guard let endingSequenceBlock = endingSequenceBlock else {
      return recognizer
    }
    return { textBuffer, index in
      let scopedBuffer = ScopedTextBuffer(
        textBuffer: textBuffer,
        startIndex: index,
        scopeEnd: endingSequenceBlock
      )
      return recognizer(scopedBuffer, index)
    }
  }

  func scopeRecognizer(
    _ recognizer: @escaping SequenceRecognizer,
    with endingSequenceBlock: ScopedTextBuffer.Scope?
  ) -> SequenceRecognizer {
    guard let endingSequenceBlock = endingSequenceBlock else {
      return recognizer
    }
    return { textBuffer, index in
      let scopedBuffer = ScopedTextBuffer(
        textBuffer: textBuffer,
        startIndex: index,
        scopeEnd: endingSequenceBlock
      )
      return recognizer(scopedBuffer, index)
    }
  }
}

