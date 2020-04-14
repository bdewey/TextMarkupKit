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
public final class Node: CustomStringConvertible, DoublyLinkedListLinksContaining {
  public init(type: NodeType, range: Range<Int>) {
    self.type = type
    self.range = range
  }

  /// The type of this node.
  public var type: NodeType

  /// The range from the original `TextBuffer` that this node in the syntax tree covers.
  public var range: Range<Int>

  /// Siblings of this node
  public var forwardLink: Node?
  public var backwardLink: Node?

  /// Children of this node.
  public var children = DoublyLinkedList<Node>()

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return range.isEmpty
  }

  public var description: String {
    "Node: \(range) \(compactStructure)"
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
