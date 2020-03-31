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

public typealias TextBufferFilter = (unichar, TextBuffer, Int) -> Bool

/// Composes another `TextBuffer` and only passes through `utf16` values that pass a filter.
public struct FilteringTextBuffer: TextBuffer {
  /// Designated initializer.
  /// - parameter textBuffer: The text buffer to wrap.
  /// - parameter startIndex: Starting index into the view.
  /// - parameter isIncluded: Filtering function. Only `utf16` values that pass this filter will be returned.
  public init(
    textBuffer: TextBuffer,
    startIndex: Int,
    isIncluded: @escaping TextBufferFilter
  ) {
    self.textBuffer = textBuffer
    self.startIndex = startIndex
    self.isIncluded = isIncluded
  }

  private let textBuffer: TextBuffer
  public let startIndex: Int
  private let isIncluded: TextBufferFilter

  /// Filters the call to the inner `textBuffer.utf16(at:)`
  public func utf16(at index: Int) -> unichar? {
    if
      index >= startIndex,
      let unicode = textBuffer.utf16(at: index),
      isIncluded(unicode, textBuffer, index) {
      return unicode
    }
    return nil
  }
}
