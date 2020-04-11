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
open class ParsingRule {
  public init() {}

  public func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    // NOTHING
  }

  /// Computes the result of applying this rule to a specific parser at a specific index.
  public func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    preconditionFailure("Subclasses should override")
  }

  static let dot = DotRule()
  static let whitespace = Characters(.whitespaces)
}

open class ParsingRuleWrapper: ParsingRule {
  public var rule: ParsingRule

  public init(_ rule: ParsingRule) {
    self.rule = rule
  }

  public override func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    rule = wrapFunction(rule)
  }
}

open class ParsingRuleSequenceWrapper: ParsingRule {
  public var rules: [ParsingRule]

  public init(_ rules: ParsingRule...) {
    self.rules = rules
  }

  public override func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    rules = rules.map(wrapFunction)
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
  func wrapping(in nodeType: NodeType) -> ParsingRule {
    return WrappingRule(rule: self, nodeType: nodeType)
  }

  /// Returns a rule that "absorbs" the contents of the receiver into a syntax tree node of type `nodeType`
  /// - note: "Absorbing" means that all of the nodes in the receiver's `ParsingResult` are discarded, but the resulting span of the
  /// buffer will be covered by this rule's single node.
  func absorb(into nodeType: NodeType) -> ParsingRule {
    return AbsorbingMatcher(rule: self, nodeType: nodeType)
  }

  /// Returns a rule that matches if the receiver repeats within `range` times, and fails otherwise.
  func repeating(_ range: Range<Int>) -> ParsingRule {
    return RangeRule(rule: self, range: range)
  }

  func repeating(_ range: ClosedRange<Int>) -> ParsingRule {
    return RangeRule(rule: self, range: range.lowerBound ..< range.upperBound + 1)
  }

  func repeating(_ partialRange: PartialRangeFrom<Int>) -> ParsingRule {
    return RangeRule(rule: self, range: partialRange.lowerBound ..< Int.max)
  }

  func assert() -> ParsingRule {
    return AssertionRule(self)
  }

  /// Returns an *assertion* that succeeds if the receiver fails and vice versa.
  func assertInverse() -> ParsingRule {
    return NotAssertionRule(self)
  }

  func trace() -> ParsingRule {
    return TraceRule(self, indentLevel: 0)
  }

  func memoize() -> ParsingRule {
    return MemoizingRule(self)
  }
}

// MARK: - Building block rules

/// A rule that always succeeds after looking at one character.
/// - note: In PEG grammars, matching a single character is represented by a ".", thus the name.
final class DotRule: ParsingRule {
  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    if index < parser.buffer.endIndex {
      return .dot
    } else {
      return .fail
    }
  }
}

/// Matches single characters that belong to a character set. The result is not put into a syntax tree node and should get absorbed
/// by another rule.
final class Characters: ParsingRule {
  init(_ characters: CharacterSet) {
    self.characters = characters
  }

  let characters: CharacterSet

  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    guard let char = parser.buffer.utf16(at: index), characters.contains(char) else {
      return .fail
    }
    return .dot
  }
}

/// Looks up a rule in the parser's grammar by identifier. Sees if the parser has already memoized the result of parsing this rule
/// at this identifier; if so, returns it. Otherwise, applies the rule, memoizes the result in the parser, and returns it.
final class MemoizingRule: ParsingRuleWrapper {
  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    if let memoizedResult = parser.memoizedResult(rule: ObjectIdentifier(self), index: index) {
      return memoizedResult
    }
    let result = rule.apply(to: parser, at: index)
    parser.memoizeResult(result, rule: ObjectIdentifier(self), index: index)
    return result
  }
}

/// Counts how many times we can successively match a rule. Succeeds and returns the concatenated result if the number of times
/// the rule matches falls within an allowed range, fails otherwise.
final class RangeRule: ParsingRuleWrapper {
  init(rule: ParsingRule, range: Range<Int>) {
    self.range = range
    super.init(rule)
  }

  let range: Range<Int>

  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true, length: 0, examinedLength: 0, nodes: [])
    var currentIndex = index
    var repetitionCount = 0
    repeat {
      let innerResult = rule.apply(to: parser, at: currentIndex)
      guard innerResult.succeeded else { break }
      Swift.assert(innerResult.length > 0, "About to enter an infinite loop")
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

/// "Absorbs" the range consumed by `rule` into a syntax tree node of type `nodeType`. Any syntax tree nodes produced
/// by `rule` will be discarded.
final class AbsorbingMatcher: ParsingRuleWrapper {
  let nodeType: NodeType

  init(rule: ParsingRule, nodeType: NodeType) {
    self.nodeType = nodeType
    super.init(rule)
  }

  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    if !result.succeeded { return result }
    let node = Node(type: nodeType, range: index ..< index + result.length)
    result.nodes = [node]
    return result
  }
}

/// Succeeds if `rule` succeeds, and all of the children of `rule` will be made the children of a new node of type `nodeType`.
final class WrappingRule: ParsingRuleWrapper {
  let nodeType: NodeType

  init(rule: ParsingRule, nodeType: NodeType) {
    self.nodeType = nodeType
    super.init(rule)
  }

  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    if !result.succeeded { return result }
    let node = Node(type: nodeType, range: index ..< index + result.length, children: result.nodes)
    result.nodes = [node]
    return result
  }
}

/// A rule that succeeds only if each child rule succeeds in sequence.
public final class InOrder: ParsingRuleSequenceWrapper {
  public override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = ParsingResult(succeeded: true)
    var currentIndex = index
    for rule in rules {
      let innerResult = rule.apply(to: parser, at: currentIndex)
      if !innerResult.succeeded { return result.failed() }
      result.concat(innerResult)
      currentIndex += innerResult.length
    }
    return result
  }
}

/// An *assertion* that succeeds if `rule` succeeds but consumes no input and produces no syntax tree nodes.
final class AssertionRule: ParsingRuleWrapper {
  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    result.length = 0
    result.nodes.removeAll()
    return result
  }
}

/// An *assertion* that succeeds if `rule` fails and vice versa, and never consumes input.
final class NotAssertionRule: ParsingRuleWrapper {
  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    var result = rule.apply(to: parser, at: index)
    result.length = 0 // never consume input
    result.succeeded.toggle()
    return result
  }
}

/// Returns the result of the first successful match, or .fail otherwise.
public final class Choice: ParsingRuleSequenceWrapper {
  public override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
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

final class TraceRule: ParsingRuleWrapper {
  init(_ rule: ParsingRule, indentLevel: Int) {
    self.indentLevel = indentLevel
    super.init(rule)
    rule.wrapInnerRules { (innerRule) -> ParsingRule in
      return TraceRule(innerRule, indentLevel: indentLevel + 1)
    }
  }

  let indentLevel: Int

  override func apply(to parser: PackratParser, at index: Int) -> ParsingResult {
    let space = String(repeating: "| ", count: indentLevel)
    let currentContents = parser.buffer.utf16(at: index).map { char -> String in
      guard let scalar = Unicode.Scalar(char) else {
        assertionFailure()
        return "invalid"
      }
      return scalar.debugDescription
    }
    print("\(space)+ \(rule)@\(index): \(currentContents ?? "nil")")
    let result = rule.apply(to: parser, at: index)
    print("\(space)= \(rule)@\(index): \(result)")
    return result
  }
}
