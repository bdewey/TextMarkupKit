// 

import Foundation

public struct DelimitedText: NodeRecognizer, SentinelContaining {
  public let type: NodeType
  public let leftDelimiter: String
  public let rightDelimiter: String

  public var sentinels: CharacterSet { CharacterSet(charactersIn: leftDelimiter) }

  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    guard let leftNode = Delimiter(leftDelimiter).recognizeNode(textBuffer: textBuffer, position: position) else {
      return nil
    }
    return nil 
  }
}
