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

/// A node in the markup language's syntax tree.
public final class Node {
  public init(type: NodeType, range: Range<TextBuffer.Index>, children: [Node] = []) {
    self.type = type
    self.range = range
    self.children = children
  }

  public init?(textBuffer: TextBuffer, position: TextBuffer.Index) {
    return nil
  }

  /// The type of this node.
  public let type: NodeType

  /// The range from the original `TextBuffer` that this node in the syntax tree covers.
  public let range: Range<TextBuffer.Index>

  /// Children of this node.
  public let children: [Node]

  /// True if this node corresponds to no text in the input buffer.
  public var isEmpty: Bool {
    return range.isEmpty
  }
}

// MARK: - Generic parsing

public extension Node {
  /// Returns the node at the specified position.
  typealias ParsingFunction = (TextBuffer, TextBuffer.Index) -> Node?

  /// Returns an array of nodes at the the specified position that
  typealias NodeSequenceParser = (TextBuffer, TextBuffer.Index) -> [Node]

  static func many(_ rule: @escaping ParsingFunction) -> NodeSequenceParser {
    return { buffer, position in
      var children: [Node] = []
      var currentPosition = position
      while !buffer.isEOF(currentPosition), let child = rule(buffer, currentPosition) {
        children.append(child)
        currentPosition = child.range.upperBound
      }
      return children
    }
  }

  static func choice(of rules: [ParsingFunction]) -> ParsingFunction {
    return { buffer, position in
      for rule in rules {
        if let node = rule(buffer, position) {
          return node
        }
      }
      return nil
    }
  }

  static func sequence(of rules: [ParsingFunction]) -> NodeSequenceParser {
    return { buffer, position in
      var childNodes: [Node] = []
      var currentPosition = position
      for childRule in rules {
        guard let childNode = childRule(buffer, currentPosition) else {
          return []
        }
        childNodes.append(childNode)
        currentPosition = childNode.range.upperBound
      }
      return childNodes
    }
  }

  static func text(
    matching predicate: @escaping (Character) -> Bool,
    named name: NodeType = .anonymous
  ) -> ParsingFunction {
    return { buffer, position in
      var endPosition = position
      while buffer.character(at: endPosition).map(predicate) ?? false {
        endPosition = buffer.index(after: endPosition)!
      }
      guard endPosition > position else {
        return nil
      }
      return Node(type: name, range: position ..< endPosition, children: [])
    }
  }

  static func text(
    upToAndIncluding terminator: Character,
    requiresTerminator: Bool = false,
    named name: NodeType = .anonymous
  ) -> ParsingFunction {
    return { buffer, position in
      var currentPosition = position
      var foundTerminator = false
      while !buffer.isEOF(currentPosition) {
        if buffer.character(at: currentPosition) == terminator {
          foundTerminator = true
          break
        }
        currentPosition = buffer.index(after: currentPosition)!
      }
      if requiresTerminator, !foundTerminator {
        // We never found the terminator
        return nil
      }
      if let nextPosition = buffer.index(after: currentPosition) {
        currentPosition = nextPosition
      }
      return Node(type: name, range: position ..< currentPosition, children: [])
    }
  }
}

public extension Array where Element: Node {
  var encompassingRange: Range<TextBuffer.Index>? {
    guard let firstChild = first, let lastChild = last else {
      return nil
    }
    return firstChild.range.lowerBound ..< lastChild.range.upperBound
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
    let filteredChildren = children.filter { $0.type != .anonymous }
    if filteredChildren.isEmpty {
      buffer.append(type.rawValue)
    } else {
      buffer.append("(")
      buffer.append(type.rawValue)
      buffer.append(" (")
      for (index, child) in filteredChildren.enumerated() {
        if index > 0 {
          buffer.append(" ")
        }
        child.writeCompactStructure(to: &buffer)
      }
      buffer.append("))")
    }
  }

  /// Returns the syntax tree and which parts of `textBuffer` the leaf nodes correspond to.
  public func debugDescription(of textBuffer: TextBuffer) -> String {
    var lines = [String]()
    writeDebugDescription(to: &lines, textBuffer: textBuffer, indentLevel: 0)
    return lines.joined(separator: "\n")
  }

  /// Recursive helper function for `debugDescription(of:)`
  private func writeDebugDescription(
    to lines: inout [String],
    textBuffer: TextBuffer,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append(type.rawValue)
    result.append(": ")
    if children.isEmpty {
      result.append(textBuffer[range].debugDescription)
    }
    lines.append(result)
    for child in children {
      child.writeDebugDescription(to: &lines, textBuffer: textBuffer, indentLevel: indentLevel + 1)
    }
  }
}
