// 

import Foundation

extension NodeType {
  public static let blankLine: NodeType = "blank_line"
}

public struct BlankLine: SentinelParser {
  public init() {}
  public var sentinels: CharacterSet { CharacterSet(charactersIn: "\n") }
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    guard
      let nextPosition = textBuffer.index(after: position),
      textBuffer.character(at: position) == "\n"
    else {
      return nil
    }
    return Node(type: .blankLine, range: position ..< nextPosition)
  }
}
