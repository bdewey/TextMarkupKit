// 

import Foundation

public struct TrimmingTextBuffer {
  public init(
    textBuffer: TextBuffer,
    startIndex: Int,
    shouldTrim: @escaping (unichar, TextBuffer, Int) -> Bool
  ) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.shouldTrim = shouldTrim
  }

  private let textBuffer: TextBuffer
  public let startIndex: Int
  private let shouldTrim: (unichar, TextBuffer, Int) -> Bool
}

extension TrimmingTextBuffer: TextBuffer {
  public func utf16(at index: Int) -> unichar? {
    guard
      index >= startIndex,
      let unicode = textBuffer.utf16(at: index),
      !shouldTrim(unicode, textBuffer, index)
    else {
      return nil
    }
    return unicode
  }
}
