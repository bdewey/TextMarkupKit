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

public protocol DoublyLinkedListLinksContaining: AnyObject {
  var forwardLink: Self? { get set }
  var backwardLink: Self? { get set }
}

public extension DoublyLinkedListLinksContaining {
  func makeForwardLink(to element: Self) {
    if let forwardElement = forwardLink {
      forwardElement.backwardLink = element
    }
    element.forwardLink = forwardLink
    forwardLink = element
    element.backwardLink = self
  }

  func makeBackwardLink(to element: Self) {
    if let backwardElement = backwardLink {
      backwardElement.forwardLink = element
    }
    element.backwardLink = backwardLink
    backwardLink = element
    element.forwardLink = self
  }
}

public struct DoublyLinkedList<Element: DoublyLinkedListLinksContaining> {
  public init() {}

  private var listEnds: (head: Element, tail: Element)?

  public var isEmpty: Bool { listEnds == nil }

  public var first: Element? {
    guard let listEnds = listEnds else {
      return nil
    }
    return listEnds.head
  }

  public var last: Element? {
    guard let listEnds = listEnds else {
      return nil
    }
    return listEnds.tail
  }

  public mutating func append(_ element: Element) {
    if let listEnds = listEnds {
      listEnds.tail.makeForwardLink(to: element)
      self.listEnds = (head: listEnds.head, tail: element)
    } else {
      listEnds = (head: element, tail: element)
    }
  }

  public mutating func merge(_ other: inout DoublyLinkedList<Element>) {
    switch (listEnds, other.listEnds) {
    case (.some(let listEnds), .some(let otherListEnds)):
      listEnds.tail.forwardLink = otherListEnds.head
      otherListEnds.head.backwardLink = listEnds.tail
      let newListEnds = (head: listEnds.head, tail: otherListEnds.tail)
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
    var current: Element?

    public mutating func next() -> Element? {
      guard let current = current else { return nil }
      self.current = current.forwardLink
      return current
    }
  }

  public func makeIterator() -> Iterator {
    return Iterator(current: listEnds.map { $0.head })
  }
}
