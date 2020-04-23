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
  func testInsertAtTail() {
    let values = [1, 2, 3, 4, 5]
    let list = DoublyLinkedList<Int>()
    for value in values {
      list.insertAtTail(value)
    }
    XCTAssertEqual(values, list.map { $0 })
  }

  func testInsertAtHead() {
    let values = [1, 2, 3, 4, 5]
    let list = DoublyLinkedList<Int>()
    for value in values {
      list.insertAtHead(value)
    }
    XCTAssertEqual(values.reversed(), list.map { $0 })
  }

  func testMergeLists() {
    let list1: DoublyLinkedList<Int> = [1, 2, 3, 4, 5]
    let list2: DoublyLinkedList<Int> = [6, 7, 8, 9, 0]

    list1.mergeAtTail(list2)
    XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], list1.map { $0 })
    XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], list2.map { $0 })
  }
}
