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

/// A `Pattern` is a sequence that appears inside a stream of characters.
public protocol Pattern {
  var sentinels: CharacterSet { get }
  mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult
  func recognizer(type: NodeType) -> Recognizer?
}

extension Pattern {
  public func recognizer(type: NodeType) -> Recognizer? {
    var pattern = self
    return { iterator in
      let savepoint = iterator
      var patternResult: PatternRecognitionResult = .needsMoreInput
      while let char = iterator.next() {
        patternResult = pattern.patternRecognized(after: char)
        if patternResult != .needsMoreInput { break }
      }
      if case .foundPattern = patternResult {
        for _ in 0 ..< patternResult.extraCharacters { iterator.rewind() }
        return Node(type: type, range: savepoint.index ..< iterator.index)
      } else {
        iterator = savepoint
        return nil
      }
    }
  }
}

public extension Pattern {
  func asAnyPattern() -> AnyPattern { AnyPattern(self) }
}

public struct AnyPattern: Pattern, ExpressibleByStringLiteral {
  public init(_ innerPattern: Pattern) {
    self.innerPattern = innerPattern
  }

  public init(stringLiteral value: StringLiteralType) {
    self.innerPattern = StringLiteralPattern(value)
  }

  public static let anything = MatchEverythingPattern().asAnyPattern()

  public static func stringPattern(_ string: String) -> AnyPattern {
    return StringLiteralPattern(string).asAnyPattern()
  }

  public static func repeating(_ char: unichar, allowableRange: Range<Int>) -> AnyPattern {
    RepeatingPattern(char, allowableRange: allowableRange).asAnyPattern()
  }

  public var innerPattern: Pattern

  public var sentinels: CharacterSet { innerPattern.sentinels }
  public mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult {
    return innerPattern.patternRecognized(after: character)
  }

  public func recognizer(type: NodeType) -> Recognizer? {
    return innerPattern.recognizer(type: type)
  }
}

/// Possible states of finding a pattern inside a stream.
public enum PatternRecognitionResult: Equatable {
  /// The most recent character completes the pattern
  case foundPattern(patternLength: Int, patternStart: Int)

  /// The most recent character is definitely *not* part of the pattern.
  case no

  /// The most recent character *might* be part of a pattern that will be completed with more characters.
  case needsMoreInput

  var extraCharacters: Int {
    switch self {
    case let .foundPattern(patternLength: patternLength, patternStart: patternStart):
      return patternStart - patternLength
    case .no, .needsMoreInput:
      return 0
    }
  }
}

/// Concrete implementation of Pattern that finds a string in a stream of characters.
public struct StringLiteralPattern: Pattern, ExpressibleByStringLiteral {
  /// Initialize with a string
  public init(_ string: String) {
    self.stringUtf16 = Array(string.utf16)
    self.sentinels = CharacterSet(charactersIn: String(string.prefix(1)))
    self.matchAtIndex = Array(repeating: false, count: stringUtf16.count)
  }

  /// Initialize with a string literal
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  public let sentinels: CharacterSet

  /// The UTF-16 characters we need to match
  private let stringUtf16: [unichar]

  private var matchAtIndex: [Bool]

  public mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult {
    guard !stringUtf16.isEmpty else {
      return .no
    }

    var anyMatches = false

    for index in (1 ..< stringUtf16.count).reversed() {
      let match = matchAtIndex[index-1] && stringUtf16[index] == character
      anyMatches = anyMatches || match
      matchAtIndex[index] = match
    }
    let initialMatch = stringUtf16[0] == character
    anyMatches = anyMatches || initialMatch
    matchAtIndex[0] = initialMatch

    if matchAtIndex.last ?? false {
      return .foundPattern(patternLength: stringUtf16.count, patternStart: stringUtf16.count)
    } else if anyMatches {
      return .needsMoreInput
    } else {
      return .no
    }
  }

  private func advanceIndex(_ index: Int, ifMatches character: unichar) -> Int? {
    if stringUtf16[index] == character {
      return index + 1
    } else {
      return nil
    }
  }
}

public struct RepeatingPattern: Pattern {
  public init(_ targetCharacter: unichar, allowableRange: Range<Int>) {
    self.targetCharacter = targetCharacter
    self.allowableRange = allowableRange
    let scalar = UnicodeScalar(targetCharacter)!
    sentinels = CharacterSet(charactersIn: scalar ... scalar)
  }

  public let sentinels: CharacterSet
  private let targetCharacter: unichar
  private let allowableRange: Range<Int>

  private var matchCount = 0

  public mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult {
    if character == targetCharacter {
      matchCount += 1
      return .needsMoreInput
    } else {
      let result: PatternRecognitionResult
      if allowableRange.contains(matchCount) {
        result = .foundPattern(patternLength: matchCount, patternStart: matchCount + 1)
      } else {
        result = .no
      }
      matchCount = 0
      return result
    }
  }
}

public struct MatchEverythingPattern: Pattern {
  public var sentinels: CharacterSet = {
    CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
  }()

  public func patternRecognized(after character: unichar) -> PatternRecognitionResult {
    return .foundPattern(patternLength: 1, patternStart: 1)
  }

  public func recognizer(type: NodeType) -> Recognizer? {
    return nil
  }
}
