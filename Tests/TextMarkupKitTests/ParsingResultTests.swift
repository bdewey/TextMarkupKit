// 

import Foundation
import TextMarkupKit
import XCTest

final class ParsingResultTests: XCTestCase {
  /// This is the "repeating a bunch of text" -- this is getting called once per character and no nodes get allocated here.
  /// the important thing is to just build up a range.
  func testZeroAllocationAccumulation() {
    var parent = ParsingResult(succeeded: true)
    for _ in 0 ..< 10 {
      let childResult = ParsingResult(succeeded: true, length: 1, examinedLength: 1)
      parent.appendChild(childResult)
    }
    XCTAssertEqual(parent.succeeded, true)
    XCTAssertEqual(parent.examinedLength, 10)
    XCTAssertEqual(parent.length, 10)
    XCTAssertNil(parent.node)

    // A single failure poisons the batch, and the "length" of failure is meaningless
    parent.appendChild(ParsingResult(succeeded: false, length: 1, examinedLength: 1))
    XCTAssertEqual(parent.succeeded, false)
    XCTAssertEqual(parent.examinedLength, 11)
    XCTAssertEqual(parent.length, 0)
  }

  func testNodeAccumulationsResultInFragment() {
    var parent = ParsingResult(succeeded: true)
    let nodeTypes: [NodeType] = [
      "one",
      "two",
      "three",
    ]
    for (index, type) in nodeTypes.enumerated() {
      let childResult = ParsingResult(
        succeeded: true,
        length: 1,
        examinedLength: 1,
        node: Node(type: type, range: index ..< index + 1)
      )
      parent.appendChild(childResult)
    }
    XCTAssertEqual(parent.succeeded, true)
    XCTAssertEqual(parent.examinedLength, 3)
    XCTAssertEqual(parent.length, 3)
    if let fragment = parent.node {
      XCTAssertTrue(fragment.isFragment)
      XCTAssertEqual(nodeTypes, fragment.children.map({ $0.type }))
    } else {
      XCTFail()
    }
  }
}
