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

/// A key for associating values of a specific type with a node.
public protocol NodePropertyKey {
  associatedtype Value

  /// The string key used to identify the value in the property bag.
  static var key: String { get }

  /// Type-safe accessor for getting the value from the property bag.
  static func getProperty(from bag: [String: Any]?) -> Value?

  /// Type-safe setter for the value in the property bag.
  static func setProperty(_ value: Value, in bag: inout [String: Any]?)
}

/// Default implementation of getter / setter.
public extension NodePropertyKey {
  static func getProperty(from bag: [String: Any]?) -> Value? {
    guard let bag = bag else { return nil }
    if let value = bag[key] {
      return (value as! Value)
    } else {
      return nil
    }
  }

  static func setProperty(_ value: Value, in bag: inout [String: Any]?) {
    if bag == nil {
      bag = [key: value]
    } else {
      bag?[key] = value
    }
  }
}

/// A node in the markup language's syntax tree.
public final class Node: CustomStringConvertible {
  public init(type: NodeType, length: Int = 0) {
    self.type = type
    self.length = length
  }

  public static func makeFragment() -> Node {
    return Node(type: .documentFragment, length: 0)
  }

  /// The type of this node.
  public var type: NodeType

  /// If true, this node should be considered a "fragment" (an ordered list of nodes without a root)
  public var isFragment: Bool {
    return type === NodeType.documentFragment
  }

  /// The length of the original text covered by this node (and all children).
  /// We only store the length so nodes can be efficiently reused while editing text, but it does mean you need to
  /// build up context (start position) by walking the parse tree.
  public var length: Int

  /// Children of this node.
  public var children = [Node]()

  public func appendChild(_ child: Node) {
    length += child.length
    if child.isFragment {
      var fragmentNodes = child.children
      if let last = children.last, let first = fragmentNodes.first, last.children.isEmpty, first.children.isEmpty, last.type == first.type {
        last.length += first.length
        fragmentNodes.removeFirst()
      }
      children.append(contentsOf: fragmentNodes)
    } else {
      // Special optimization: Adding a terminal node of the same type of the last terminal node
      // can just be a range update.
      if let lastNode = children.last, lastNode.children.isEmpty, child.children.isEmpty, lastNode.type == child.type {
        lastNode.length += child.length
      } else {
        children.append(child)
      }
    }
  }

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return length == 0
  }

  public var description: String {
    "Node: \(length) \(compactStructure)"
  }

  /// Walks down the tree of nodes to find a specific node.
  public func node(at indexPath: IndexPath) -> Node? {
    if indexPath.isEmpty { return self }
    let nextChild = children.dropFirst(indexPath[0]).first(where: { _ in true })
    assert(nextChild != nil)
    return nextChild?.node(at: indexPath.dropFirst())
  }

  // MARK: - Properties

  /// Lazily-allocated property bag.
  private var propertyBag: [String: Any]?

  /// Type-safe property accessor.
  public subscript<K: NodePropertyKey>(key: K.Type) -> K.Value? {
    get {
      return key.getProperty(from: propertyBag)
    }
    set {
      if let value = newValue {
        key.setProperty(value, in: &propertyBag)
      } else {
        propertyBag?.removeValue(forKey: key.key)
      }
    }
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
    var lines = ""
    writeDebugDescription(to: &lines, pieceTable: pieceTable, location: 0, indentLevel: 0)
    return lines
  }

  /// Recursive helper function for `debugDescription(of:)`
  private func writeDebugDescription<Target: TextOutputStream>(
    to lines: inout Target,
    pieceTable: PieceTable,
    location: Int,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append(type.rawValue)
    result.append(": ")
    if children.isEmpty {
      result.append(pieceTable[NSRange(location: location, length: length)].debugDescription)
    }
    lines.write(result)
    lines.write("\n")
    var childLocation = location
    for child in children {
      child.writeDebugDescription(to: &lines, pieceTable: pieceTable, location: childLocation, indentLevel: indentLevel + 1)
      childLocation += child.length
    }
  }
}
