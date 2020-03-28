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

/// All of the rules necessary to find markup inside of text.
public struct MarkupLanguage {
  public var name: String
  public var root: MarkupRule

  public enum Error: Swift.Error {
    /// We didn't get a root node at all
    case parsingFailed
    /// The parsing routine did not parse the entire document.
    case incompleteParsing(StringPosition)
  }

  public func parse(_ text: String) throws -> MarkupNode {
    guard
      let node = try root.nodeAtPosition(StringPosition(string: text, position: text.startIndex))
    else {
        throw Error.parsingFailed
    }
    if node.range.upperBound.position != text.endIndex {
      throw Error.incompleteParsing(node.range.upperBound)
    }
    return node
  }

  static func many(name: MarkupNode.Identifier, rule: MarkupRule) -> RepeatRule {
    RepeatRule(name: name, subrule: rule)
  }

  static func choice(of rules: [MarkupRule]) -> ChoiceRule {
    ChoiceRule(rules: rules)
  }
}

extension MarkupLanguage {
  public static let miniMarkdown = MarkupLanguage(
    name: "MiniMarkdown",
    root: many(name: "document", rule: choice(of: [
      headerRule,
      lineRule,
    ]))
  )

  static let headerRule = SequenceRule(name: "header", children: [
    TextMatchingRule(name: "delimiter", predicate: { $0 == "#" }),
    TextMatchingRule(name: .anonymous, predicate: { $0.unicodeScalars.first!.properties.isPatternWhitespace }),
    TerminatorRule(name: "text", predicate: { $0.isEOF || (try! $0.character()) == "\n" }),
  ])

  static let lineRule = TerminatorRule(name: "line", predicate: { $0.isEOF || (try! $0.character()) == "\n" })
}
