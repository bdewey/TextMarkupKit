// 

import Foundation

extension NodeType {
  public static let text: NodeType = "text"
}

public struct TextSequenceRecognizer {
  public init(
    textRecognizers: [SentinelRecognizerCollection.Element],
    defaultType: NodeType
  ) {
    self.textRecognizers = SentinelRecognizerCollection(textRecognizers)
    self.defaultType = defaultType
  }

  public var textRecognizers: SentinelRecognizerCollection
  public var defaultType: NodeType

  public func parse(textBuffer: TextBuffer, position: TextBufferIndex) -> [Node] {
    var children = [Node]()
    var defaultRange = position ..< position
    var position = position
    while let character = textBuffer.character(at: position) {
      if textRecognizers.sentinels.contains(character.unicodeScalars.first!), let node = textRecognizers.recognizeNode(textBuffer: textBuffer, position: position) {
        if !defaultRange.isEmpty {
          let defaultNode = Node(type: defaultType, range: defaultRange)
          children.append(defaultNode)
        }
        children.append(node)
        position = node.range.upperBound
        defaultRange = position ..< position
      } else {
        position = textBuffer.index(after: position)!
      }
      defaultRange = defaultRange.settingUpperBound(position)
    }
    if !defaultRange.isEmpty {
      let defaultNode = Node(type: defaultType, range: defaultRange)
      children.append(defaultNode)
    }
    return children
  }
}

public extension TextSequenceRecognizer {
  static let miniMarkdown = TextSequenceRecognizer(
    textRecognizers: [DelimitedText.strongEmphasis, DelimitedText.emphasis],
    defaultType: .text
  )
}

private extension Range {
  func settingUpperBound(_ newUpperBound: Bound) -> Range<Bound> {
    return lowerBound ..< newUpperBound
  }
}
