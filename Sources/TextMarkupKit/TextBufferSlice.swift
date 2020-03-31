// 

import Foundation

public struct TextBufferSlice {
  public init(textBuffer: TextBuffer, startIndex: TextBufferIndex, endIndex: TextBufferIndex) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.endIndex = endIndex
  }

  public let textBuffer: TextBuffer
  public let startIndex: TextBufferIndex
  public let endIndex: TextBufferIndex
}

extension TextBufferSlice: TextBuffer {
  public func character(at index: TextBufferIndex) -> Character? {
    guard (startIndex..<endIndex).contains(index) else {
      return nil
    }
    return textBuffer.character(at: index)
  }

  public func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard (startIndex..<endIndex).contains(index) else {
      return nil
    }
    return textBuffer.unicodeScalar(at: index)
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard index < endIndex else {
      return nil
    }
    return textBuffer.index(after: index)
  }

  public func index(before index: TextBufferIndex) -> TextBufferIndex? {
    guard index > startIndex else {
      return nil
    }
    return textBuffer.index(before: index)
  }
}
