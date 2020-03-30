// 

import Foundation

public struct TextMatchingRecognizer: NodeRecognizer {
  public init(type: NodeType, matchFunction: @escaping (Character) -> Bool) {
    self.type = type
    self.matchFunction = matchFunction
  }

  public let type: NodeType
  public let matchFunction: (Character) -> Bool

  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    var endPosition = position
    while textBuffer.character(at: endPosition).map(matchFunction) ?? false {
      endPosition = textBuffer.index(after: endPosition)!
    }
    guard endPosition > position else {
      return nil
    }
    return Node(type: type, range: position ..< endPosition, children: [])
  }
}
