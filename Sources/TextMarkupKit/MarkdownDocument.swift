// 

import Foundation

extension NodeType {
  public static let markdownDocument: NodeType = "document"
  public static let paragraph: NodeType = "paragraph"
}

public struct MarkdownDocument: UnconditionalParser {
  public init(
    subparsers: [SentinelParser] = [
      Header(),
      BlankLine(),
    ],
    defaultParser: UnconditionalParser = Paragraph()
  ) {
    self.subparsers = SentinelParserCollection(subparsers)
    self.defaultParser = defaultParser
  }

  public var subparsers: SentinelParserCollection
  public let defaultParser: UnconditionalParser

  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node {
    var children = [Node]()
    var position = position
    while let scalar = textBuffer.unicodeScalar(at: position) {
      if
        subparsers.sentinels.contains(scalar),
        let node = subparsers.parse(textBuffer: textBuffer, position: position)
      {
        children.append(node)
        position = node.range.upperBound
      } else {
        let paragraphNode = defaultParser.parse(textBuffer: textBuffer, position: position)
        children.append(paragraphNode)
        position = paragraphNode.range.upperBound
      }
    }
    return Node(type: .markdownDocument, range: position ..< position, children: children)
  }
}
