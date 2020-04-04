// 

import Foundation

/// A `Pattern` is a sequence that appears inside a stream of characters.
public protocol Pattern {
  mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult
}

/// Possible states of finding a pattern inside a stream.
public enum PatternRecognitionResult {
  /// The most recent character completes the pattern
  case yes

  /// The most recent character is definitely *not* part of the pattern.
  case no

  /// The most recent character *might* be part of a pattern that will be completed with more characters.
  case maybe
}

/// Concrete implementation of Pattern that finds a string in a stream of characters.
public struct StringLiteralPattern: Pattern, ExpressibleByStringLiteral {
  /// Initialize with a string
  public init(_ string: String) {
    self.stringUtf16 = Array(string.utf16)
  }

  /// Initialize with a string literal
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  /// The UTF-16 characters we need to match
  private let stringUtf16: [unichar]

  /// Expresses all current partial matches. We expect the next incoming character to match `stringUtf16` at these indexes
  /// to keep the possibilities going.
  private var nextMatchIndexes: [Int] = []

  public mutating func patternRecognized(after character: unichar) -> PatternRecognitionResult {
    guard !stringUtf16.isEmpty else {
      return .no
    }

    var nextIndexes = nextMatchIndexes.compactMap { advanceIndex($0, ifMatches: character) }
    if stringUtf16[0] == character { nextIndexes.append(1) }

    nextMatchIndexes = nextIndexes.filter { $0 < stringUtf16.count }
    if nextMatchIndexes.count != nextIndexes.count {
      return .yes
    } else if nextMatchIndexes.isEmpty {
      return .no
    } else {
      return .maybe
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
