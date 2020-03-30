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
  internal init(_ stringIndex: String.Index) {
    self.stringIndex = stringIndex
  }

  internal let stringIndex: String.Index

  public static func < (lhs: TextBufferIndex, rhs: TextBufferIndex) -> Bool {
    return lhs.stringIndex < rhs.stringIndex
  }
}

public protocol TextBuffer {
  var startIndex: TextBufferIndex { get }
  func character(at index: TextBufferIndex) -> Character?
  func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar?
  func index(after index: TextBufferIndex) -> TextBufferIndex?
  func index(before index: TextBufferIndex) -> TextBufferIndex?
}

public extension TextBuffer {
  /// - returns: The index after matching all characters of `string` if the string matches, `nil` otherwise.
  func position(afterMatching string: String, startingPosition: TextBufferIndex) -> TextBufferIndex? {
    var currentPosition = startingPosition
    for character in string {
      guard
        character == self.character(at: currentPosition),
        let nextPosition = self.index(after: currentPosition)
      else {
        return nil
      }
      currentPosition = nextPosition
    }
    return currentPosition
  }

  func index(after terminator: Character, startingAt startIndex: TextBufferIndex) -> TextBufferIndex {
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
