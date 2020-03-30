// 

import Foundation

/// Filters another TextBuffer. It will stop advancing through the buffer when the buffer is positioned at a delimiter string.
public struct DelimitedTextBuffer {
  public init(textBuffer: TextBuffer, delimiter: String) {
    self.textBuffer = textBuffer
    self.delimiter = delimiter
  }

  private let textBuffer: TextBuffer
  private let delimiter: String
}

extension DelimitedTextBuffer: TextBuffer {
  public var startIndex: TextBufferIndex { textBuffer.startIndex }

  public func character(at index: TextBufferIndex) -> Character? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.character(at: index)
  }

  public func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.unicodeScalar(at: index)
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.index(after: index)
  }

  public func index(before index: TextBufferIndex) -> TextBufferIndex? {
    return textBuffer.index(before: index)
  }
}
