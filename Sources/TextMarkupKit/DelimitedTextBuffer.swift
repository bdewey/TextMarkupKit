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

/// Filters another TextBuffer. It will stop advancing through the buffer when the buffer is positioned at a delimiter string.
public struct DelimitedTextBuffer {
  public init(textBuffer: TextBuffer, delimiter: String) {
    self.textBuffer = textBuffer
    self.delimiter = delimiter
  }

  private let textBuffer: TextBuffer
  private let delimiter: String
}

extension DelimitedTextBuffer: TextBuffer {
  public var startIndex: TextBufferIndex { textBuffer.startIndex }

  public func character(at index: TextBufferIndex) -> Character? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.character(at: index)
  }

  public func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.unicodeScalar(at: index)
  }

  public func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard textBuffer.position(afterMatching: delimiter, startingPosition: index) == nil else {
      return nil
    }
    return textBuffer.index(after: index)
  }

  public func index(before index: TextBufferIndex) -> TextBufferIndex? {
    return textBuffer.index(before: index)
  }
}
