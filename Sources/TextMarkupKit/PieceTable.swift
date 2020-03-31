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

  public var startIndex: Int { 0 }
  public var endIndex: Int { string.length }

  public func utf16(at index: Int) -> unichar? {
    guard index < string.length else {
      return nil
    }
    return string.character(at: index)
  }

  public subscript(range: Range<Int>) -> String {
    let stringIndexRange = NSRange(location: range.lowerBound, length: range.count)
    return string.substring(with: stringIndexRange) as String
  }
}
