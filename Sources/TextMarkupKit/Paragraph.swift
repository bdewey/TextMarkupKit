// 

import Foundation

public struct Paragraph: UnconditionalParser {
  public init() { }
  private let paragraphTermination: CharacterSet = [
    "#",
    "\n",
  ]

  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node {
    var currentPosition = position
    repeat {
      currentPosition = textBuffer.index(after: "\n", startingAt: currentPosition)
    } while !paragraphTermination.contains(textBuffer.unicodeScalar(at: currentPosition), includesNil: true)
    return Node(type: "paragraph", range: position ..< currentPosition, children: [])
  }
}
