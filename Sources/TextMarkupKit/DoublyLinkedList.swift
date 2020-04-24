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

public final class DoublyLinkedList<Element>: ExpressibleByArrayLiteral {
  private var listEnds: ListEnds?

  public init() {
    count = 0
  }

  public convenience init<S: Sequence>(_ elements: S) where S.Element == Element {
    self.init()
    for element in elements {
      insertAtTail(element)
    }
  }

  public convenience init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

  public private(set) var count: Int

  public var isEmpty: Bool {
    return listEnds == nil
  }

  public var last: Element? {
    return listEnds?.tail.payload
  }

  public func insertAtHead(_ element: Element) {
    count += 1
    let node = Node(element)
    if var listEnds = listEnds {
      listEnds.head.backwardLink = node
      node.forwardLink = listEnds.head
      listEnds.head = node
      node.backwardLink = nil
      self.listEnds = listEnds
    } else {
      self.listEnds = ListEnds(head: node, tail: node)
    }
  }

  public func insertAtTail(_ element: Element) {
    count += 1
    let node = Node(element)
    if var listEnds = listEnds {
      listEnds.tail.forwardLink = node
      node.backwardLink = listEnds.tail
      listEnds.tail = node
      node.forwardLink = nil
      self.listEnds = listEnds
    } else {
      self.listEnds = ListEnds(head: node, tail: node)
    }
  }

  public func mergeAtTail(_ other: DoublyLinkedList<Element>) {
    count += other.count
    other.count = count
    switch (listEnds, other.listEnds) {
    case (.some(let listEnds), .some(let otherListEnds)):
      listEnds.tail.forwardLink = otherListEnds.head
      otherListEnds.head.backwardLink = listEnds.tail
      let newListEnds = ListEnds(head: listEnds.head, tail: otherListEnds.tail)
      self.listEnds = newListEnds
      other.listEnds = newListEnds
    case (.none, .some(let otherListEnds)):
      listEnds = otherListEnds
    case (.some(let listEnds), .none):
      other.listEnds = listEnds
    case (.none, .none):
      break
    }
  }
}

extension DoublyLinkedList: Sequence {
  public struct Iterator: IteratorProtocol {
    fileprivate var nextNode: Node?

    public mutating func next() -> Element? {
      let nextElement = nextNode?.payload
      nextNode = nextNode?.forwardLink
      return nextElement
    }
  }

  public func makeIterator() -> Iterator {
    Iterator(nextNode: listEnds?.head)
  }
}

// MARK: - Private

private extension DoublyLinkedList {
  struct ListEnds {
    var head: Node
    var tail: Node
  }

  class Node {
    init(_ payload: Element) {
      self.payload = payload
    }

    let payload: Element
    var forwardLink: Node?
    unowned var backwardLink: Node?
  }
}
