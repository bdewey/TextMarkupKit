// 

import Foundation

/// Defines a "scope" inside another `textBuffer` -- slice of the composed textBuffer contents.
public struct ScopedTextBuffer: TextBuffer {
  /// A function that defines the end of the scope.
  public typealias Scope = (unichar, TextBuffer, Int) -> Bool

  /// Designated initializer.
  /// - parameter textBuffer: The text buffer to wrap.
  /// - parameter startIndex: Starting index into the view.
  /// - parameter scopeEnd: The first index for which `scopeEnd` returns true is the end of the scoped slice.
  public init(
    textBuffer: TextBuffer,
    startIndex: Int,
    scopeEnd: @escaping Scope
  ) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.scopeEnd = scopeEnd
  }

  private let textBuffer: TextBuffer
  public let startIndex: Int
  private let scopeEnd: Scope

  /// Filters the call to the inner `textBuffer.utf16(at:)`
  public func utf16(at index: Int) -> unichar? {
    if
      index >= startIndex,
      let unicode = textBuffer.utf16(at: index),
      !scopeEnd(unicode, textBuffer, index) {
      return unicode
    }
    return nil
  }

  public static func endAfter(_ literal: String) -> Scope {
    return { _, textBuffer, index in
      let literalCount = literal.utf16.count
      for (charIndex, char) in literal.utf16.enumerated() {
        let bufferIndex = index - literalCount + charIndex
        guard let bufferChar = textBuffer.utf16(at: bufferIndex), bufferChar == char else {
          return false
        }
      }
      return true
    }
  }
}

public final class EndAfterPatternTextBuffer: TextBuffer {
  public init(textBuffer: TextBuffer, startIndex: Int, pattern: Pattern) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.pattern = pattern
  }

  private let textBuffer: TextBuffer
  public let startIndex: Int
  private var pattern: Pattern
  private var previousIndex: Int?
  private var memoizedResult: Bool?

  public func utf16(at index: Int) -> unichar? {
    if
      index >= startIndex,
      let char = textBuffer.utf16(at: index),
      !isPattern(completedBy: char, at: index) {
      return char
    }
    return nil
  }

  private func isPattern(completedBy character: unichar, at index: Int) -> Bool {
    if let previousIndex = previousIndex {
      // If we've been called before, the only legit values of `previousIndex` are
      // the same index as before (meaning we're being called multiple times with the same index
      // which is inefficient but legitimate) or advancing by a single character
      if previousIndex == index {
        return memoizedResult!
      }
      assert(previousIndex == index - 1)
    }
    previousIndex = index
    return pattern.patternRecognized(after: character) == .yes
  }
}

public extension TextBuffer {
  func scope(startingAt index: Int, endingAfter pattern: Pattern) -> TextBuffer {
    return EndAfterPatternTextBuffer(textBuffer: self, startIndex: index, pattern: pattern)
  }

  func scope(startingAt index: Int, endingAfter pattern: StringLiteralPattern) -> TextBuffer {
    return EndAfterPatternTextBuffer(textBuffer: self, startIndex: index, pattern: pattern)
  }
}
