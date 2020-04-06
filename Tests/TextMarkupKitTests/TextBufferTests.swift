//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation
import TextMarkupKit
import XCTest

final class TextBufferTests: XCTestCase {
  func testScopeEndingAfter() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    let iterator = buffer.makeIterator()
    iterator.pushingScope(.endingAfterPattern("**"))
    XCTAssertEqual(iterator.stringContents(), "This is content **")
    iterator.poppingScope()
    XCTAssertEqual(iterator.stringContents(), " with a double-asterisk")
  }

  func testScopeEndingBefore() {
    let buffer = PieceTable("This is content ** with a double-asterisk")
    let iterator = buffer.makeIterator()
    iterator.pushingScope(.endingBeforePattern("**"))
    XCTAssertEqual(iterator.stringContents(), "This is content ")
    iterator.poppingScope()
    XCTAssertEqual(iterator.stringContents(), "** with a double-asterisk")
  }

  func testScopeEndingBeforeAtEnd() {
    let buffer = PieceTable("Marker at end *")
    let iterator = buffer.makeIterator()
    iterator.pushingScope(.endingBeforePattern("*"))
    XCTAssertEqual(iterator.stringContents(), "Marker at end ")
    iterator.poppingScope()
    XCTAssertEqual(iterator.stringContents(), "*")
  }
}

private extension NSStringIterator {
  func stringContents() -> String {
    var chars = [unichar]()
    while let char = next() {
      chars.append(char)
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }
}
