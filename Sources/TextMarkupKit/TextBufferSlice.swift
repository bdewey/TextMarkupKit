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
  public func utf16(at index: TextBufferIndex) -> unichar? {
    guard (startIndex..<endIndex).contains(index) else {
      return nil
    }
    return textBuffer.utf16(at: index)
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard index < endIndex else {
      return nil
    }
    return textBuffer.index(after: index)
  }
}
