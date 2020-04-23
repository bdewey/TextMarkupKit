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
  private var forwardLink: DoublyLinkedList<Element>!
  private unowned var backwardLink: DoublyLinkedList<Element>!
  private var element: Element?

  public init() {
    self.element = nil
    self.forwardLink = self
    self.backwardLink = self
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

  private init(_ element: Element) {
    self.element = element
    self.forwardLink = self
    self.backwardLink = self
  }

  public func insertAtHead(_ element: Element) {
    let node = DoublyLinkedList(element)
    forwardLink.backwardLink = node
    node.forwardLink = forwardLink
    node.backwardLink = self
    forwardLink = node
  }

  public func insertAtTail(_ element: Element) {
    let node = DoublyLinkedList(element)
    backwardLink.forwardLink = node
    node.backwardLink = backwardLink
    node.forwardLink = self
    backwardLink = node
  }

  public func mergeAtTail(_ other: DoublyLinkedList<Element>) {
    backwardLink.forwardLink = other.forwardLink
    other.forwardLink.backwardLink = backwardLink
    backwardLink = other.backwardLink
    other.forwardLink = forwardLink
  }
}

extension DoublyLinkedList: Sequence {
  public struct Iterator: IteratorProtocol {
    let listEnd: DoublyLinkedList<Element>
    var nextNode: DoublyLinkedList<Element>

    public mutating func next() -> Element? {
      if nextNode === listEnd {
        return nil
      }
      let nextElement = nextNode.element
      nextNode = nextNode.forwardLink
      return nextElement
    }
  }

  public func makeIterator() -> Iterator {
    Iterator(listEnd: self, nextNode: forwardLink)
  }
}

// MARK: - Private

private extension DoublyLinkedList {}
