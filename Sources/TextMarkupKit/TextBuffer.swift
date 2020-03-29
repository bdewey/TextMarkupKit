// 

import Foundation

/// Currently this is an un-editable string. But the goal is to support efficient edits with a Piece Table data structure.
public final class TextBuffer {
  /// An index into the buffer. Note that the index will remain valid even across edits.
  public typealias Index = String.Index

  public init(_ string: String) {
    self.string = string
  }

  private let string: String

  public var startIndex: Index { string.startIndex }
  public var endIndex: Index { string.endIndex }

  public func character(at index: Index) -> Character? {
    guard index != string.endIndex else {
      return nil
    }
    return string[index]
  }

  public func unicodeScalar(at index: Index) -> UnicodeScalar? {
    guard index != string.endIndex else {
      return nil
    }
    return string.unicodeScalars[index]
  }

  public func index(after index: Index) -> Index? {
    guard index != string.endIndex else {
      return nil
    }
    return string.index(after: index)
  }

  public func isEOF(_ index: Index) -> Bool {
    return index == string.endIndex
  }

  public subscript<R: RangeExpression>(range: R) -> String where R.Bound == String.Index {
    return String(string[range])
  }
}

extension TextBuffer {
  public func index(after terminator: Character, startingAt startIndex: Index) -> Index {
    var currentPosition = startIndex
    while character(at: currentPosition) != terminator, let next = index(after: currentPosition) {
      currentPosition = next
    }
    if let next = index(after: currentPosition) {
      currentPosition = next
    }
    return currentPosition
  }
}
