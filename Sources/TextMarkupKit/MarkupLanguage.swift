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
public typealias ParsingFunction = (StringPosition) throws -> MarkupNode?

/// Returns an array of nodes at the the specified position that
public typealias NodeSequenceParser = (StringPosition) throws -> [MarkupNode]

infix operator =>: MultiplicationPrecedence

public func => (name: MarkupNode.Identifier, parser: @escaping NodeSequenceParser) -> ParsingFunction {
  return { position in
    let children = try parser(position)
    guard
      let firstChild = children.first,
      let lastChild = children.last
    else {
        return nil
    }
    return MarkupNode(
      name: name,
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
    case incompleteParsing(StringPosition)
  }

  public func parse(_ text: String) throws -> MarkupNode {
    guard
      let node = try root(StringPosition(string: text, position: text.startIndex))
    else {
        throw Error.parsingFailed
    }
    if node.range.upperBound.position != text.endIndex {
      throw Error.incompleteParsing(node.range.upperBound)
    }
    return node
  }

  static func many(_ rule: @escaping ParsingFunction) -> NodeSequenceParser {
    return { position in
      var children: [MarkupNode] = []
      var currentPosition = position
      while !currentPosition.isEOF, let child = try rule(currentPosition) {
        children.append(child)
        currentPosition = child.range.upperBound
      }
      return children
    }
  }

  static func choice(of rules: [ParsingFunction]) -> ParsingFunction {
    return { position in
      for rule in rules {
        if let node = try? rule(position) {
          return node
        }
      }
      return nil
    }
  }

  static func sequence(of rules: [ParsingFunction]) -> NodeSequenceParser {
    return { position in
      var childNodes: [MarkupNode] = []
      var currentPosition = position
      for childRule in rules {
        guard let childNode = try childRule(currentPosition) else {
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
    named name: MarkupNode.Identifier = .anonymous
  ) -> ParsingFunction {
    return { position in
      var endPosition = position
      while endPosition.character.map(predicate) ?? false {
        try endPosition.advance()
      }
      guard endPosition > position else {
        return nil
      }
      return MarkupNode(name: name, range: position ..< endPosition, children: [])
    }
  }

  static func text(
    upToAndIncluding terminator: Character,
    requiresTerminator: Bool = false,
    named name: MarkupNode.Identifier = .anonymous
  ) -> ParsingFunction {
    return { position in
      var currentPosition = position
      var foundTerminator = false
      while !currentPosition.isEOF {
        if currentPosition.character == terminator {
          foundTerminator = true
          break
        }
        try currentPosition.advance()
      }
      if requiresTerminator, !foundTerminator {
        // We never found the terminator
        return nil
      }
      try? currentPosition.advance()
      return MarkupNode(name: name, range: position ..< currentPosition, children: [])
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

  static let paragraph: ParsingFunction = { position in
    var currentPosition = position
    repeat {
      currentPosition.advance(past: "\n")
    } while !paragraphTermination.contains(currentPosition.unicodeScalar, includesNil: true)
    return MarkupNode(name: "paragraph", range: position ..< currentPosition, children: [])
  }
}

private extension CharacterSet {
  func contains(_ scalar: UnicodeScalar?, includesNil: Bool) -> Bool {
    scalar.map(contains) ?? includesNil
  }
}
