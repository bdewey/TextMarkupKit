// 

import Foundation
import TextMarkupKit
import XCTest

final class DoublyLinkedListTests: XCTestCase {
  func testAppendAndEnumerate() {
    let values = [1, 2, 3, 4, 5]
    var list = DoublyLinkedList<IntListElement>()

    for value in values {
      let element = IntListElement(value)
      list.append(element)
    }

    XCTAssertEqual(values, list.map { $0.payload })
  }
}

private final class IntListElement: DoublyLinkedListLinksContaining {
  init(_ payload: Int) {
    self.payload = payload
  }

  let payload: Int
  var forwardLink: IntListElement?
  var backwardLink: IntListElement?
}
