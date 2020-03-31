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

/// Currently this is an un-editable string. But the goal is to support efficient edits with a Piece Table data structure.
public final class PieceTable: TextBuffer {
  public init(_ string: String) {
    self.string = string as NSString
  }

  private let string: NSString

  public var startIndex: TextBufferIndex { TextBufferIndex(0) }
  public var endIndex: TextBufferIndex { TextBufferIndex(string.length) }

  public func utf16(at index: TextBufferIndex) -> unichar? {
    guard index.stringIndex < string.length else {
      return nil
    }
    return string.character(at: index.stringIndex)
  }

  public func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard index.stringIndex < string.length else {
      return nil
    }
    guard let scalar = UnicodeScalar(string.character(at: index.stringIndex)) else {
      assertionFailure()
      return nil
    }
    return scalar
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard index.stringIndex < string.length else {
      return nil
    }
    return TextBufferIndex(index.stringIndex + 1)
  }

  public func isEOF(_ index: TextBufferIndex) -> Bool {
    return index.stringIndex >= string.length
  }

  public subscript(range: Range<TextBufferIndex>) -> String {
    let stringIndexRange = NSRange(location: range.lowerBound.stringIndex, length: range.upperBound.stringIndex - range.lowerBound.stringIndex)
    return string.substring(with: stringIndexRange) as String
  }
}
