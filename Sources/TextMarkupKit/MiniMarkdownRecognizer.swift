// 

import Foundation

public final class MiniMarkdownRecognizer: Parser {
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

  public func parse(textBuffer: TextBuffer, position: Int) -> Node {
    return parser(textBuffer, position)!
  }

  private lazy var parser = bind(nodeType: .markdownDocument, sequenceRecognizer: blockSequence)

  private lazy var blockSequence: SequenceRecognizer = { [weak self] textBuffer, index in
    guard let self = self else { return [] }
    var blocks = [Node]()
    var currentPosition = index
    repeat {
      if let node = self.blockRecognizers.recognizeNode(textBuffer: textBuffer, position: currentPosition) {
        blocks.append(node)
        currentPosition = node.range.upperBound
      } else if let node = self.paragraph.recognizer(textBuffer, currentPosition) {
        blocks.append(node)
        currentPosition = node.range.upperBound
      } else {
        break
      }
    } while true
    return blocks
  }

  func styledText(textBuffer: TextBuffer, index: Int) -> [Node] {
    var children = [Node]()
    var defaultRange = index ..< index
    var index = index
    while let utf16 = textBuffer.utf16(at: index) {
      if
        styledTextRecognizers.sentinels.characterIsMember(utf16),
        let node = styledTextRecognizers.recognizeNode(textBuffer: textBuffer, position: index) {
        if !defaultRange.isEmpty {
          let defaultNode = Node(type: defaultTextType, range: defaultRange)
          children.append(defaultNode)
        }
        children.append(node)
        index = node.range.upperBound
        defaultRange = index ..< index
      } else {
        index += 1
      }
      defaultRange = defaultRange.settingUpperBound(index)
    }
    if !defaultRange.isEmpty {
      let defaultNode = Node(type: defaultTextType, range: defaultRange)
      children.append(defaultNode)
    }
    return children
  }

  let anything: SequenceRecognizer = { textBuffer, index in
    var endIndex = index
    while textBuffer.utf16(at: endIndex) != nil {
      endIndex += 1
    }
    return [Node(type: .text, range: index ..< endIndex)]
  }

  func styledText(_ type: NodeType) -> Recognizer {
    return { [weak self] textBuffer, index in
      guard let self = self else { return nil }
      let children = self.styledText(textBuffer: textBuffer, index: index)
      if let range = children.encompassingRange {
        return Node(type: type, range: range, children: children)
      } else {
        return nil
      }
    }
  }

  // MARK: - blocks

  private lazy var header = RuleBuilder(.header)
    .startsWith(.pattern("#", min: 1, max: 6))
    .then(anything)
    .endsWith(Self.paragraphTermination)

//  let blankLine = SentinelRecognizer(["\n"]) { textBuffer, position in
//    guard
//      textBuffer.utf16(at: position) == unichar.newline,
//      textBuffer.utf16(at: position + 1) != nil
//    else {
//      return nil
//    }
//    return Node(type: .blankLine, range: position ..< position + 1)
//  }

  private lazy var blankLine = RuleBuilder(.blankLine)
    .startsWith(.pattern("\n", min: 1, max: 1))
    .endsWith(Self.paragraphTermination)

  lazy var paragraph = RuleBuilder(.paragraph)
    .startsWith(.anything)
    .then(styledText)
    .endsWith(Self.paragraphTermination)

  // MARK: - text

  private(set) lazy var strongEmphasis = delimitedText(.strongEmphasis, leftDelimiter: "**")
  private(set) lazy var emphasis = delimitedText(.emphasis, leftDelimiter: "*")
  private(set) lazy var code = delimitedText(.code, leftDelimiter: "`")
}

//struct RecognizerBuilder {
//  var type: NodeType?
//  var filter: TextBufferFilter?
//  var sequence: TextRecognizer.SequenceRecognizer?
//
//  func build() -> TextRecognizer.Recognizer {
//    guard let sequence = sequence else {
//      assertionFailure()
//      return { _, _ in nil }
//    }
//    let recognizer = bind(nodeType: type ?? .anonymous, sequenceRecognizer: sequence)
//    if let filter = filter {
//      return { textBuffer, index in
//        let filteringTextBuffer = FilteringTextBuffer(textBuffer: textBuffer, startIndex: index, isIncluded: filter)
//        return recognizer(filteringTextBuffer, index)
//      }
//    } else {
//      return recognizer
//    }
//  }
//
//  private func bind(nodeType: NodeType, sequenceRecognizer: @escaping TextRecognizer.SequenceRecognizer) -> TextRecognizer.Recognizer {
//    return { textBuffer, index in
//      let children = sequenceRecognizer(textBuffer, index)
//      guard let range = children.encompassingRange else {
//        return nil
//      }
//      return Node(type: nodeType, range: range, children: children)
//    }
//  }
//}

// MARK: - Paragraphs
private extension MiniMarkdownRecognizer {
  private static let paragraphTerminationCharacters = NSCharacterSet(charactersIn: "#\n")

  /// True if a character belongs to a paragraph. Criteria for a paragraph boundary:
  /// 1. `character` is a member of `paragraphTermination`
  /// 2. The *previous* character is a newline.
  /// A character that meets this criteria is the first character in a **new** block and gets filtered out.
  static func paragraphTermination(
    character: unichar,
    textBuffer: TextBuffer,
    index: Int
  ) -> Bool {
    if paragraphTerminationCharacters.characterIsMember(character), textBuffer.utf16(at: index - 1) == .newline {
      return true
    }
    return false
  }
}

// MARK: - Helpers
// TODO: Consider moving these to the base class

private extension MiniMarkdownRecognizer {
  func delimitedText(_ type: NodeType, leftDelimiter: String, maybeRightDelimiter: String? = nil) -> RuleCollection.Rule {
    let rightDelimiter = maybeRightDelimiter ?? leftDelimiter
    return RuleBuilder(type).startsWith(leftDelimiter).then(anything).endsWith(rightDelimiter)
  }
}

// TODO: Maybe create Range+Extensions.swift
private extension Range {
  func settingUpperBound(_ newUpperBound: Bound) -> Range<Bound> {
    return lowerBound ..< newUpperBound
  }
}
