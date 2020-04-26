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

/// A Packrat grammar is a collection of parsing rules, one of which is the designated `start` rule.
public protocol PackratGrammar {
  /// The designated starting rule for parsing the grammar. This rule should produce exactly one syntax tree `Node`.
  var start: ParsingRule { get }
}

/// Implements a packrat parsing algorithm.
public final class PackratParser: CustomStringConvertible {
  /// Designated initializer.
  /// - Parameters:
  ///   - buffer: The content to parse.
  ///   - grammar: The grammar rules to apply to the contents of `buffer`
  // TODO: This should probably take a block that constructs a grammar rather than a grammar
  public init(buffer: PieceTable, grammar: PackratGrammar) {
    self.buffer = buffer
    self.grammar = grammar
    var memoizationRuleNames = [String]()
    grammar.start.forEachRule { rule in
      guard let memoRule = rule as? MemoizingRule else {
        return
      }
      memoRule.ruleIndex = memoizationRuleNames.count
      memoizationRuleNames.append(memoRule.name)
    }
    self.memoizationRuleNames = memoizationRuleNames
    self.memoizedResults = Array(
      repeating: MemoColumn(ruleNames: memoizationRuleNames),
      count: buffer.endIndex + 1
    )
  }

  /// The contents to parse.
  public let buffer: PieceTable

  /// The grammar rules to apply to the contents of `buffer`.
  public let grammar: PackratGrammar

  /// If any rules are tracing evaluation, the trace entries are stored here.
  public let traceBuffer = TraceBuffer()

  /// The names of the memoization rules in the grammar.
  private let memoizationRuleNames: [String]

  public var description: String {
    let (totalEntries, successfulEntries) = memoizationStatistics()
    let properties: [String: Any] = [
      "totalEntries": totalEntries,
      "successfulEntries": successfulEntries,
      "memoizationChecks": memoizationChecks,
      "memoizationHits": memoizationHits,
      "memoizationHitRate": String(format: "%.2f%%", 100.0 * Double(memoizationHits) / Double(memoizationChecks)),
    ]
    return "PackratParser: \(properties)"
  }

  /// Parses the contents of the buffer.
  /// - Throws: If the grammar could not parse the entire contents, throws `Error.incompleteParsing`. If the grammar resulted in more than one resulting node, throws `Error.ambiguousParsing`.
  /// - Returns: The single node at the root of the syntax tree resulting from parsing `buffer`
  public func parse() throws -> Node {
    let result = grammar.start.apply(to: self, at: 0)
    guard let node = result.node, result.length == buffer.endIndex else {
      throw Error.incompleteParsing(length: result.length)
    }
    return node
  }

  private var memoizationChecks = 0
  private var memoizationHits = 0

  /// Returns the memoized result of applying a rule at an index into the buffer, if it exists.
  public func memoizedResult(ruleIndex: Int, index: Int) -> ParsingResult? {
    let result = memoizedResults[index][ruleIndex]
    memoizationChecks += 1
    if result != nil { memoizationHits += 1 }
    return result
  }

  /// Memoizes the result of applying a rule at an index in the buffer.
  /// - Parameters:
  ///   - result: The parsing result to memoize.
  ///   - rule: The rule that generated the result that we are memoizing.
  ///   - index: The position in the input at which we applied the rule to get the result.
  public func memoizeResult(_ result: ParsingResult, ruleIndex: Int, index: Int) {
    assert(result.examinedLength > 0)
    assert((result.examinedLength + index) <= buffer.length + 1)
    assert(result.examinedLength >= result.length)
    memoizedResults[index][ruleIndex] = result
  }

  /// Adjust the memo tables for reuse after an edit to the input text where the characters in `originalRange` were replaced
  /// with `replacementLength` characters.
  public func applyEdit(originalRange: NSRange, replacementLength: Int) {
    precondition(replacementLength >= 0)
    let lengthIncrease = replacementLength - originalRange.length
    if lengthIncrease < 0 {
      // We need to *shrink* the memo table.
      memoizedResults.removeSubrange(originalRange.location ..< originalRange.location + abs(lengthIncrease))
    } else if lengthIncrease > 0 {
      // We need to *grow* the memo table.
      memoizedResults.insert(
        contentsOf: Array<MemoColumn>(
          repeating: MemoColumn(ruleNames: memoizationRuleNames),
          count: lengthIncrease
        ),
        at: originalRange.location
      )
    }
    // Now that we've adjusted the length of the memo table, everything in these columns is invalid.
    let invalidRange = NSRange(location: originalRange.location, length: replacementLength)
    for column in Range(invalidRange)! {
      memoizedResults[column].removeAll()
    }
    // Finally go through everything to the left of the removed range and invalidate memoization
    // results where it overlaps the edited range.
    var removedResults = [Int: [ParsingResult]]()
    for column in 0 ..< invalidRange.location {
      let invalidLength = invalidRange.location - column
      if memoizedResults[column].maxExaminedLength >= invalidLength {
        let victims = memoizedResults[column].remove {
          $0.examinedLength >= invalidLength
        }
        removedResults[column] = victims
      }
    }
  }

  // MARK: - Supporting types

  public enum Error: Swift.Error {
    /// The supplied grammar did not parse the entire contents of the buffer.
    /// - parameter length: How much of the buffer was consumed by the grammar.
    case incompleteParsing(length: Int)

    /// The supplied grammar consumed the entire buffer but resulted in more than one top-level node.
    /// - parameter nodes: The nodes generated by parsing.
    case ambiguousParsing(nodes: [Node])
  }

  // MARK: - Memoization internals

  private var memoizedResults: [MemoColumn]

  public func memoizationStatistics() -> (totalEntries: Int, successfulEntries: Int) {
    var totalEntries = 0
    var successfulEntries = 0
    for column in memoizedResults {
      for maybeResult in column {
        guard let result = maybeResult else { continue }
        totalEntries += 1
        if result.succeeded { successfulEntries += 1 }
      }
    }
    return (totalEntries: totalEntries, successfulEntries: successfulEntries)
  }
}

// MARK: - Memoization

private extension PackratParser {
  /// A column in the memo table. It contains a fixed number of slots for memoizing results, one slot per memo rule.
  /// It's the job of the parser to assign a unique index to each memo rule so different rules don't clobber each other.
  struct MemoColumn {
    /// Designated initializer.
    /// - Parameter ruleNames: The names of the memoization rules. The expectation is each rule will use the
    /// same index as its name, allowing helpful debugging messages.
    init(ruleNames: [String]) {
      self.ruleNames = ruleNames
      // Make sure we have enough storage to store a result from every rule.
      self.storage = Array(repeating: nil, count: ruleNames.count)
    }

    private let ruleNames: [String]
    private(set) var maxExaminedLength = 0
    private var storage: [ParsingResult?]

    subscript(id: Int) -> ParsingResult? {
      get {
        storage[id]
      }
      set {
        guard let newValue = newValue else {
          assertionFailure()
          return
        }
        storage[id] = newValue
        maxExaminedLength = Swift.max(maxExaminedLength, newValue.examinedLength)
      }
    }

    mutating func removeAll() {
      for i in storage.indices {
        storage[i] = nil
      }
      maxExaminedLength = 0
    }

    /// Removes results that match a predicate.
    /// - parameter predicate: A block that returns true for each result that should be removed from the memo column.
    /// - returns: All removed results.
    @discardableResult
    mutating func remove(where predicate: (ParsingResult) -> Bool) -> [ParsingResult] {
      var maxExaminedLength = 0
      var removedResults = [ParsingResult]()
      for (i, maybeResult) in storage.enumerated() {
        guard let result = maybeResult else { continue }
        if predicate(result) {
          storage[i] = nil
          removedResults.append(result)
        } else {
          maxExaminedLength = Swift.max(maxExaminedLength, result.examinedLength)
        }
      }
      self.maxExaminedLength = maxExaminedLength
      return removedResults
    }
  }
}

extension PackratParser.MemoColumn: Collection {
  typealias Index = Int
  var startIndex: Index { storage.startIndex }
  var endIndex: Index { storage.endIndex }
  func index(after i: Index) -> Index {
    return storage.index(after: i)
  }
}
