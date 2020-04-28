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
public final class PieceTable: CustomStringConvertible {
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

  /// Return the receiver as a String.
  public var string: String {
    self[startIndex ..< endIndex]
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
  public func replaceCharacters(in range: NSRange, with str: String) {
    replaceSubrange(range.lowerBound ..< range.upperBound, with: str.utf16)
  }

  /// Gets the string from an NSRange of ContentIndexes.
  public subscript(range: NSRange) -> String {
    return self[range.lowerBound ..< range.upperBound]
  }

  /// Gets a substring of the PieceTable contents.
  private subscript(bounds: Range<Int>) -> String {
    guard bounds.upperBound > 0 else { return "" }
    let (lowerSliceIndex, lowerStartBefore) = self.sliceIndex(for: bounds.lowerBound)
    let (upperSliceIndex, upperCountBefore) = self.sliceIndex(for: bounds.upperBound - 1)
    var results = [unichar]()
    for sliceIndex in lowerSliceIndex ... upperSliceIndex {
      let slice = slices[sliceIndex]
      let lowerBound = (sliceIndex == lowerSliceIndex) ? slice.startIndex + bounds.lowerBound - lowerStartBefore : slice.startIndex
      let upperBound = (sliceIndex == upperSliceIndex) ? slice.startIndex + bounds.upperBound - upperCountBefore : slice.endIndex
      results.append(contentsOf: sourceArray(for: slice.source)[lowerBound ..< upperBound])
    }
    return String(utf16CodeUnits: results, count: results.count)
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
  private struct SourceIndex: Comparable {
    /// The index of the slice in `slices`
    let sliceIndex: Int

    /// The index of a unichar within a specific slice.
    let contentIndex: Int

    public static func < (lhs: SourceIndex, rhs: SourceIndex) -> Bool {
      if lhs.sliceIndex != rhs.sliceIndex { return lhs.sliceIndex < rhs.sliceIndex }
      return lhs.contentIndex < rhs.contentIndex
    }
  }

  /// Given a `ContentIndex`, returns the corresponding `Index`
  /// - note: O(N) in the size of `slices`
  private func sourceIndex(for contentIndex: Int) -> SourceIndex {
    let (sliceIndex, contentLength) = self.sliceIndex(for: contentIndex)
    if sliceIndex < slices.endIndex {
      let slice = slices[sliceIndex]
      return SourceIndex(sliceIndex: sliceIndex, contentIndex: slice.startIndex + (contentIndex - contentLength))
    } else {
      return SourceIndex(sliceIndex: sliceIndex, contentIndex: 0)
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
    let sourceArray = self.sourceArray(for: slices[position.sliceIndex].source)
    return sourceArray[position.contentIndex]
  }

  /// For convenience reading contents with a parser, an accessor that accepts a contentIndex and returns nil when the index is
  /// out of bounds versus crashing.
  public subscript(contentIndex: Int) -> unichar {
    let index = self.sourceIndex(for: contentIndex)
    return self[index]
  }
}

extension PieceTable: RangeReplaceableCollection {
  /// Replace a range of characters with `newElements`. Note that `subrange` can be empty (in which case it's just an insert point).
  /// Similarly `newElements` can be empty (expressing deletion).
  ///
  /// Also remember that characters are never really deleted.
  public func replaceSubrange<C, R>(
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
  private func deleteRange(_ range: Range<Int>) {
    let lowerBound = sourceIndex(for: range.lowerBound)
    let upperBound = sourceIndex(for: range.upperBound)

    if lowerBound.sliceIndex == slices.endIndex { return }
    if lowerBound.sliceIndex == upperBound.sliceIndex {
      // We're removing characters from *within* a slice. That means we need to *split* this
      // existing slice.

      let existingSlice = slices[lowerBound.sliceIndex]

      let lowerPart = SourceSlice(source: existingSlice.source, startIndex: existingSlice.startIndex, endIndex: lowerBound.contentIndex)
      let upperPart = SourceSlice(source: existingSlice.source, startIndex: upperBound.contentIndex, endIndex: existingSlice.endIndex)

      if !lowerPart.isEmpty {
        slices[lowerBound.sliceIndex] = lowerPart
        if !upperPart.isEmpty {
          slices.insert(upperPart, at: lowerBound.sliceIndex + 1)
        }
      } else if !upperPart.isEmpty {
        // lower empty, upper isn't
        slices[lowerBound.sliceIndex] = upperPart
      } else {
        // we deleted a whole slice, nothing left!
        slices.remove(at: lowerBound.sliceIndex)
      }
    } else {
      // We are removing things between two or more slices.
      slices.removeSubrange(lowerBound.sliceIndex + 1 ..< upperBound.sliceIndex)
      slices[lowerBound.sliceIndex].endIndex = lowerBound.contentIndex
      slices[lowerBound.sliceIndex + 1].startIndex = upperBound.contentIndex

      if slices[lowerBound.sliceIndex + 1].isEmpty {
        slices.remove(at: lowerBound.sliceIndex + 1)
      }
      if slices[lowerBound.sliceIndex].isEmpty {
        slices.remove(at: lowerBound.sliceIndex)
      }
    }
  }
}
