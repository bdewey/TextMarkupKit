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

/// An opaque, stable reference to a spot in a TextBuffer.
public struct TextBufferIndex: Comparable {
  internal init(_ stringIndex: Int) {
    self.stringIndex = stringIndex
  }

  internal let stringIndex: Int

  public static func < (lhs: TextBufferIndex, rhs: TextBufferIndex) -> Bool {
    return lhs.stringIndex < rhs.stringIndex
  }
}

public protocol TextBuffer {
  var startIndex: TextBufferIndex { get }
  func utf16(at index: TextBufferIndex) -> unichar?
  func index(after index: TextBufferIndex) -> TextBufferIndex?
}

public extension TextBuffer {
  /// Finds the first occurence of `string` on or after `startingPosition` and returns the start index of the match, if found.
  /// - note: This is a naive string search which should probably get optimized if the string length is more than 1-2 characters.
  func firstIndex(of string: String, startingPosition: TextBufferIndex) -> TextBufferIndex? {
    let unicodeCharacters = Array(string.utf16)
    var currentPosition = startingPosition
    while self.utf16(at: currentPosition) != nil {
      var innerPosition = currentPosition
      var inputIndex = 0
      while inputIndex < unicodeCharacters.count,
        let bufferCharacter = self.utf16(at: innerPosition),
        bufferCharacter == unicodeCharacters[inputIndex] {
        inputIndex += 1
        innerPosition = index(after: innerPosition)!
      }
      if inputIndex == unicodeCharacters.count {
        return currentPosition
      }
      // If we read a character it's safe to advance
      currentPosition = index(after: currentPosition)!
    }
    return nil
  }

  func index(after terminator: unichar, startingAt startIndex: TextBufferIndex) -> TextBufferIndex {
    var currentPosition = startIndex
    while utf16(at: currentPosition) != terminator, let next = index(after: currentPosition) {
      currentPosition = next
    }
    if let next = index(after: currentPosition) {
      currentPosition = next
    }
    return currentPosition
  }
}
