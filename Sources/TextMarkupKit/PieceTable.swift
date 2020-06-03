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

/// A piece table in a range-replacable collection of UTF-16 values (unichar). Internally it uses two arrays to store these:
/// A read-only *originalContents* array and an append-only *newContents* array that holds all added content.
///
/// The logical view of the modified string is built from an array of slices from the two arrays.
public struct PieceTable: CustomStringConvertible, RangeReplaceableSafeUnicodeBuffer {
  /// Initialize an empty piece table.
  public init() {
    self.originalContents = []
    self.slices = [SourceSlice(source: .original, startIndex: 0, endIndex: 0)]
  }

  /// Initialize a piece table with the contents of a string.
  public init(_ string: String) {
    self.originalContents = Array(string.utf16)
    self.slices = [SourceSlice(source: .original, startIndex: 0, endIndex: originalContents.count)]
  }

  /// Holds all of the original, unedited contents of the buffer.
  private let originalContents: [unichar]

  /// Holds all new characters added to the buffer.
  private var addedContents = [unichar]()

  /// Identifies which of the two arrays holds a slice of characters.
  private enum Source {
    case original
    case added
  }

  /// Gets the array for a source.
  private func sourceArray(for source: Source) -> [unichar] {
    switch source {
    case .original:
      return originalContents
    case .added:
      return addedContents
    }
  }

  /// A slice of one of the storage arrays.
  private struct SourceSlice {
    let source: Source
    var startIndex: Int
    var endIndex: Int

    var count: Int { endIndex - startIndex }
    var isEmpty: Bool { startIndex == endIndex }
  }

  /// The logical contents of this buffer, expressed as a sequence of slices from either `originalContents` or `newContents`
  private var slices = [SourceSlice]()

  /// How many slices are in the piece table.
  public var sliceCount: Int { slices.count }

  /// Return the receiver as a String.
  public var string: String {
    let chars = self[startIndex...]
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  /// How many `unichar` elements are in the piece table.
  /// - note: O(N) in the number of slices.
  public var count: Int {
    slices.reduce(0) {
      $0 + $1.count
    }
  }

  // MARK: Performance counters

  /// How many times someone read past last valid character
  public var eofRead = 0

  /// How many times someone read any content at all.
  public var charactersRead = 0

  /// Returns the unichar at a specific ContentIndex, or nil if index is past valid content.
  public func utf16(at index: Int) -> unichar? {
    if index < endIndex {
      return self[index]
    } else {
      return nil
    }
  }

  /// Implementation of the core NSTextStorage method: Replaces the characters in an NSRange of ContentIndexes with the
  /// UTF-16 characters from a string.
  public mutating func replaceCharacters(in range: NSRange, with str: String) {
    replaceSubrange(range.lowerBound ..< range.upperBound, with: str.utf16)
  }

  /// Gets the string from an NSRange of ContentIndexes.
  public subscript(range: NSRange) -> [unichar] {
    return self[range.lowerBound ..< range.upperBound]
  }

  /// Gets a substring of the PieceTable contents.
  public subscript<R: RangeExpression>(boundsExpression: R) -> [unichar] where R.Bound == Int {
    let bounds = boundsExpression.relative(to: self)
    guard bounds.upperBound > 0 else { return [] }
    let (lowerSliceIndex, lowerStartBefore) = sliceIndex(for: bounds.lowerBound)
    let (upperSliceIndex, upperCountBefore) = sliceIndex(for: bounds.upperBound - 1)
    var results = [unichar]()
    for sliceIndex in lowerSliceIndex ... upperSliceIndex {
      let slice = slices[sliceIndex]
      let lowerBound = (sliceIndex == lowerSliceIndex) ? slice.startIndex + bounds.lowerBound - lowerStartBefore : slice.startIndex
      let upperBound = (sliceIndex == upperSliceIndex) ? slice.startIndex + bounds.upperBound - upperCountBefore : slice.endIndex
      results.append(contentsOf: sourceArray(for: slice.source)[lowerBound ..< upperBound])
    }
    return results
  }

  public var description: String {
    let properties: [String: Any] = [
      "count": count,
      "charactersRead": charactersRead,
      "eofRead": eofRead,
    ]
    return "PieceTable \(properties)"
  }
}

extension PieceTable: Collection {
  /// Identifies a location of a character as its location in the `slices` array (to find the appropriate source) and the index within
  /// that source.
  ///
  /// We index into the slices array instead of just remembering the source so we can reason about what comes next...?
  private struct SourceIndex {
    /// Which source array to use
    let source: Source

    /// The index of a unichar within a specific slice.
    let contentIndex: Int
  }

  /// Given a `ContentIndex`, returns the corresponding `Index`
  /// - note: O(N) in the size of `slices`
  private func sourceIndex(for contentIndex: Int) -> SourceIndex {
    let (sliceIndex, contentLength) = self.sliceIndex(for: contentIndex)
    if sliceIndex < slices.endIndex {
      let slice = slices[sliceIndex]
      return SourceIndex(source: slice.source, contentIndex: slice.startIndex + (contentIndex - contentLength))
    } else {
      // TODO: This is wrong!
      return SourceIndex(source: .original, contentIndex: 0)
    }
  }

  /// The index into `slices` of the slice that contains `contentIndex` as well as how many characters come before that slice.
  /// - note: O(N) in the size of `slices`
  private func sliceIndex(for contentIndex: Int) -> (sliceIndex: Int, countBeforeSlice: Int) {
    var countBeforeSlice = 0
    for (index, slice) in slices.enumerated() {
      if countBeforeSlice + slice.count > contentIndex {
        return (index, countBeforeSlice)
      }
      countBeforeSlice += slice.count
    }
    return (slices.endIndex, countBeforeSlice)
  }

  public var startIndex: Int { 0 }
  public var endIndex: Int { count }
  public func index(after i: Int) -> Int { i + 1 }

  private subscript(position: SourceIndex) -> unichar {
    let sourceArray = self.sourceArray(for: position.source)
    return sourceArray[position.contentIndex]
  }

  /// For convenience reading contents with a parser, an accessor that accepts a contentIndex and returns nil when the index is
  /// out of bounds versus crashing.
  public subscript(contentIndex: Int) -> unichar {
    let index = sourceIndex(for: contentIndex)
    return self[index]
  }
}

extension PieceTable: RangeReplaceableCollection {
  /// Replace a range of characters with `newElements`. Note that `subrange` can be empty (in which case it's just an insert point).
  /// Similarly `newElements` can be empty (expressing deletion).
  ///
  /// Also remember that characters are never really deleted.
  public mutating func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C: Collection, R: RangeExpression, unichar == C.Element, Int == R.Bound {
    let range = subrange.relative(to: self)
    deleteRange(range)
    guard !newElements.isEmpty else { return }

    let index = addedContents.endIndex
    addedContents.append(contentsOf: newElements)
    if slices.isEmpty {
      slices.append(SourceSlice(source: .added, startIndex: index, endIndex: addedContents.endIndex))
    } else {
      let (sliceIndex, _) = self.sliceIndex(for: range.lowerBound)
      if sliceIndex > 0, slices[sliceIndex - 1].source == .added, slices[sliceIndex - 1].endIndex == index {
        slices[sliceIndex - 1].endIndex = addedContents.endIndex
      } else {
        let newSlice = SourceSlice(source: .added, startIndex: index, endIndex: addedContents.endIndex)
        slices.insert(newSlice, at: sliceIndex)
      }
    }
  }

  /// Deletes a range of contents from the piece table.
  /// Remember that we never actually remove the characters; all this will do is update `slices` so we no longer say the given
  /// range of content is part of our collection.
  /// - returns: The index of the SourceSlice where characters can be inserted if the intent was to replace this range.
  private mutating func deleteRange(_ range: Range<Int>) {
    let (lowerBound, lowerCountBefore) = sliceIndex(for: range.lowerBound)
    let (upperBound, upperCountBefore) = sliceIndex(for: range.upperBound)

    if lowerBound == slices.endIndex { return }
    if lowerBound == upperBound {
      // We're removing characters from *within* a slice. That means we need to *split* this
      // existing slice.

      let existingSlice = slices[lowerBound]

      let lowerPart = SourceSlice(source: existingSlice.source, startIndex: existingSlice.startIndex, endIndex: existingSlice.startIndex + (range.lowerBound - lowerCountBefore))
      let upperPart = SourceSlice(source: existingSlice.source, startIndex: existingSlice.startIndex + (range.upperBound - lowerCountBefore), endIndex: existingSlice.endIndex)

      if !lowerPart.isEmpty {
        slices[lowerBound] = lowerPart
        if !upperPart.isEmpty {
          slices.insert(upperPart, at: lowerBound + 1)
        }
      } else if !upperPart.isEmpty {
        // lower empty, upper isn't
        slices[lowerBound] = upperPart
      } else {
        // we deleted a whole slice, nothing left!
        slices.remove(at: lowerBound)
      }
    } else {
      // We are removing things between two or more slices.
      slices.removeSubrange(lowerBound + 1 ..< upperBound)
      slices[lowerBound].endIndex = slices[lowerBound].startIndex + range.lowerBound - lowerCountBefore

      // lowerBound might be the end of the array.
      if lowerBound + 1 < slices.endIndex {
        slices[lowerBound + 1].startIndex = slices[lowerBound + 1].startIndex + range.upperBound - upperCountBefore
        if slices[lowerBound + 1].isEmpty {
          slices.remove(at: lowerBound + 1)
        }
      }

      if slices[lowerBound].isEmpty {
        slices.remove(at: lowerBound)
      }
    }
  }
}
