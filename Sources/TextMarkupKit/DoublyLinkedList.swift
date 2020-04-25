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

public struct DoublyLinkedList<Element>: ExpressibleByArrayLiteral {
  public private(set) var count: Int
  private var head: Node
  private let tail: Node

  public init() {
    count = 0
    tail = Node()
    head = tail
  }

  public init<S: Sequence>(_ elements: S) where S.Element == Element {
    var head: Node?
    var tail: Node?
    var count = 0
    for element in elements {
      count += 1
      let node = Node(element)
      head = head ?? node
      node.previous = tail
      tail?.next = node
      tail = node
    }
    let sentinel = Node()
    head = head ?? sentinel
    sentinel.previous = tail
    tail?.next = sentinel

    self.count = count
    self.head = head!
    self.tail = sentinel
  }

  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

  public var isEmpty: Bool {
    count == 0
  }

  public var last: Element? {
    tail.previous?.payload
  }
}

extension DoublyLinkedList: BidirectionalCollection, RangeReplaceableCollection {
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

  public mutating func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C : Collection, R : RangeExpression, Element == C.Element, Index == R.Bound {
    // TODO: Make a deep copy if needed
    let range = subrange.relative(to: self)

    // TODO: Actually remove nodes

    if newElements.isEmpty { return } // don't need to do more work
    let list = DoublyLinkedList(newElements)
    let index = range.upperBound
    index.node.previous?.next = list.head
    list.head.previous = index.node.previous

    let lastPayloadNode = list.tail.previous
    lastPayloadNode?.next = index.node
    index.node.previous = lastPayloadNode

    if index.node === head {
      head = list.head
    }
    count += list.count
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
