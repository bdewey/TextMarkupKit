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
public final class TextBuffer {
  /// An index into the buffer. Note that the index will remain valid even across edits.
  public typealias Index = String.Index

  public init(_ string: String) {
    self.string = string
  }

  private let string: String

  public var startIndex: Index { string.startIndex }
  public var endIndex: Index { string.endIndex }

  public func character(at index: Index) -> Character? {
    guard index != string.endIndex else {
      return nil
    }
    return string[index]
  }

  public func unicodeScalar(at index: Index) -> UnicodeScalar? {
    guard index != string.endIndex else {
      return nil
    }
    return string.unicodeScalars[index]
  }

  public func index(after index: Index) -> Index? {
    guard index != string.endIndex else {
      return nil
    }
    return string.index(after: index)
  }

  public func isEOF(_ index: Index) -> Bool {
    return index == string.endIndex
  }

  public subscript<R: RangeExpression>(range: R) -> String where R.Bound == String.Index {
    return String(string[range])
  }
}

extension TextBuffer {
  public func index(after terminator: Character, startingAt startIndex: Index) -> Index {
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
