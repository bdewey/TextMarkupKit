// 

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
  public init() { }
  
  private var head: Element?
  private var tail: Element?

  public mutating func append(_ element: Element) {
    if let tail = tail {
      tail.makeForwardLink(to: element)
      self.tail = element
    } else {
      assert(head == nil)
      head = element
      tail = element
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
    return Iterator(current: head)
  }
}
