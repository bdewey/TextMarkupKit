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

extension NodeType {
  static let documentFragment: NodeType = "{{fragment}}"
}

/// A node in the markup language's syntax tree.
public final class Node: CustomStringConvertible {
  public init(type: NodeType, range: Range<Int>) {
    self.type = type
    self.range = range
  }

  /// The type of this node.
  public var type: NodeType

  /// If true, this node should be considered a "fragment" (an ordered list of nodes without a root)
  public var isFragment: Bool {
    return type === NodeType.documentFragment
  }

  /// The range from the original `TextBuffer` that this node in the syntax tree covers.
  public var range: Range<Int>

  /// Siblings of this node
  public var forwardLink: Node?
  public var backwardLink: Node?

  /// Children of this node.
  public var children = Children()

  public func appendChild(_ child: Node) {
    range = range.lowerBound ..< child.range.upperBound
    children.append(child)
  }

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return range.isEmpty
  }

  public var description: String {
    "Node: \(range) \(compactStructure)"
  }
}

// MARK: - Tree management

public extension Node {
  struct Children {
    private var listEnds: (head: Node, tail: Node)?

    public var isEmpty: Bool { listEnds == nil }

    public var first: Node? {
      guard let listEnds = listEnds else {
        return nil
      }
      return listEnds.head
    }

    public var last: Node? {
      guard let listEnds = listEnds else {
        return nil
      }
      return listEnds.tail
    }

    public mutating func append(_ element: Node) {
      if let listEnds = listEnds {
        listEnds.tail.appendSibling(element)
        self.listEnds = (head: listEnds.head, tail: element)
      } else {
        listEnds = (head: element, tail: element)
      }
    }

    public mutating func merge(_ other: inout Children) {
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

  private func appendSibling(_ sibling: Node) {
    if let currentSibling = forwardLink {
      currentSibling.backwardLink = sibling
    }
    sibling.forwardLink = forwardLink
    forwardLink = sibling
    sibling.backwardLink = self
  }
}

// MARK: - Enumerating children

extension Node.Children: Sequence {
  public struct Iterator: IteratorProtocol {
    var current: Node?

    public mutating func next() -> Node? {
      guard let current = current else { return nil }
      self.current = current.forwardLink
      return current
    }
  }

  public func makeIterator() -> Iterator {
    return Iterator(current: listEnds.map { $0.head })
  }
}

// MARK: - Debugging support

extension Node {
  /// Returns the structure of this node as a compact s-expression.
  /// For example, `(document ((header text) blank_line paragraph blank_line paragraph)`
  public var compactStructure: String {
    var results = ""
    writeCompactStructure(to: &results)
    return results
  }

  /// Recursive helper for generating `compactStructure`
  private func writeCompactStructure(to buffer: inout String) {
    if children.isEmpty {
      buffer.append(type.rawValue)
    } else {
      buffer.append("(")
      buffer.append(type.rawValue)
      buffer.append(" ")
      for (index, child) in children.enumerated() {
        if index > 0 {
          buffer.append(" ")
        }
        child.writeCompactStructure(to: &buffer)
      }
      buffer.append(")")
    }
  }

  /// Returns the syntax tree and which parts of `textBuffer` the leaf nodes correspond to.
  public func debugDescription(withContentsFrom pieceTable: PieceTable) -> String {
    var lines = [String]()
    writeDebugDescription(to: &lines, pieceTable: pieceTable, indentLevel: 0)
    return lines.joined(separator: "\n")
  }

  /// Recursive helper function for `debugDescription(of:)`
  private func writeDebugDescription(
    to lines: inout [String],
    pieceTable: PieceTable,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append(type.rawValue)
    result.append(": ")
    if children.isEmpty {
      result.append(pieceTable[range].debugDescription)
    }
    lines.append(result)
    for child in children {
      child.writeDebugDescription(to: &lines, pieceTable: pieceTable, indentLevel: indentLevel + 1)
    }
  }
}
