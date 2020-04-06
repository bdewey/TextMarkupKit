// 

import Foundation
import TextMarkupKit
import XCTest

final class TextBufferTests: XCTestCase {
  func testScopeEndingAfter() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    var iterator = buffer.makeIterator().pushScope(.endAfterPattern, pattern: "**")
    XCTAssertEqual(iterator.stringContents(), "This is content **")
    iterator = iterator.popScope()
    XCTAssertEqual(iterator.stringContents(), " with a double-asterisk")
  }

  func testScopeEndingBefore() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    var iterator = buffer.makeIterator().pushScope(.endBeforePattern, pattern: "**")
    XCTAssertEqual(iterator.stringContents(), "This is content ")
    iterator = iterator.popScope()
    XCTAssertEqual(iterator.stringContents(), "** with a double-asterisk")
  }
}

private extension NSStringIterator {
  mutating func stringContents() -> String {
    var chars = [unichar]()
    while let char = next() {
      chars.append(char)
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }
}
