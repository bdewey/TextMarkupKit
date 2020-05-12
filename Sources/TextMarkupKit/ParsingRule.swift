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
open class ParsingRule: CustomStringConvertible {
  public init() {}

  /// A simple description of this rule.
  public var description: String {
    let pointer = String(format: "%p", unsafeBitCast(self, to: Int.self))
    return "<\(type(of: self)) \(pointer)>"
  }

  /// Holds how many times a rule was invoked and how many times the rule succeeded.
  public struct PerformanceCounters {
    public private(set) var total: Int = 0
    public private(set) var successes: Int = 0

    /// The success rate of this rule.
    public var successRate: Double {
      guard total > 0 else { return 0 }
      return Double(successes) / Double(total)
    }

    /// Updates the performance counters given the result of applying this rule.
    /// - returns: The result for syntactic convenience.
    @discardableResult
    mutating func recordResult(_ parsingResult: ParsingResult) -> ParsingResult {
      total += 1
      if parsingResult.succeeded { successes += 1 }
      return parsingResult
    }
  }

  /// Performance counters for this rule.
  public internal(set) var performanceCounters = PerformanceCounters()

  /// An entry is a mapping of this rule's description to its performance counters.
  public typealias PerformanceCounterEntry = (key: String, value: PerformanceCounters)

  /// Writes the rule's performance counters into an array.
  func gatherPerformanceCounters(into array: inout [PerformanceCounterEntry]) {
    array.append((key: String(describing: self), value: performanceCounters))
  }

  /// Returns all of the performance counters for this rule and any inner rules.
  public func allPerformanceCounters() -> [PerformanceCounterEntry] {
    var results = [PerformanceCounterEntry]()
    gatherPerformanceCounters(into: &results)
    return results
  }

  public func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    // NOTHING
  }

  /// Computes the result of applying this rule to specific text at a specific index.
  public func parsingResult(
    from buffer: SafeUnicodeBuffer,
    at index: Int,
    memoizationTable: MemoizationTable
  ) -> ParsingResult {
    preconditionFailure("Subclasses should override")
  }

  /// If non-nil, a CharacterSet noting characters that are valid openings for this rule.
  public var possibleOpeningCharacters: CharacterSet? {
    return nil
  }
}

open class ParsingRuleWrapper: ParsingRule {
  public var rule: ParsingRule

  public init(_ rule: ParsingRule) {
    self.rule = rule
  }

  public override func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    rule = wrapFunction(rule)
  }

  override func gatherPerformanceCounters(into array: inout [ParsingRule.PerformanceCounterEntry]) {
    super.gatherPerformanceCounters(into: &array)
    rule.gatherPerformanceCounters(into: &array)
  }

  public override var possibleOpeningCharacters: CharacterSet? {
    return rule.possibleOpeningCharacters
  }
}

open class ParsingRuleSequenceWrapper: ParsingRule {
  public var rules: [ParsingRule]

  public init(_ rules: [ParsingRule]) {
    self.rules = rules
  }

  public convenience init(_ rules: ParsingRule...) {
    self.init(rules)
  }

  public override func wrapInnerRules(_ wrapFunction: (ParsingRule) -> ParsingRule) {
    rules = rules.map(wrapFunction)
  }

  override func gatherPerformanceCounters(into array: inout [ParsingRule.PerformanceCounterEntry]) {
    super.gatherPerformanceCounters(into: &array)
    for rule in rules {
      rule.gatherPerformanceCounters(into: &array)
    }
  }

  public override var possibleOpeningCharacters: CharacterSet? {
    assertionFailure("Subclasses should override")
    return nil
  }
}

/// The output of trying to match a rule at an offset into a PieceTable.
public struct ParsingResult {
  public init(succeeded: Bool, length: Int = 0, examinedLength: Int = 0, node: Node? = nil) {
    assert(node == nil || (length == node!.length))
    self.succeeded = succeeded
    self.length = length
    self.examinedLength = examinedLength
    self.node = node
  }

  /// Did the rule succeed?
  public var succeeded: Bool

  /// How much of the input is consumed by the rule if it succeeded
  public private(set) var length: Int

  /// Mutate this result to denote that it consumes no input.
  public mutating func setZeroLength() {
    length = 0
    node = nil
  }

  /// How far into the input sequence did we look to determine if we succeeded?
  public var examinedLength: Int {
    didSet {
      assert(examinedLength >= length)
    }
  }

  /// If we succeeded, what are the parse results? Note that for efficiency some rules may consume input (length > 1) but not actually generate syntax tree nodes.
  public private(set) var node: Node?

  /// Turns the spanned by an "anonymous" result into a typed node.
  fileprivate mutating func makeNode(type: NodeType) {
    assert(node == nil)
    node = Node(type: type, length: length)
  }

  /// Marks this result as a failure; useful for truncating in-process results. Notes it leaves `examinedLength` unchanged
  /// so incremental parsing can work.
  @discardableResult
  public mutating func failed() -> ParsingResult {
    succeeded = false
    length = 0
    node = nil
    return self
  }

  /// Used to accumulate child results into a parent result.
  public mutating func appendChild(_ result: ParsingResult) {
    assert(result.node == nil || result.node!.length == result.length)
    succeeded = succeeded && result.succeeded
    examinedLength += result.examinedLength
    guard succeeded else {
      length = 0
      node = nil
      return
    }
    if result.length == 0 { return }
    length += result.length
    if node?.type == .blankLine {
      print("Extended blank line length to \(length)")
    }
    guard let resultNode = result.node else {
      return
    }
    // Optimization: if resultNode is fragment an we haven't allocated one, steal it.
    if resultNode.isFragment, node == nil {
      node = resultNode
      assert(node == nil || node?.length == length)
    } else {
      let fragment = makeFragmentIfNeeded()
      fragment.appendChild(resultNode)
    }
    assert(node == nil || node?.length == length)
  }

  private mutating func makeFragmentIfNeeded() -> Node {
    if let existingNode = node {
      return existingNode
    }
    let node = Node(type: .documentFragment, length: 0)
    self.node = node
    return node
  }

  /// Represents the "dot" in PEG grammars -- matches a single character. Does not create a node; this result will need to
  /// get absorbed into something else.
  public static let dot = ParsingResult(succeeded: true, length: 1, examinedLength: 1, node: nil)

  /// Static result representing failure after looking at one character.
  public static let fail = ParsingResult(succeeded: false, length: 0, examinedLength: 1, node: nil)
}

// MARK: - Deriving rules

public extension ParsingRule {
  func wrapping(in nodeType: NodeType) -> ParsingRule {
    return WrappingRule(rule: self, nodeType: nodeType)
  }

  /// Returns a rule that "absorbs" the contents of the receiver into a syntax tree node of type `nodeType`
  /// - note: "Absorbing" means that all of the nodes in the receiver's `ParsingResult` are discarded, but the resulting span of the
  /// buffer will be covered by this rule's single node.
  func `as`(_ nodeType: NodeType) -> ParsingRule {
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
    return TraceRule(self)
  }

  func memoize() -> ParsingRule {
    return MemoizingRule(self)
  }

  func zeroOrOne() -> ParsingRule {
    return ZeroOrOneRule(self)
  }

  func property<K: NodePropertyKey>(key: K.Type, value: K.Value) -> ParsingRule {
    return PropertyRule(key: key, value: value, rule: self)
  }
}

// MARK: - Building block rules

/// A rule that always succeeds after looking at one character.
/// - note: In PEG grammars, matching a single character is represented by a ".", thus the name.
final class DotRule: ParsingRule {
  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    if index < buffer.count {
      return performanceCounters.recordResult(.dot)
    } else {
      return performanceCounters.recordResult(.fail)
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

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    guard let char = buffer.utf16(at: index), characters.contains(char) else {
      return performanceCounters.recordResult(.fail)
    }
    return performanceCounters.recordResult(.dot)
  }

  override var description: String {
    "\(super.description) \(characters)"
  }

  override var possibleOpeningCharacters: CharacterSet {
    return characters
  }
}

public final class Literal: ParsingRule {
  init(_ string: String) {
    self.chars = Array(string.utf16)
  }

  let chars: [unichar]

  public override var description: String {
    let str = String(utf16CodeUnits: chars, count: chars.count)
    return "\(super.description) \(str)"
  }

  public override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var length = 0
    while length < chars.count, let char = buffer.utf16(at: index + length), char == chars[length] {
      length += 1
    }
    if length == chars.count {
      return performanceCounters.recordResult(ParsingResult(succeeded: true, length: length, examinedLength: length))
    } else {
      return performanceCounters.recordResult(ParsingResult(succeeded: false, length: 0, examinedLength: length + 1))
    }
  }

  public override var possibleOpeningCharacters: CharacterSet {
    return [Unicode.Scalar(chars[0])!]
  }
}

/// Looks up a rule in the parser's grammar by identifier. Sees if the parser has already memoized the result of parsing this rule
/// at this identifier; if so, returns it. Otherwise, applies the rule, memoizes the result in the parser, and returns it.
final class MemoizingRule: ParsingRuleWrapper {
  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    if let memoizedResult = memoizationTable.memoizedResult(rule: ObjectIdentifier(self), index: index) {
      return performanceCounters.recordResult(memoizedResult)
    }
    let result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    memoizationTable.memoizeResult(result, rule: ObjectIdentifier(self), index: index)
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "MEMOIZE \(rule.description)"
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

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = ParsingResult(succeeded: true)
    var currentIndex = index
    var repetitionCount = 0
    var examinedThroughIndex = index
    repeat {
      let innerResult = rule.parsingResult(from: buffer, at: currentIndex, memoizationTable: memoizationTable)
      examinedThroughIndex = max(examinedThroughIndex, currentIndex + innerResult.examinedLength)
      guard innerResult.succeeded, innerResult.length > 0 else {
        result.examinedLength = examinedThroughIndex - index
        break
      }
      repetitionCount += 1
      if repetitionCount >= range.upperBound {
        result.examinedLength = examinedThroughIndex - index
        return performanceCounters.recordResult(result.failed())
      }
      result.appendChild(innerResult)
      currentIndex += innerResult.length
    } while true
    result.examinedLength = examinedThroughIndex - index
    if repetitionCount < range.lowerBound {
      return performanceCounters.recordResult(result.failed())
    }
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "RANGE \(range) \(rule)"
  }
}

/// Matches an inner rule 0 or 1 times.
final class ZeroOrOneRule: ParsingRuleWrapper {
  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    if result.succeeded {
      return performanceCounters.recordResult(result)
    }
    result.succeeded = true
    result.setZeroLength()
    return performanceCounters.recordResult(result)
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

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    if !result.succeeded || result.length == 0 { return result }
    if let existingNode = result.node, existingNode.isFragment {
      existingNode.type = nodeType
    } else {
      result.makeNode(type: nodeType)
    }
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "\(super.description) \(nodeType.rawValue)"
  }
}

/// Succeeds if `rule` succeeds, and all of the children of `rule` will be made the children of a new node of type `nodeType`.
final class WrappingRule: ParsingRuleWrapper {
  let nodeType: NodeType

  init(rule: ParsingRule, nodeType: NodeType) {
    self.nodeType = nodeType
    super.init(rule)
  }

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    if !result.succeeded || result.length == 0 { return result }
    if let node = result.node {
      Swift.assert(node.isFragment)
      node.type = nodeType
    } else {
      result.makeNode(type: nodeType)
    }
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "\(super.description) \(nodeType.rawValue)"
  }
}

/// A rule that succeeds only if each child rule succeeds in sequence.
public final class InOrder: ParsingRuleSequenceWrapper {
  public override init(_ rules: [ParsingRule]) {
    self.memoizedPossibleCharacters = Self.possibleOpeningCharacters(for: rules)
    super.init(rules)
  }

  private let memoizedPossibleCharacters: CharacterSet?

  public override var possibleOpeningCharacters: CharacterSet? { memoizedPossibleCharacters }

  public override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = ParsingResult(succeeded: true)
    var currentIndex = index
    var maxExaminedIndex = index
    for rule in rules {
      let innerResult = rule.parsingResult(from: buffer, at: currentIndex, memoizationTable: memoizationTable)
      maxExaminedIndex = max(maxExaminedIndex, currentIndex + innerResult.examinedLength)
      result.appendChild(innerResult)
      if !innerResult.succeeded {
        result.examinedLength = maxExaminedIndex - index
        return performanceCounters.recordResult(result.failed())
      }
      currentIndex += innerResult.length
    }
    result.examinedLength = maxExaminedIndex - index
    return performanceCounters.recordResult(result)
  }

  public override var description: String {
    "IN ORDER: \(rules.map(String.init(describing:)).joined(separator: ", "))"
  }

  private static func possibleOpeningCharacters(for rules: [ParsingRule]) -> CharacterSet? {
    var assertions: CharacterSet?
    var possibilities: CharacterSet? = CharacterSet()
    var done = false
    for rule in rules where !done {
      var rule = rule
      if let traceRule = rule as? TraceRule {
        rule = traceRule.rule
      }
      switch rule {
      case let rule as RangeRule:
        possibilities.formUnion(rule.possibleOpeningCharacters)
        if rule.range.lowerBound > 0 {
          done = true
        }
      case let rule as ZeroOrOneRule:
        possibilities.formUnion(rule.possibleOpeningCharacters)
      case let rule as AssertionRule:
        assertions.formIntersection(rule.possibleOpeningCharacters)
      case let rule as NotAssertionRule:
        assertions.formIntersection(rule.possibleOpeningCharacters)
      default:
        possibilities.formUnion(rule.possibleOpeningCharacters)
        done = true
      }
    }
    possibilities.formIntersection(assertions)
    return possibilities
  }
}

/// Apply my character set rules where "nil" means "match anything"
private extension Optional where Wrapped == CharacterSet {
  mutating func formUnion(_ other: CharacterSet?) {
    switch (self, other) {
    case (.none, _):
      // nil union anything is nil
      break
    case (_, .none):
      self = nil
    case (.some(let characters), .some(let otherCharacters)):
      self = characters.union(otherCharacters)
    }
  }

  mutating func formIntersection(_ other: CharacterSet?) {
    switch (self, other) {
    case (.none, _):
      self = other
    case (_, .none):
      break
    case (.some(let characters), .some(let otherCharacters)):
      self = characters.intersection(otherCharacters)
    }
  }

  func subtracting(_ other: CharacterSet?) -> CharacterSet? {
    switch (self, other) {
    case (_, .none):
      // anything minus everything is nothing
      return CharacterSet()
    case (.none, .some(let chars)):
      return chars.inverted
    case (.some(let selfChars), .some(let otherChars)):
      return selfChars.subtracting(otherChars)
    }
  }

  func contains(_ maybeChar: unichar?) -> Bool {
    switch (self, maybeChar) {
    case (.none, _):
      // nil character set accepts everything
      return true
    case (.some, .none):
      // Non-nil character set and nil character always fails
      return false
    case (.some(let set), .some(let char)):
      return set.contains(char)
    }
  }
}

/// An *assertion* that succeeds if `rule` succeeds but consumes no input and produces no syntax tree nodes.
final class AssertionRule: ParsingRuleWrapper {
  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    result.setZeroLength()
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "ASSERT \(rule.description)"
  }
}

/// An *assertion* that succeeds if `rule` fails and vice versa, and never consumes input.
final class NotAssertionRule: ParsingRuleWrapper {
  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    result.setZeroLength()
    result.succeeded.toggle()
    return performanceCounters.recordResult(result)
  }

  override var description: String {
    "NOT \(rule.description)"
  }

  override var possibleOpeningCharacters: CharacterSet? {
    // It doesn't matter what our inner rule is. If we're asserting that the inner rule
    // fails, a set of possible characters that scopes success tells us nothing about
    // characters that imply failure.
    //
    // Example: Literal("!["), possibleChars == "!"
    //          Literal("![").assertInverse() succeeds on "!!", so you have to evaluate
    //          the rule even if you're looking at a "!"
    return nil
  }
}

/// Returns the result of the first successful match, or .fail otherwise.
public final class Choice: ParsingRuleSequenceWrapper {
  public init(_ rules: ParsingRule...) {
    super.init(rules)
    var characters = CharacterSet()
    for rule in rules {
      if let subruleCharacters = rule.possibleOpeningCharacters {
        characters.formUnion(subruleCharacters)
      } else {
        self._possibleCharacters = nil
        return
      }
    }
    self._possibleCharacters = characters
  }

  private var _possibleCharacters: CharacterSet?

  public override var possibleOpeningCharacters: CharacterSet? { _possibleCharacters }

  public override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    var examinedLength = 1
    let ch = buffer.utf16(at: index)
    guard _possibleCharacters.contains(ch) else {
      return .fail
    }
    for rule in rules {
      if !rule.possibleOpeningCharacters.contains(ch) { continue }
      var result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
      examinedLength = max(examinedLength, result.examinedLength)
      if result.succeeded {
        result.examinedLength = examinedLength
        return performanceCounters.recordResult(result)
      }
    }
    return performanceCounters.recordResult(ParsingResult(succeeded: false, examinedLength: examinedLength))
  }

  public override var description: String {
    "CHOICE: \(rules.map(String.init(describing:)).joined(separator: ", "))"
  }
}

final class TraceRule: ParsingRuleWrapper {
  override init(_ rule: ParsingRule) {
    super.init(rule)
    rule.wrapInnerRules { (innerRule) -> ParsingRule in
      if !(innerRule is TraceRule) {
        return TraceRule(innerRule)
      } else {
        return innerRule
      }
    }
  }

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    let locationHint = buffer.utf16(at: index).map { char -> String in
      guard let scalar = Unicode.Scalar(char) else {
        assertionFailure()
        return "invalid"
      }
      return scalar.debugDescription
    } ?? "(eof)"
    let currentEntry = TraceBuffer.Entry(rule: rule, index: index, locationHint: locationHint)
    TraceBuffer.shared.pushEntry(currentEntry)
    let result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    currentEntry.result = result
    TraceBuffer.shared.popEntry()
    return result
  }

  override var description: String {
    rule.description
  }
}

final class PropertyRule<K: NodePropertyKey>: ParsingRuleWrapper {
  init(key: K.Type, value: K.Value, rule: ParsingRule) {
    self.key = key
    self.value = value
    super.init(rule)
  }

  let key: K.Type
  let value: K.Value

  override func parsingResult(from buffer: SafeUnicodeBuffer, at index: Int, memoizationTable: MemoizationTable) -> ParsingResult {
    let result = rule.parsingResult(from: buffer, at: index, memoizationTable: memoizationTable)
    result.node?[key] = value
    return result
  }
}
