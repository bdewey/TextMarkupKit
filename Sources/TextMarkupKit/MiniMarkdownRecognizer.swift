// 

import Foundation

public protocol PieceTableParser {
  func parse(pieceTable: PieceTable) -> Node
}

public final class MiniMarkdownRecognizer: PieceTableParser {
  public init() {}
  
  public lazy var blockRecognizers: RuleCollection = [
    header,
    blankLine
  ]

  public lazy var styledTextRecognizers: RuleCollection = [
    strongEmphasis,
    emphasis,
    code,
  ]

  public let defaultTextType = NodeType.text

  public func parse(pieceTable: PieceTable) -> Node {
    var iterator: NSStringIterator = pieceTable.makeIterator()
    guard let node = parser(&iterator) else {
      assertionFailure()
      return Node(type: .markdownDocument, range: pieceTable.startIndex ..< pieceTable.endIndex)
    }
    return node
  }

  private lazy var parser = bind(nodeType: .markdownDocument, sequenceRecognizer: blockSequence)

  private lazy var blockSequence: SequenceRecognizer = { [weak self] iterator in
    guard let self = self else { return [] }
    var blocks = [Node]()
    repeat {
      if let node = self.blockRecognizers.recognize(iterator: &iterator) {
        blocks.append(node)
      } else if let node = self.paragraph.recognizer(&iterator) {
        blocks.append(node)
      } else {
        break
      }
    } while true
    return blocks
  }

  func styledText(iterator: inout NSStringIterator) -> [Node] {
    var children = [Node]()
    var defaultRange = iterator.index ..< iterator.index
    while let utf16 = iterator.peek() {
      if
        styledTextRecognizers.sentinels.characterIsMember(utf16),
        let node = styledTextRecognizers.recognize(iterator: &iterator) {
        if !defaultRange.isEmpty {
          let defaultNode = Node(type: defaultTextType, range: defaultRange)
          children.append(defaultNode)
        }
        children.append(node)
        defaultRange = iterator.index ..< iterator.index
      } else {
        _ = iterator.next()
      }
      defaultRange = defaultRange.settingUpperBound(iterator.index)
    }
    if !defaultRange.isEmpty {
      let defaultNode = Node(type: defaultTextType, range: defaultRange)
      children.append(defaultNode)
    }
    return children
  }

  let anything: SequenceRecognizer = { iterator in
    let startIndex = iterator.index
    while iterator.next() != nil {
    }
    return [Node(type: .text, range: startIndex ..< iterator.index)]
  }

  func styledText(_ type: NodeType) -> Recognizer {
    return { [weak self] iterator in
      guard let self = self else { return nil }
      let children = self.styledText(iterator: &iterator)
      if let range = children.encompassingRange {
        return Node(type: type, range: range, children: children)
      } else {
        return nil
      }
    }
  }

  // MARK: - blocks

  private lazy var header = RuleBuilder(.header)
    .startsWith(.repeating(.octothorpe, allowableRange: 1 ..< 7))
    .then(styledText)
    .endsAfter(.paragraphTermination)
    .build()


  private lazy var blankLine = RuleBuilder(.blankLine)
    .startsWith("\n")
    .build()

  lazy var paragraph = RuleBuilder(.paragraph)
    .startsWith(.anything)
    .then(styledText)
    .endsAfter(.paragraphTermination)
    .build()

  // MARK: - text

  private lazy var strongEmphasis = delimitedText(.strongEmphasis, leftDelimiter: "**")
  private lazy var emphasis = delimitedText(.emphasis, leftDelimiter: "*")
  private lazy var code = delimitedText(.code, leftDelimiter: "`")
}

// MARK: - Paragraphs
struct ParagraphTerminationPattern: Pattern {
  let sentinels: CharacterSet = ["\n"]
  private let paragraphTermination: CharacterSet = ["\n", "#"]

  func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult {
    guard character == .newline else {
      return .no
    }
    if let nextChar = iterator.peek() {
      return paragraphTermination.contains(nextChar) ? .yes : .no
    } else {
      return .yes
    }
  }
}

// TODO: Move this to a separate file
extension CharacterSet {
  func contains(_ char: unichar) -> Bool {
    guard let scalar = UnicodeScalar(char) else {
      assertionFailure()
      return false
    }
    return contains(scalar)
  }
}

extension AnyPattern {
  static let paragraphTermination = ParagraphTerminationPattern().asAnyPattern()
}

// MARK: - Helpers
// TODO: Consider moving these to the base class

private extension MiniMarkdownRecognizer {
  func delimitedText(_ type: NodeType, leftDelimiter: String, maybeRightDelimiter: String? = nil) -> RuleCollection.Rule {
    let rightDelimiter = maybeRightDelimiter ?? leftDelimiter
    return RuleBuilder(type)
      .startsWith(.stringPattern(leftDelimiter))
      .then(anything)
      .endsWith(.stringPattern(rightDelimiter))
      .build()
  }
}

// TODO: Maybe create Range+Extensions.swift
private extension Range {
  func settingUpperBound(_ newUpperBound: Bound) -> Range<Bound> {
    return lowerBound ..< newUpperBound
  }
}
