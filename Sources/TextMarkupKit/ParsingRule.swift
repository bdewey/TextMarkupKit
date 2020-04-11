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
  static let whitespace = CharacterSetMatcher(characters: .whitespaces)
  static func sequence(_ rules: ParsingRule...) -> ParsingRule {
    return SequenceRule(rules: rules)
  }

  static func choice(_ rules: ParsingRule...) -> ParsingRule {
    return ChoiceRule(rules: rules)
  }
}

/// The output of trying to match a rule at an offset into a PieceTable.
public struct ParsingResult {
  /// Did the rule succeed?
  public var succeeded: Bool

  /// How much of the input is consumed by the rule if it succeeded
  public var length: Int = 0

  /// How far into the input sequence did we look to determine if we succeeded?
  public var examinedLength: Int = 0

  /// If we succeeded, what are the parse results? Note that for efficiency some rules may consume input (length > 1) but not actually generate syntax tree nodes.
  public var nodes: [Node] = []

  /// Marks this result as a failure; useful for truncating in-process results. Notes it leaves `examinedLength` unchanged
  /// so incremental parsing can work.
  @discardableResult
  public mutating func failed() -> ParsingResult {
    succeeded = false
    length = 0
    nodes.removeAll()
    return self
  }

  public mutating func concat(_ result: ParsingResult) {
    succeeded = succeeded && result.succeeded
    length += result.length
    examinedLength += result.examinedLength
    nodes.append(contentsOf: result.nodes)
  }

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

  func wrapping(in nodeType: NodeType) -> ParsingRule {
    return WrappingRule(nodeType: nodeType, rule: self)
  }

  /// Returns a rule that "absorbs" the contents of the receiver into a syntax tree node of type `nodeType`
  /// - note: "Absorbing" means that all of the nodes in the receiver's `ParsingResult` are discarded, but the resulting span of the
  /// buffer will be covered by this rule's single node.
  func absorb(into nodeType: NodeType) -> ParsingRule {
    return AbsorbingMatcher(nodeType: nodeType, rule: self)
  }

  /// Returns a rule that matches if the receiver repeats within `range` times, and fails otherwise.
  func repeating(_ range: Range<Int>) -> ParsingRule {
    return RangeRule(rule: self, range: range)
  }

  func repeating(_ partialRange: PartialRangeFrom<Int>) -> ParsingRule {
    return UnboundedRangeRule(rule: self, range: partialRange)
  }

  func assert() -> ParsingRule {
    return AssertionRule(rule: self)
  }

  /// Returns an *assertion* that succeeds if the receiver fails and vice versa.
  func assertInverse() -> ParsingRule {
    return NotAssertionRule(rule: self)
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
      Swift.assert(innerResult.length > 0, "About to enter an infinite loop")
      result.length += innerResult.length
      result.examinedLength += innerResult.examinedLength
      result.nodes.append(contentsOf: innerResult.nodes)
      currentIndex += innerResult.length
    } while true
    return result
  }
}

/// Counts how many times we can successively match a rule. Succeeds and returns the concatenated result if the number of times
/// the rule matches falls within an allowed range, fails otherwise.
struct RangeRule: ParsingRule {
  let rule: ParsingRule
  let range: Range<Int>

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true, length: 0, examinedLength: 0, nodes: [])
    var currentIndex = index
    var repetitionCount = 0
    repeat {
      let innerResult = rule.apply(to: parser, at: currentIndex)
      guard innerResult.succeeded else { break }
      repetitionCount += 1
      result.length += innerResult.length
      result.examinedLength += innerResult.examinedLength
      if repetitionCount >= range.upperBound {
        return result.failed()
      }
      result.nodes.append(contentsOf: innerResult.nodes)
      currentIndex += innerResult.length
    } while true
    if repetitionCount < range.lowerBound {
      return result.failed()
    }
    return result
  }
}

/// Counts how many times we can successively match a rule. Succeeds and returns the concatenated result if the number of times
/// the rule matches falls within an allowed range, fails otherwise.
struct UnboundedRangeRule: ParsingRule {
  let rule: ParsingRule
  let range: PartialRangeFrom<Int>

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true, length: 0, examinedLength: 0, nodes: [])
    var currentIndex = index
    var repetitionCount = 0
    repeat {
      let innerResult = rule.apply(to: parser, at: currentIndex)
      guard innerResult.succeeded else { break }
      repetitionCount += 1
      result.concat(innerResult)
      currentIndex += innerResult.length
    } while true
    if repetitionCount < range.lowerBound {
      return result.failed()
    }
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

/// Succeeds if `rule` succeeds, and all of the children of `rule` will be made the children of a new node of type `nodeType`.
struct WrappingRule: ParsingRule {
  let nodeType: NodeType
  let rule: ParsingRule

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    if !result.succeeded { return result }
    let node = Node(type: nodeType, range: index ..< index + result.length, children: result.nodes)
    result.nodes = [node]
    return result
  }
}

/// A rule that succeeds only if each child rule succeeds in sequence.
struct SequenceRule: ParsingRule {
  let rules: [ParsingRule]

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true)
    var currentIndex = index
    for rule in rules {
      result.concat(rule.apply(to: parser, at: currentIndex))
      if !result.succeeded { return result.failed() }
      currentIndex += result.length
    }
    return result
  }
}

/// An *assertion* that succeeds if `rule` succeeds but consumes no input and produces no syntax tree nodes.
struct AssertionRule: ParsingRule {
  let rule: ParsingRule

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    result.length = 0
    result.nodes.removeAll()
    return result
  }
}

/// An *assertion* that succeeds if `rule` fails and vice versa, and never consumes input.
struct NotAssertionRule: ParsingRule {
  let rule: ParsingRule

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    result.length = 0 // never consume input
    result.succeeded.toggle()
    return result
  }
}

/// Returns the result of the first successful match, or .fail otherwise.
struct ChoiceRule: ParsingRule {
  let rules: [ParsingRule]

  func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var examinedLength = 0
    for rule in rules {
      var result = rule.apply(to: parser, at: index)
      examinedLength = max(examinedLength, result.examinedLength)
      if result.succeeded {
        result.examinedLength = examinedLength
        return result
      }
    }
    return ParsingResult(succeeded: false, length: 0, examinedLength: examinedLength, nodes: [])
  }
}
