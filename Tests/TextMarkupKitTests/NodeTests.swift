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

final class NodeTests: XCTestCase {
  func testAppendChild() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
    ]
    let root = Node(type: "root", range: 0 ..< 0)
    for (index, type) in childTypes.enumerated() {
      let childNode = Node(type: type, range: index ..< index + 1)
      root.appendChild(childNode)
    }
    XCTAssertEqual(root.range, 0 ..< 3)
    XCTAssertEqual(childTypes, root.children.map { $0.type })
  }

  func testAppendFragment() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
    ]
    let root = Node(type: "root", range: 0 ..< 0)
    let fragment = makeFragment(with: childTypes, startingIndex: 0)
    root.appendChild(fragment)
    XCTAssertEqual(root.range, 0 ..< 3)
    XCTAssertEqual(childTypes, root.children.map { $0.type })
  }

  func testChildlessSimilarityMerge() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
      "three",
    ]
    let root = Node(type: "root", range: 0 ..< 0)
    for (index, type) in childTypes.enumerated() {
      let childNode = Node(type: type, range: index ..< index + 1)
      root.appendChild(childNode)
    }
    XCTAssertEqual(root.range, 0 ..< 4)
    XCTAssertEqual(["one", "two", "three"], root.children.map { $0.type })
  }
}

private func makeFragment(with nodeTypes: [NodeType], startingIndex: Int) -> Node {
  let fragment = Node.makeFragment(at: startingIndex)
  for (index, type) in nodeTypes.enumerated() {
    let childNode = Node(type: type, range: startingIndex + index ..< startingIndex + index + 1)
    fragment.appendChild(childNode)
  }
  return fragment
}
