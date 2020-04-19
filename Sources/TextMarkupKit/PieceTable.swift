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
public final class PieceTable: CustomStringConvertible {
  public init(_ string: String) {
    self.originalContents = string as NSString
    self.runs = RunCollection(originalLength: originalContents.length)
  }

  /// Holds all of the original, unedited contents of the buffer.
  private let originalContents: NSString

  /// Holds all new characters added to the buffer.
  private let newContents = NSMutableString()

  /// The logical contents of this buffer, expressed as a sequence of runs from either `originalContents` or `newContents`
  private var runs: RunCollection

  public var startIndex: Int { 0 }
  public var endIndex: Int {
    return runs.length
  }

  public var length: Int {
    runs.length
  }

  /// Return the receiver as a String.
  public var string: String {
    runs.map { string(for: $0) }.joined()
  }

  public var eofRead = 0
  public var charactersRead = 0

  public func utf16(at index: Int) -> unichar? {
    guard index < originalContents.length else {
      eofRead += 1
      return nil
    }
    charactersRead += 1
    return originalContents.character(at: index)
  }

  public func replaceCharacters(in range: NSRange, with str: String) {
    assert(range.upperBound <= endIndex)
    let newRange: NSRange?
    if !str.isEmpty {
      newRange = appendString(str)
    } else {
      newRange = nil
    }
    runs.replaceRange(range, with: newRange)
  }

  private func appendString(_ str: String) -> NSRange {
    let location = newContents.length
    newContents.append(str)
    return NSRange(location: location, length: str.utf16.count)
  }

  public subscript(range: Range<Int>) -> String {
    let stringIndexRange = NSRange(location: range.lowerBound, length: range.count)
    return originalContents.substring(with: stringIndexRange) as String
  }

  public var description: String {
    let properties: [String: Any] = [
      "length": originalContents.length,
      "charactersRead": charactersRead,
      "eofRead": eofRead,
    ]
    return "PieceTable \(properties)"
  }
}

// MARK: - Private

private extension PieceTable {
  enum Source {
    case original
    case new
  }

  /// A contiguous range of characters from either `originalContents` or `newContents`.
  struct Run {
    let source: Source
    var range: NSRange
  }

  func string(for run: Run) -> String {
    switch run.source {
    case .original:
      return originalContents.substring(with: run.range)
    case .new:
      return newContents.substring(with: run.range)
    }
  }

  struct RunCollection: Collection {
    init(originalLength: Int) {
      self.runs = [Run(source: .original, range: NSRange(location: 0, length: originalLength))]
    }

    private var runs: [Run]

    var length: Int {
      runs.reduce(0) { $0 + $1.range.length }
    }

    mutating func replaceRange(_ existingRange: NSRange, with newRange: NSRange?) {
      let cutpoint = deleteRange(existingRange)
      if let newRange = newRange {
        let run = Run(source: .new, range: newRange)
        runs.insert(run, at: cutpoint)
      }
    }

    private mutating func deleteRange(_ existingRange: NSRange) -> Int {
      let findResult = findRange(existingRange)
      var endingRun = runs[findResult.end.index]
      endingRun.range.location += (existingRange.upperBound - findResult.end.contentOffset)
      endingRun.range.length -= (existingRange.upperBound - findResult.end.contentOffset)
      runs[findResult.start.index].range.length = (existingRange.lowerBound - findResult.start.contentOffset)
      let runsToDelete = findResult.end.index - findResult.start.index - 1
      if runsToDelete < 0 {
        runs.insert(endingRun, at: findResult.start.index + 1)
      } else {
        runs.removeSubrange(findResult.start.index + 1 ..< findResult.end.index)
        runs[findResult.start.index + 1] = endingRun
      }
      return findResult.start.index + 1
    }

    private func findRange(_ range: NSRange) -> FindRangeResult {
      var result = FindRangeResult()
      var contentOffset = 0
      var foundStart = false
      for (i, run) in runs.enumerated() {
        if !foundStart, contentOffset + run.range.length > range.location {
          result.start = RunInfo(index: i, contentOffset: contentOffset)
          foundStart = true
        }
        if contentOffset + run.range.length >= range.upperBound {
          result.end = RunInfo(index: i, contentOffset: contentOffset)
          return result
        }
        contentOffset += run.range.length
      }
      assertionFailure()
      return result
    }

    var startIndex: Int { return 0 }
    var endIndex: Int { return runs.count }
    func index(after i: Int) -> Int {
      return i + 1
    }

    subscript(position: Int) -> Run {
      runs[position]
    }

    struct RunInfo {
      /// The index of a run
      var index: Int = 0

      /// The starting content offset of this run.
      var contentOffset: Int = 0
    }

    struct FindRangeResult {
      var start = RunInfo()
      var end = RunInfo()
    }
  }
}
