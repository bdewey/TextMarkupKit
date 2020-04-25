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
  private var head: Node
  private let tail: Node

  public init() {
    count = 0
    tail = Node()
    head = tail
  }

  public convenience init<S: Sequence>(_ elements: S) where S.Element == Element {
    self.init()
    for element in elements {
      insert(element, at: endIndex)
    }
  }

  public convenience init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

  public private(set) var count: Int

  public var isEmpty: Bool {
    count == 0
  }

  public var last: Element? {
    tail.previous?.payload
  }

  public func insert(_ element: Element, at index: Index) {
    let node = Node(element)
    index.node.previous?.next = node
    node.previous = index.node.previous
    node.next = index.node
    index.node.previous = node
    count += 1
    if index.node === head {
      head = node
    }
  }

//  public func fuse(_ other: DoublyLinkedList<Element>) -> Index {
//    let originalCount = count
//    count += other.count
//    other.count = count
//    switch (listEnds, other.listEnds) {
//    case (.some(let listEnds), .some(let otherListEnds)):
//      let fuseIndex = Index(ordinal: originalCount - 1, node: listEnds.tail)
//      listEnds.tail.forwardLink = otherListEnds.head
//      otherListEnds.head.backwardLink = listEnds.tail
//      let newListEnds = ListEnds(head: listEnds.head, tail: otherListEnds.tail)
//      self.listEnds = newListEnds
//      other.listEnds = newListEnds
//      return fuseIndex
//    case (.none, .some(let otherListEnds)):
//      listEnds = otherListEnds
//      return Index(ordinal: count - 1, node: otherListEnds.tail)
//    case (.some(let listEnds), .none):
//      other.listEnds = listEnds
//      return Index(ordinal: count - 1, node: listEnds.tail)
//    case (.none, .none):
//      return endIndex
//    }
//  }

  @discardableResult
  public func remove(at index: Index) -> Element {
    precondition(index != endIndex)
    let node = index.node
    count -= 1
    node.previous?.next = node.next
    node.next?.previous = node.previous
    if node === head {
      // Only the end index has a nil forwardLink
      head = node.next!
    }
    return node.payload!
  }
}

extension DoublyLinkedList: BidirectionalCollection {
  public struct Index: Comparable {
    fileprivate let ordinal: Int
    fileprivate let node: Node

    public static func < (lhs: DoublyLinkedList.Index, rhs: DoublyLinkedList.Index) -> Bool {
      return lhs.node !== rhs.node && lhs.ordinal < rhs.ordinal
    }

    public static func == (lhs: DoublyLinkedList.Index, rhs: DoublyLinkedList.Index) -> Bool {
      return lhs.node === rhs.node
    }
  }

  public var startIndex: Index {
    Index(ordinal: 0, node: head)
  }

  public var endIndex: Index {
    Index(ordinal: count, node: tail)
  }

  public subscript(position: Index) -> Element {
    // node is non-nil for everything except `endIndex`. It's an error to subscript the end index,
    // so crashing is the right thing.
    position.node.payload!
  }

  public func index(after i: Index) -> Index {
    Index(ordinal: i.ordinal + 1, node: i.node.next!)
  }

  public func index(before i: Index) -> Index {
    precondition(i.ordinal > 0)
    return Index(ordinal: i.ordinal - 1, node: i.node.previous!)
  }
}

// MARK: - Private

private extension DoublyLinkedList {
  final class Node {
    init(_ payload: Element? = nil) {
      self.payload = payload
    }

    let payload: Element?
    var isSentinel: Bool { payload == nil }
    var next: Node?
    unowned var previous: Node?
  }
}
