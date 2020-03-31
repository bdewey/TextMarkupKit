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

public protocol TextBuffer {
  var startIndex: Int { get }
  func utf16(at index: Int) -> unichar?
}

public extension TextBuffer {
  /// Finds the first occurence of `string` on or after `startingPosition` and returns the start index of the match, if found.
  /// - note: This is a naive string search which should probably get optimized if the string length is more than 1-2 characters.
  func firstIndex(of string: String, startingPosition: Int) -> Int? {
    let unicodeCharacters = Array(string.utf16)
    var currentPosition = startingPosition
    while self.utf16(at: currentPosition) != nil {
      var innerPosition = currentPosition
      var inputIndex = 0
      while inputIndex < unicodeCharacters.count,
        let bufferCharacter = self.utf16(at: innerPosition),
        bufferCharacter == unicodeCharacters[inputIndex] {
        inputIndex += 1
        innerPosition += 1
      }
      if inputIndex == unicodeCharacters.count {
        return currentPosition
      }
      // If we read a character it's safe to advance
      currentPosition += 1
    }
    return nil
  }

  func index(after terminator: unichar, startingAt startIndex: Int) -> Int {
    var currentPosition = startIndex
    while let unichar = utf16(at: currentPosition), unichar != terminator {
      currentPosition += 1
    }
    if utf16(at: currentPosition) != nil {
      currentPosition += 1
    }
    return currentPosition
  }
}
