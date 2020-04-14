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

  func testMerge() {
    let values1 = [1, 2, 3, 4, 5]
    let values2 = [6, 7, 8, 9]
    var expectedMergedValues = values1
    expectedMergedValues.append(contentsOf: values2)

    var list1 = makeList(from: values1)
    var list2 = makeList(from: values2)

    XCTAssertEqual(values1, list1.map { $0.payload })
    XCTAssertEqual(values2, list2.map { $0.payload })

    list1.merge(&list2)
    XCTAssertEqual(expectedMergedValues, list1.map { $0.payload })
    XCTAssertEqual(expectedMergedValues, list2.map { $0.payload })
  }

  private func makeList(from values: [Int]) -> DoublyLinkedList<IntListElement> {
    var list = DoublyLinkedList<IntListElement>()
    for value in values {
      let element = IntListElement(value)
      list.append(element)
    }
    return list
  }
}

private final class IntListElement: DoublyLinkedListLinksContaining, CustomStringConvertible {
  init(_ payload: Int) {
    self.payload = payload
  }

  let payload: Int
  var forwardLink: IntListElement?
  var backwardLink: IntListElement?

  var description: String {
    "IntListElement \(payload): back \(backwardLink?.payload ?? -1) forward \(forwardLink?.payload ?? -1)"
  }
}
