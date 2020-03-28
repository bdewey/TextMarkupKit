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

open class MarkupNode {
  public final class Identifier: RawRepresentable, ExpressibleByStringLiteral, Hashable {
    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
      self.rawValue = value
    }

    public let rawValue: String

    public static let anonymous: Identifier = ""
  }

  public init(name: Identifier, range: Range<StringPosition>, children: [MarkupNode]) {
    self.name = name
    self.range = range
    self.children = children
  }

  public let name: Identifier
  public let range: Range<StringPosition>
  public let children: [MarkupNode]

  public var newlineStructure: String {
    var results: [String] = []
    dumpNewlineStructure(indentLevel: 0, results: &results)
    return results.joined(separator: "\n")
  }

  private func dumpNewlineStructure(indentLevel: Int, results: inout [String]) {
    results.append(String(repeating: " ", count: indentLevel * 2) + name.rawValue)
    for child in children where child.name != .anonymous {
      child.dumpNewlineStructure(indentLevel: indentLevel + 1, results: &results)
    }
  }

  public var compactStructure: String {
    var results = "("
    writeCompactStructure(to: &results)
    results += ")"
    return results
  }

  private func writeCompactStructure(to buffer: inout String) {
    buffer.append(name.rawValue)
    let filteredChildren = children.filter { $0.name != .anonymous }
    if !filteredChildren.isEmpty {
      buffer.append(" (")
      for (index, child) in filteredChildren.enumerated() {
        if index > 0 {
          buffer.append(" ")
        }
        child.writeCompactStructure(to: &buffer)
      }
      buffer.append(")")
    }
  }
}
