// 

import Foundation

extension NodeType {
  public static let header: NodeType = "header"
}

public struct Header: SequenceParser, SentinelParser {
  public init() { }
  public var sentinels: CharacterSet { CharacterSet(charactersIn: "#") }
  public var type: NodeType { .header }
  public let parseFunction = Node.sequence(of: [
    Node.text(matching: { $0 == "#" }, named: "delimiter"),
    Node.text(matching: { $0.unicodeScalars.first!.properties.isPatternWhitespace }),
    Node.text(upToAndIncluding: "\n", named: "text"),
  ])
}
