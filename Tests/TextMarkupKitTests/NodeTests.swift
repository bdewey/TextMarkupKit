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
    let root = Node(type: "root")
    for type in childTypes {
      let childNode = Node(type: type, length: 1)
      root.appendChild(childNode)
    }
    XCTAssertEqual(root.length, 3)
    XCTAssertEqual(childTypes, root.children.map { $0.type })
  }

  func testAppendFragment() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
    ]
    let root = Node(type: "root")
    let fragment = makeFragment(with: childTypes)
    root.appendChild(fragment)
    XCTAssertEqual(root.length, 3)
    XCTAssertEqual(childTypes, root.children.map { $0.type })
  }

  func testChildlessSimilarityMerge() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "three",
      "three",
    ]
    let root = Node(type: "root")
    for type in childTypes {
      let childNode = Node(type: type, length: 1)
      root.appendChild(childNode)
    }
    XCTAssertEqual(root.length, 4)
    XCTAssertEqual(["one", "two", "three"], root.children.map { $0.type })
  }

  func testAppendFragmentDoesSimilarityMerge() {
    let childTypes: [NodeType] = [
      "one",
      "two",
      "one",
    ]
    let root = Node(type: "root")
    let fragment = makeFragment(with: childTypes)
    root.appendChild(fragment)
    XCTAssertEqual(root.length, 3)
    XCTAssertEqual(childTypes, root.children.map { $0.type })
    let fragment2 = makeFragment(with: childTypes)
    root.appendChild(fragment2)
    XCTAssertEqual(root.length, 6)
    XCTAssertEqual(["one", "two", "one", "two", "one"], root.children.map { $0.type })
  }
}

private func makeFragment(with nodeTypes: [NodeType]) -> Node {
  let fragment = Node.makeFragment()
  for type in nodeTypes {
    let childNode = Node(type: type, length: 1)
    fragment.appendChild(childNode)
  }
  return fragment
}
