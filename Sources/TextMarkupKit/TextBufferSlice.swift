// 

import Foundation

public struct TextBufferSlice {
  public init(textBuffer: TextBuffer, startIndex: Int, endIndex: Int) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.endIndex = endIndex
  }

  public let textBuffer: TextBuffer
  public let startIndex: Int
  public let endIndex: Int
}

extension TextBufferSlice: TextBuffer {
  public func utf16(at index: Int) -> unichar? {
    guard (startIndex..<endIndex).contains(index) else {
      return nil
    }
    return textBuffer.utf16(at: index)
  }
}
