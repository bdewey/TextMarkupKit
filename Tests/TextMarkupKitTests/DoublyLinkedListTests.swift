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
      list.insert(value, at: list.endIndex)
    }
    XCTAssertEqual(values, list.map { $0 })
  }

  func testInsertAtHead() {
    let values = [1, 2, 3, 4, 5]
    let list = DoublyLinkedList<Int>()
    for value in values {
      list.insert(value, at: list.startIndex)
    }
    XCTAssertEqual(values.reversed(), list.map { $0 })
  }

//  func testMergeLists() {
//    let list1: DoublyLinkedList<Int> = [1, 2, 3, 4, 5]
//    let list2: DoublyLinkedList<Int> = [6, 7, 8, 9, 0]
//
//    let fusePoint = list1.fuse(list2)
//    XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], list1.map { $0 })
//    XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], list2.map { $0 })
//    XCTAssertEqual([5, 6, 7, 8, 9, 0], list1[fusePoint ..< list1.endIndex].map { $0 })
//    list1.remove(at: fusePoint)
//    XCTAssertEqual([1, 2, 3, 4, 6, 7, 8, 9, 0], list1.map { $0 })
//  }

  func testRemoveOnlyNode() {
    let list: DoublyLinkedList<Int> = [312]
    list.remove(at: list.startIndex)
    XCTAssertTrue(list.isEmpty)
  }

  func testRemoveFirstItem() {
    let list: DoublyLinkedList<Int> = [1, 2]
    list.remove(at: list.startIndex)
    XCTAssertEqual([2], list.map { $0 })
  }

  func testRemoveLastItem() {
    let list: DoublyLinkedList<Int> = [1, 2]
    let lastValidIndex = list.index(before: list.endIndex)
    list.remove(at: lastValidIndex)
    XCTAssertEqual([1], list.map { $0 })
  }
}
