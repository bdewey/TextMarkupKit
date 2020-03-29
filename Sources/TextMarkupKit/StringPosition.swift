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

/// Combination of a string and an index into that string.
public struct StringPosition: Comparable {
  public enum Error: Swift.Error {
    case readPastEndOfText
    case advancePastEndOfText
  }

  public static func < (lhs: StringPosition, rhs: StringPosition) -> Bool {
    return lhs.position < rhs.position
  }

  public let string: String
  public var position: String.Index

  public func character() throws -> Character {
    guard !isEOF else { throw Error.readPastEndOfText }
    return string[position]
  }

  public func unicodeScalar() throws -> UnicodeScalar {
    guard !isEOF else { throw Error.readPastEndOfText }
    return string.unicodeScalars[position]
  }

  public mutating func advance() throws {
    guard !isEOF else { throw Error.advancePastEndOfText }
    position = string.index(after: position)
  }

  public mutating func advance(past terminator: Character) {
    while !isEOF, string[position] != terminator {
      position = string.index(after: position)
    }
    if !isEOF {
      position = string.index(after: position)
    }
  }

  public var isEOF: Bool {
    return position == string.endIndex
  }

  public func testMembership(in characterSet: CharacterSet, includeEOF: Bool = true) -> Bool {
    if isEOF {
      return includeEOF
    }
    return characterSet.contains(string.unicodeScalars[position])
  }
}
