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

/// Returns the node at the specified position.
public typealias ParsingFunction = (TextBuffer, TextBuffer.Index) throws -> Node?

/// Returns an array of nodes at the the specified position that
public typealias NodeSequenceParser = (TextBuffer, TextBuffer.Index) throws -> [Node]

infix operator =>: MultiplicationPrecedence

public func => (name: NodeType, parser: @escaping NodeSequenceParser) -> ParsingFunction {
  return { buffer, position in
    let children = try parser(buffer, position)
    guard
      let firstChild = children.first,
      let lastChild = children.last
    else {
      return nil
    }
    return Node(
      type: name,
      range: firstChild.range.lowerBound ..< lastChild.range.upperBound,
      children: children
    )
  }
}

/// All of the rules necessary to find markup inside of text.
public struct MarkupLanguage {
  public var name: String
  public var root: ParsingFunction

  public enum Error: Swift.Error {
    /// We didn't get a root node at all
    case parsingFailed
    /// The parsing routine did not parse the entire document.
    case incompleteParsing(TextBuffer.Index)
  }

  public func parse(_ text: String) throws -> Node {
    let buffer = TextBuffer(text)
    guard
      let node = try root(buffer, buffer.startIndex)
    else {
      throw Error.parsingFailed
    }
    if node.range.upperBound != text.endIndex {
      throw Error.incompleteParsing(node.range.upperBound)
    }
    return node
  }

  static func many(_ rule: @escaping ParsingFunction) -> NodeSequenceParser {
    return { buffer, position in
      var children: [Node] = []
      var currentPosition = position
      while !buffer.isEOF(currentPosition), let child = try rule(buffer, currentPosition) {
        children.append(child)
        currentPosition = child.range.upperBound
      }
      return children
    }
  }

  static func choice(of rules: [ParsingFunction]) -> ParsingFunction {
    return { buffer, position in
      for rule in rules {
        if let node = try? rule(buffer, position) {
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
        guard let childNode = try childRule(buffer, currentPosition) else {
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

extension MarkupLanguage {
  public static let miniMarkdown = MarkupLanguage(
    name: "MiniMarkdown",
    root: "document" => many(choice(of: [
      header,
      blankLine,
      paragraph,
    ]))
  )

  static let blankLine = text(matching: { $0 == "\n" }, named: "blank_line")

  static let header = "header" => sequence(of: [
    text(matching: { $0 == "#" }, named: "delimiter"),
    text(matching: { $0.unicodeScalars.first!.properties.isPatternWhitespace }),
    text(upToAndIncluding: "\n", named: "text"),
  ])

  private static let paragraphTermination: CharacterSet = [
    "#",
    "\n",
  ]

  static let paragraph: ParsingFunction = { buffer, position in
    var currentPosition = position
    repeat {
      currentPosition = buffer.index(after: "\n", startingAt: currentPosition)
    } while !paragraphTermination.contains(buffer.unicodeScalar(at: currentPosition), includesNil: true)
    return Node(type: "paragraph", range: position ..< currentPosition, children: [])
  }
}
