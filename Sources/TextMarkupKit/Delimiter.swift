// 

import Foundation

extension NodeType {
  static let delimiter: NodeType = "delimiter"
}

public struct Delimiter: NodeRecognizer {
  public init(_ delimiter: String) {
    self.delimiter = delimiter
  }

  public let delimiter: String

  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    var currentPosition = position
    for character in delimiter {
      guard character == textBuffer.character(at: currentPosition), let nextPosition = textBuffer.index(after: currentPosition) else {
        return nil
      }
      currentPosition = nextPosition
    }
    return Node(type: .delimiter, range: position ..< currentPosition)
  }
}
