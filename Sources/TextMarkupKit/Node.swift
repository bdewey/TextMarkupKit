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
open class Node {
  public init(id: NodeType, range: Range<TextBuffer.Index>, children: [Node] = []) {
    self.id = id
    self.range = range
    self.children = children
  }

  public let id: NodeType
  public var range: Range<TextBuffer.Index>
  public let children: [Node]

  public var isEmpty: Bool {
    return range.isEmpty
  }

  public var compactStructure: String {
    var results = ""
    writeCompactStructure(to: &results)
    return results
  }

  private func writeCompactStructure(to buffer: inout String) {
    let filteredChildren = children.filter { $0.id != .anonymous }
    if filteredChildren.isEmpty {
      buffer.append(id.rawValue)
    } else {
      buffer.append("(")
      buffer.append(id.rawValue)
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

  public func debugDescription(of textBuffer: TextBuffer) -> String {
    var lines = [String]()
    writeDebugDescription(to: &lines, textBuffer: textBuffer, indentLevel: 0)
    return lines.joined(separator: "\n")
  }

  private func writeDebugDescription(
    to lines: inout [String],
    textBuffer: TextBuffer,
    indentLevel: Int
  ) {
    var result = String(repeating: " ", count: 2 * indentLevel)
    result.append(id.rawValue)
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
