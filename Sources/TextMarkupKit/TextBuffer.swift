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

/// Currently this is an un-editable string. But the goal is to support efficient edits with a Piece Table data structure.
public final class TextBuffer {
  public init(_ string: String) {
    self.string = string
  }

  private let string: String

  public var startIndex: TextBufferIndex { TextBufferIndex(string.startIndex) }
  public var endIndex: TextBufferIndex { TextBufferIndex(string.endIndex) }

  public func character(at index: TextBufferIndex) -> Character? {
    guard index.stringIndex != string.endIndex else {
      return nil
    }
    return string[index.stringIndex]
  }

  public func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard index.stringIndex != string.endIndex else {
      return nil
    }
    return string.unicodeScalars[index.stringIndex]
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard index.stringIndex != string.endIndex else {
      return nil
    }
    return TextBufferIndex(string.index(after: index.stringIndex))
  }

  public func isEOF(_ index: TextBufferIndex) -> Bool {
    return index.stringIndex == string.endIndex
  }

  public subscript(range: Range<TextBufferIndex>) -> String {
    let stringIndexRange = range.lowerBound.stringIndex ..< range.upperBound.stringIndex
    return String(string[stringIndexRange])
  }
}

extension TextBuffer {
  public func index(after terminator: Character, startingAt startIndex: TextBufferIndex) -> TextBufferIndex {
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
