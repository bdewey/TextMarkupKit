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

/// A rule recognizes a specific bit of structure inside of text content.
public protocol ParsingRule {
  /// Computes the result of applying this rule to a specific parser at a specific index.
  func apply(to parser: PackratParser, at index: Int) -> ParsingResult
}

public enum ParsingRules {
  static let dot = DotRule()
}

/// The output of trying to match a rule at an offset into a PieceTable.
public struct ParsingResult {
  /// Did the rule succeed?
  public var succeeded: Bool

  /// How much of the input is consumed by the rule if it succeeded
  public var length: Int

  /// How far into the input sequence did we look to determine if we succeeded?
  public var examinedLength: Int

  /// If we succeeded, what are the parse results? Note that for efficiency some rules may consume input (length > 1) but not actually generate syntax tree nodes.
  public var nodes: [Node]

  /// Represents the "dot" in PEG grammars -- matches a single character. Does not create a node; this result will need to
  /// get absorbed into something else.
  public static let dot = ParsingResult(succeeded: true, length: 1, examinedLength: 1, nodes: [])

  /// Static result representing failure after looking at one character.
  public static let fail = ParsingResult(succeeded: false, length: 0, examinedLength: 1, nodes: [])
}

// MARK: - Deriving rules

public extension ParsingRule {
  /// Returns a rule that matches zero or more occurrences of the receiver.
  func zeroOrMore() -> ParsingRule {
    return ZeroOrMoreMatcher(rule: self)
  }

  /// Returns a rule that "absorbs" the contents of the receiver into a syntax tree node of type `nodeType`
  /// - note: "Absorbing" means that all of the nodes in the receiver's `ParsingResult` are discarded, but the resulting span of the
  /// buffer will be covered by this rule's single node.
  func absorb(into nodeType: NodeType) -> ParsingRule {
    return AbsorbingMatcher(nodeType: nodeType, rule: self)
  }
}

// MARK: - Building block rules

/// A rule that always succeeds after looking at one character.
/// - note: In PEG grammars, matching a single character is represented by a ".", thus the name.
struct DotRule: ParsingRule {
  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    if index < parser.buffer.endIndex {
      return .dot
    } else {
      return .fail
    }
  }
}

/// Matches single characters that belong to a character set. The result is not put into a syntax tree node and should get absorbed
/// by another rule.
struct CharacterSetMatcher: ParsingRule {
  let characters: CharacterSet

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    guard let char = parser.buffer.utf16(at: index), characters.contains(char) else {
      return .fail
    }
    return .dot
  }
}

/// Looks up a rule in the parser's grammar by identifier. Sees if the parser has already memoized the result of parsing this rule
/// at this identifier; if so, returns it. Otherwise, applies the rule, memoizes the result in the parser, and returns it.
struct RuleMatcher<Grammar>: ParsingRule {
  let ruleIdentifier: KeyPath<Grammar, ParsingRule>

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    guard let grammar = parser.grammar as? Grammar else {
      preconditionFailure("Parser grammar was not of the expected type")
    }
    if let memoizedResult = parser.memoizedResult(rule: ruleIdentifier, index: index) {
      return memoizedResult
    }
    let rule = grammar[keyPath: ruleIdentifier]
    let result = rule.apply(to: parser, at: index)
    parser.memoizeResult(result, rule: ruleIdentifier, index: index)
    return result
  }
}

/// Matches zero or more occurrences of a rule. The resulting nodes are concatenated together in the result.
struct ZeroOrMoreMatcher: ParsingRule {
  let rule: ParsingRule

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true, length: 0, examinedLength: 0, nodes: [])
    var currentIndex = index
    repeat {
      let innerResult = rule.apply(to: parser, at: currentIndex)
      guard innerResult.succeeded else { break }
      result.length += innerResult.length
      result.examinedLength += innerResult.examinedLength
      result.nodes.append(contentsOf: innerResult.nodes)
      currentIndex += innerResult.length
    } while true
    return result
  }
}

/// "Absorbs" the range consumed by `rule` into a syntax tree node of type `nodeType`. Any syntax tree nodes produced
/// by `rule` will be discarded.
struct AbsorbingMatcher: ParsingRule {
  let nodeType: NodeType
  let rule: ParsingRule

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    if !result.succeeded { return result }
    let node = Node(type: nodeType, range: index ..< index + result.length)
    result.nodes = [node]
    return result
  }
}
