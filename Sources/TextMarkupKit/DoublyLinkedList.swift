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
  private var tail: Node

  public init() {
    self.count = 0
    self.tail = Node()
    self.head = tail
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

  public mutating func append(_ newElement: Element) {
    if !isKnownUniquelyReferenced(&head) {
      (head, tail) = head.copy()
    }
    count += 1
    let node = Node(newElement)
    tail.previous?.next = node
    node.previous = tail.previous
    node.next = tail
    tail.previous = node
    if head === tail {
      head = node
    }
  }

  public mutating func removeLast() -> Element {
    if !isKnownUniquelyReferenced(&head) {
      (head, tail) = head.copy()
    }
    let lastNode = tail.previous!
    lastNode.previous?.next = lastNode.next
    lastNode.next?.previous = lastNode.previous
    count -= 1
    return lastNode.payload!
  }

  @discardableResult
  public mutating func removeFirst() -> Element {
    if !isKnownUniquelyReferenced(&head) {
      (head, tail) = head.copy()
    }
    let oldHead = head
    head = oldHead.next!
    head.previous = nil
    count -= 1
    return oldHead.payload!
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

    fileprivate func replacingNode(_ newNode: Node, ifMatches node: Node) -> Index {
      if self.node === node {
        return Index(ordinal: ordinal, node: newNode)
      } else {
        return self
      }
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

  public mutating func replaceSubrange<R>(_ subrange: R, with newElements: DoublyLinkedList<Element>) where R: RangeExpression, Index == R.Bound {
    var range = subrange.relative(to: self)
    if !isKnownUniquelyReferenced(&head) {
      (head, tail) = head.copy(remapping: &range)
    }

    // TODO: Actually remove nodes
    let nodesToRemove = range.upperBound.ordinal - range.lowerBound.ordinal
    if nodesToRemove > 0 {
      range.lowerBound.node.previous?.next = range.upperBound.node
      range.upperBound.node.previous = range.lowerBound.node.previous
      if head === range.lowerBound.node {
        head = range.upperBound.node
      }
      count -= nodesToRemove
    }

    if newElements.isEmpty { return } // don't need to do more work
    let index = range.upperBound
    index.node.previous?.next = newElements.head
    newElements.head.previous = index.node.previous

    let lastPayloadNode = newElements.tail.previous
    lastPayloadNode?.next = index.node
    index.node.previous = lastPayloadNode

    if index.node === head {
      head = newElements.head
    }
    count += newElements.count
  }

  public mutating func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C: Collection, R: RangeExpression, Element == C.Element, Index == R.Bound {
    replaceSubrange(subrange, with: DoublyLinkedList(newElements))
  }
}

// MARK: - Private

private extension DoublyLinkedList {
  final class Node: CustomStringConvertible, Sequence {
    init(_ payload: Element? = nil) {
      self.payload = payload
    }

    let payload: Element?
    var next: Node?
    unowned var previous: Node?

    func copy(remapping range: inout Range<Index>) -> (start: Node, end: Node) {
      let start = Node(payload)
      range = Self.replacingNode(self, with: start, in: range)
      var end = start
      var current = self
      while let next = current.next {
        let node = Node(next.payload)
        range = Self.replacingNode(next, with: node, in: range)
        end.next = node
        node.previous = end
        current = next
        end = node
      }
      return (start, end)
    }

    func copy() -> (start: Node, end: Node) {
      let start = Node(payload)
      var end = start
      var current = self
      while let next = current.next {
        let node = Node(next.payload)
        end.next = node
        node.previous = end
        current = next
        end = node
      }
      return (start, end)
    }

    static func replacingNode(_ node: Node, with newNode: Node, in range: Range<Index>) -> Range<Index> {
      return range.lowerBound.replacingNode(newNode, ifMatches: node) ..< range.upperBound.replacingNode(newNode, ifMatches: node)
    }

    var description: String {
      let pointer = unsafeBitCast(self, to: Int.self)
      let pointerDescription = String(format: "<Node: %p>", pointer)
      let payloadDescription = payload.map { String(describing: $0) } ?? "nil"
      return "\(pointerDescription) \(payloadDescription)"
    }

    struct Iterator: IteratorProtocol {
      var node: Node?

      mutating func next() -> Node? {
        let value = node
        node = node?.next
        return value
      }
    }

    func makeIterator() -> Iterator {
      Iterator(node: self)
    }
  }
}
