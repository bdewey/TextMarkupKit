// 

import Foundation
import TextMarkupKit
import XCTest

final class TextBufferTests: XCTestCase {
  func testScopeEndingAfter() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    let iterator = buffer.makeIterator().iterator(endingAfter: "**")
    XCTAssertEqual(iterator.stringContents, "This is content **")
  }

  func testScopeEndingBefore() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    let iterator = buffer.makeIterator().iterator(endingBefore: "**")
    XCTAssertEqual(iterator.stringContents, "This is content ")
  }
}

private extension NSStringIterator {
  var stringContents: String {
    var i = self
    var chars = [unichar]()
    while let char = i.next() {
      chars.append(char)
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }
}
