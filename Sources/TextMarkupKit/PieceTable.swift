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

  public subscript(range: Range<Int>) -> [unichar] {
    guard let stringIndexRange = NSRange(location: range.lowerBound, length: range.count).intersection(NSRange(location: 0, length: string.length)) else {
      return []
    }
    var chars = Array<unichar>(repeating: 0, count: stringIndexRange.length)
    string.getCharacters(&chars, range: stringIndexRange)
    return chars
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

public protocol NSStringIterator: CustomDebugStringConvertible {
  var index: Int { get set }
  @discardableResult mutating func rewind() -> Bool
  mutating func next() -> unichar?
//  func pushScope(_ scopeType: NSStringIteratorScopeType, pattern: AnyPattern) -> NSStringIterator
//  func popScope() -> NSStringIterator
  mutating func pushingScope(_ scope: Scope)
  mutating func poppingScope()
  func index(afterPrefix pattern: Pattern) -> Int?
}

public struct Scope {
  let endBeforePattern: Bool
  var pattern: Pattern
  var terminationIndex: Int?

  public static func endingBeforePattern(_ pattern: AnyPattern) -> Scope {
    return Scope(endBeforePattern: true, pattern: pattern.innerPattern)
  }

  public static func endingAfterPattern(_ pattern: AnyPattern) -> Scope {
    return Scope(endBeforePattern: false, pattern: pattern.innerPattern)
  }

  func validIndex(_ index: Int) -> Bool {
    guard let terminationIndex = terminationIndex else {
      return true
    }
    return index < terminationIndex
  }

  mutating func needsMoreInputToFindPattern(char: unichar?, index: Int) -> Bool {
    guard terminationIndex == nil, let char = char else {
      return false
    }
    switch pattern.patternRecognized(after: char) {
    case let .foundPattern(patternLength: patternLength, patternStart: patternStart):
      terminationIndex = endBeforePattern ? index - patternStart : index - patternStart + patternLength
      return false
    case .needsMoreInput:
      return false
    case .no:
      return true
    }
  }
}

extension PieceTable {
  public struct Iterator: NSStringIterator, IteratorProtocol {
    internal init(index: Int, string: PieceTable) {
      self.index = index
      self.string = string
    }

    public var index: Int
    private let string: PieceTable
    private var buffer = [unichar]()
    private var bufferStartIndex = 0

    private var scopes: [Scope] = []

    public mutating func rewind() -> Bool {
      if index > 0 {
        index -= 1
        return true
      }
      return false
    }

    public mutating func next() -> unichar? {
      guard index < string.length, scopes.allSatisfy({ $0.validIndex(index) }) else {
        return nil
      }
      let char = getCharFromBuffer(at: index)
      for scopeIndex in scopes.indices {
        var innerIndex = index
        var innerChar = char
        while scopes[scopeIndex].needsMoreInputToFindPattern(char: innerChar, index: innerIndex) {
          innerIndex += 1
          innerChar = getCharFromBuffer(at: innerIndex)
        }
      }
      if scopes.allSatisfy({ $0.validIndex(index) }) {
        index += 1
        return char
      } else {
        return nil
      }
    }

    private mutating func getCharFromBuffer(at index: Int) -> unichar? {
      let char: unichar?
      let bufferIndex = index - bufferStartIndex
      if buffer.indices.contains(bufferIndex) {
        char = buffer[bufferIndex]
      } else {
        buffer = string[index ..< index + 4096]
        bufferStartIndex = index
        char = buffer.first
      }
      return char
    }

    public mutating func pushingScope(_ scope: Scope) {
      scopes.append(scope)
    }

    public mutating func poppingScope() {
      scopes.removeLast()
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
    private var patternEndIndex: Int?
    public var index: Int {
      get { innerIterator.index }
      set { innerIterator.index = newValue }
    }

    public mutating func rewind() -> Bool {
      return innerIterator.rewind()
    }

    public mutating func next() -> unichar? {
      guard !atEndOfPattern, let char = innerIterator.next() else {
        return nil
      }
      if patternEndIndex == nil {
        switch pattern.patternRecognized(after: char) {
        case let .foundPattern(patternLength: patternLength, patternStart: patternStart):
          assert(patternLength == patternStart)
          patternEndIndex = innerIterator.index
        case .needsMoreInput:
          patternEndIndex = innerIterator.index(afterPrefix: pattern)
        case .no:
          break
        }
      }
      return char
    }

    private var atEndOfPattern: Bool {
      guard let patternEndIndex = patternEndIndex else {
        return false
      }
      return index >= patternEndIndex
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
      guard let char = innerIterator.next() else {
        return nil
      }
      let patternFound: Bool
      switch pattern.patternRecognized(after: char) {
      case .foundPattern:
        patternFound = true
      case .no:
        patternFound = false
      case .needsMoreInput:
        patternFound = innerIterator.index(afterPrefix: pattern) != nil
      }
      if patternFound {
        _ = rewind()
        return nil
      } else {
        return char
      }
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

  public func index(afterPrefix pattern: Pattern) -> Int? {
    var pattern = pattern
    var iterator = self
    while let char = iterator.next() {
      switch pattern.patternRecognized(after: char) {
      case .no:
        return nil
      case .needsMoreInput:
        continue
      case let .foundPattern(patternLength: patternLength, patternStart: patternStart):
        return iterator.index - patternStart + patternLength
      }
    }
    return nil
  }

  public var debugDescription: String {
    var copy = self
    var chars = [unichar]()
    while let char = copy.next() {
      chars.append(char)
    }
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  public mutating func pushingScope(_ scope: Scope) {
    assertionFailure()
  }

  public mutating func poppingScope() {
    assertionFailure()
  }
}
