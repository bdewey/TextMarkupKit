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

  private enum Source {
    case original
    case added
  }

  private func sourceArray(for source: Source) -> [unichar] {
    switch source {
    case .original:
      return originalContents
    case .added:
      return addedContents
    }
  }

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
    self[sliceIndex(for: startIndex) ..< sliceIndex(for: endIndex)]
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
    let lowerBound = sliceIndex(for: range.lowerBound)
    let upperBound = sliceIndex(for: range.upperBound)
    return self[lowerBound ..< upperBound]
  }

  /// Gets a substring of the PieceTable contents.
  private subscript(bounds: Range<SliceIndex>) -> String {
    var results = [unichar]()
    for sliceIndex in bounds.lowerBound.sliceIndex ... bounds.upperBound.sliceIndex {
      let slice = slices[sliceIndex]
      let lowerBound = (sliceIndex == bounds.lowerBound.sliceIndex) ? bounds.lowerBound.contentIndex : slice.startIndex
      let upperBound = (sliceIndex == bounds.upperBound.sliceIndex) ? bounds.upperBound.contentIndex : slice.endIndex
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

  private struct SliceIndex: Comparable {
    /// The index of the slice in `slices`
    let sliceIndex: Int

    /// The index of a unichar within a specific slice.
    let contentIndex: Int

    public static func < (lhs: SliceIndex, rhs: SliceIndex) -> Bool {
      if lhs.sliceIndex != rhs.sliceIndex { return lhs.sliceIndex < rhs.sliceIndex }
      return lhs.contentIndex < rhs.contentIndex
    }
  }

  /// Given an `Index`, returns the corresponding `ContentIndex`.
  /// - note: O(N) in the size of `slices`
  private func contentIndex(for index: SliceIndex) -> Int {
    var sliceOffset: Int = 0
    for i in 0 ..< index.sliceIndex - 1 {
      sliceOffset += slices[i].count
    }
    return sliceOffset + (index.contentIndex - slices[index.sliceIndex].startIndex)
  }

  /// Given a `ContentIndex`, returns the corresponding `Index`
  /// - note: O(N) in the size of `slices`
  private func sliceIndex(for contentIndex: Int) -> SliceIndex {
    var contentLength = 0
    for (index, slice) in slices.enumerated() {
      if contentLength + slice.count > contentIndex {
        return SliceIndex(sliceIndex: index, contentIndex: slice.startIndex + (contentIndex - contentLength))
      }
      contentLength += slice.count
    }
    return SliceIndex(sliceIndex: slices.count - 1, contentIndex: slices.last?.endIndex ?? 0)
  }

  public var startIndex: Int { 0 }
  public var endIndex: Int { count }
  public func index(after i: Int) -> Int { i + 1 }

  private subscript(position: SliceIndex) -> unichar {
    let sourceArray = self.sourceArray(for: slices[position.sliceIndex].source)
    return sourceArray[position.contentIndex]
  }

  /// For convenience reading contents with a parser, an accessor that accepts a contentIndex and returns nil when the index is
  /// out of bounds versus crashing.
  public subscript(contentIndex: Int) -> unichar {
    let index = self.sliceIndex(for: contentIndex)
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
      let insertionPoint = sliceIndex(for: range.lowerBound)
      let existingSlice = slices[insertionPoint.sliceIndex]
      if insertionPoint.contentIndex == existingSlice.endIndex, existingSlice.source == .added, existingSlice.endIndex == index {
        // The insertion point is at the end of an added slice, and the end of that slice is the beginning of the content we added...
        // Just update the end index.
        slices[insertionPoint.sliceIndex].endIndex = addedContents.endIndex
      } else if insertionPoint.contentIndex == existingSlice.startIndex, insertionPoint.sliceIndex > 0, slices[insertionPoint.sliceIndex - 1].endIndex == index, slices[insertionPoint.sliceIndex - 1].source == .added {
        // Same deal but with the previous slice.
        slices[insertionPoint.sliceIndex - 1].endIndex = addedContents.endIndex
      } else {
        let newSlice = SourceSlice(source: .added, startIndex: index, endIndex: addedContents.endIndex)
        let sliceIndexForInsertion = insertionPoint.contentIndex == existingSlice.startIndex ? insertionPoint.sliceIndex : insertionPoint.sliceIndex + 1
        slices.insert(newSlice, at: sliceIndexForInsertion)
      }
    }
  }

  /// Deletes a range of contents from the piece table.
  /// Remember that we never actually remove the characters; all this will do is update `slices` so we no longer say the given
  /// range of content is part of our collection.
  /// - returns: The index of the SourceSlice where characters can be inserted if the intent was to replace this range.
  private func deleteRange(_ range: Range<Int>) {
    let lowerBound = sliceIndex(for: range.lowerBound)
    let upperBound = sliceIndex(for: range.upperBound)
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
