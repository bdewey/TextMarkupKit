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
public final class PieceTable: TextBuffer, CustomStringConvertible, Sequence {
  public init(_ string: String) {
    self.string = string as NSString
  }

  private let string: NSString

  public var startIndex: Int { 0 }
  public var endIndex: Int { string.length }

  public var length: Int { string.length }

  public private(set) var eofRead = 0
  public private(set) var charactersRead = 0

  public func clearStatistics() {
    eofRead = 0
    charactersRead = 0
  }

  public func utf16(at index: Int) -> unichar? {
    guard index >= 0, index < string.length else {
      eofRead += 1
      return nil
    }
    charactersRead += 1
    return string.character(at: index)
  }

  public func makeIterator() -> Iterator {
    return Iterator(index: 0, string: self)
  }

  public subscript(range: Range<Int>) -> String {
    let stringIndexRange = NSRange(location: range.lowerBound, length: range.count)
    return string.substring(with: stringIndexRange) as String
  }

  public var description: String {
    let properties: [String: Any] = [
      "length": string.length,
      "charactersRead": charactersRead,
      "eofRead": eofRead,
    ]
    return "PieceTable \(properties)"
  }
}

public enum NSStringIteratorScopeType {
  case endBeforePattern
  case endAfterPattern
}

public protocol NSStringIterator {
  var index: Int { get set }
  mutating func rewind() -> Bool
  mutating func next() -> unichar?
  func pushScope(_ scopeType: NSStringIteratorScopeType, pattern: AnyPattern) -> NSStringIterator
  func popScope() -> NSStringIterator
}

extension PieceTable {
  public struct Iterator: NSStringIterator, IteratorProtocol {
    internal init(index: Int, string: PieceTable) {
      self.index = index
      self.string = string
    }

    public var index: Int
    private let string: PieceTable

    public mutating func rewind() -> Bool {
      if index > 0 {
        index -= 1
        return true
      }
      return false
    }

    public mutating func next() -> unichar? {
      guard index < string.length else {
        return nil
      }
      let char = string.utf16(at: index)
      index += 1
      return char
    }

    public func popScope() -> NSStringIterator {
      assertionFailure()
      return self
    }
  }

  public struct EndingAfterIterator: NSStringIterator {
    internal init(iterator: NSStringIterator, pattern: Pattern) {
      self.innerIterator = iterator
      self.pattern = pattern
    }

    private var innerIterator: NSStringIterator
    private var pattern: Pattern
    private var foundPattern = false
    public var index: Int {
      get { innerIterator.index }
      set { innerIterator.index = newValue }
    }

    public mutating func rewind() -> Bool {
      return innerIterator.rewind()
    }

    public mutating func next() -> unichar? {
      guard !foundPattern, let char = innerIterator.next() else {
        return nil
      }
      foundPattern = pattern.patternRecognized(after: char, iterator: self) == .yes
      return char
    }

    public func popScope() -> NSStringIterator {
      var popped = innerIterator
      popped.index = index
      return popped
    }
  }

  public struct EndingBeforeIterator: NSStringIterator {
    internal init(iterator: NSStringIterator, pattern: Pattern) {
      self.innerIterator = iterator
      self.pattern = pattern
    }

    private var innerIterator: NSStringIterator
    private var pattern: Pattern
    public var index: Int {
      get { innerIterator.index }
      set { innerIterator.index = newValue }
    }

    public mutating func rewind() -> Bool {
      return innerIterator.rewind()
    }

    public mutating func next() -> unichar? {
      var seekahead = innerIterator
      var patternFound = false
      while let char = seekahead.next() {
        let result = pattern.patternRecognized(after: char, iterator: self)
        if result == .yes {
          patternFound = true
          break
        } else if result == .no {
          break
        }
      }
      guard !patternFound, let char = innerIterator.next() else {
        return nil
      }
      return char
    }

    public func popScope() -> NSStringIterator {
      var popped = innerIterator
      popped.index = index
      return popped
    }
  }
}

extension NSStringIterator {
  public func pushScope(
    _ scopeType: NSStringIteratorScopeType,
    pattern: AnyPattern
  ) -> NSStringIterator {
    switch scopeType {
    case .endAfterPattern:
      return PieceTable.EndingAfterIterator(iterator: self, pattern: pattern.innerPattern)
    case .endBeforePattern:
      return PieceTable.EndingBeforeIterator(iterator: self, pattern: pattern.innerPattern)
    }
  }
}
