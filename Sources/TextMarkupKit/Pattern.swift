// 

import Foundation

/// A `Pattern` is a sequence that appears inside a stream of characters.
public protocol Pattern {
  var sentinels: CharacterSet { get }
  mutating func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult
  func recognizer(type: NodeType) -> Recognizer?
}

extension Pattern {
  public func recognizer(type: NodeType) -> Recognizer? {
    var pattern = self
    return { iterator in
      let savepoint = iterator
      var patternResult: PatternRecognitionResult = .maybe
      while let char = iterator.next() {
        patternResult = pattern.patternRecognized(after: char, iterator: iterator)
        if patternResult != .maybe { break }
      }
      if patternResult == .yes {
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
  public mutating func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult {
    return innerPattern.patternRecognized(after: character, iterator: iterator)
  }

  public func recognizer(type: NodeType) -> Recognizer? {
    return innerPattern.recognizer(type: type)
  }
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
    sentinels = CharacterSet(charactersIn: String(string.prefix(1)))
  }

  /// Initialize with a string literal
  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  public let sentinels: CharacterSet

  /// The UTF-16 characters we need to match
  private let stringUtf16: [unichar]

  /// Expresses all current partial matches. We expect the next incoming character to match `stringUtf16` at these indexes
  /// to keep the possibilities going.
  private var nextMatchIndexes: [Int] = []

  public mutating func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult {
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

public struct RepeatingPattern: Pattern {

  public init(_ targetCharacter: unichar, allowableRange: Range<Int>) {
    self.targetCharacter = targetCharacter
    self.allowableRange = allowableRange
    let scalar = UnicodeScalar(targetCharacter)!
    sentinels = CharacterSet(charactersIn: scalar...scalar)
  }

  public let sentinels: CharacterSet
  private let targetCharacter: unichar
  private let allowableRange: Range<Int>

  private var matchCount = 0

  public mutating func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult {
    if character == targetCharacter {
      matchCount += 1
    } else {
      matchCount = 0
    }
    if allowableRange.contains(matchCount) { return .yes }
    if matchCount > 0, matchCount < allowableRange.lowerBound { return .maybe }
    return .no
  }
}

public struct MatchEverythingPattern: Pattern {
  public var sentinels: CharacterSet = {
    CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
  }()

  public func patternRecognized(after character: unichar, iterator: NSStringIterator) -> PatternRecognitionResult {
    return .yes
  }

  public func recognizer(type: NodeType) -> Recognizer? {
    return nil
  }
}
