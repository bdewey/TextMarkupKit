// 

import Foundation
import TextMarkupKit
import XCTest

final class NodeTests: XCTestCase {
  func testAppendChild() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
    ]
    let root = Node(type: "root", range: 0..<0)
    for (index, type) in childTypes.enumerated() {
      let childNode = Node(type: type, range: index ..< index + 1)
      root.appendChild(childNode)
    }
    XCTAssertEqual(root.range, 0 ..< 3)
    XCTAssertEqual(childTypes, root.children.map({ $0.type }))
  }
}
