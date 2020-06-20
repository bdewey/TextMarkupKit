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
    self.pieces = [Piece(source: .original, startIndex: 0, endIndex: 0)]
  }

  /// Initialize a piece table with the contents of a string.
  public init(_ string: String) {
    self.originalContents = Array(string.utf16)
    self.pieces = [Piece(source: .original, startIndex: 0, endIndex: originalContents.count)]
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
  private struct Piece {
    let source: Source
    var startIndex: Int
    var endIndex: Int

    var count: Int { endIndex - startIndex }
    var isEmpty: Bool { startIndex == endIndex }
  }

  /// The logical contents of this buffer, expressed as a sequence of slices from either `originalContents` or `newContents`
  private var pieces = [Piece]()

  /// How many slices are in the piece table.
  public var sliceCount: Int { pieces.count }

  /// Return the receiver as a String.
  public var string: String {
    let chars = self[startIndex...]
    return String(utf16CodeUnits: chars, count: chars.count)
  }

  /// How many `unichar` elements are in the piece table.
  /// - note: O(N) in the number of slices.
  public var count: Int {
    pieces.reduce(0) {
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
    guard let position = self.index(startIndex, offsetBy: index, limitedBy: endIndex) else {
      return nil
    }
    if position < endIndex {
      return self[position]
    } else {
      return nil
    }
  }

  /// Implementation of the core NSTextStorage method: Replaces the characters in an NSRange of ContentIndexes with the
  /// UTF-16 characters from a string.
  public mutating func replaceCharacters(in range: NSRange, with str: String) {
    let lowerBound = index(startIndex, offsetBy: range.location)
    let upperBound = index(lowerBound, offsetBy: range.length)
    replaceSubrange(lowerBound ..< upperBound, with: str.utf16)
  }

  /// Gets the string from an NSRange of ContentIndexes.
  public subscript(range: NSRange) -> [unichar] {
    let lowerBound = index(startIndex, offsetBy: range.location)
    let upperBound = index(lowerBound, offsetBy: range.length)
    return self[lowerBound ..< upperBound]
  }

  /// Gets a substring of the PieceTable contents.
  public subscript<R: RangeExpression>(boundsExpression: R) -> [unichar] where R.Bound == Index {
    let bounds = boundsExpression.relative(to: self)
    guard !bounds.isEmpty else { return [] }
    let lowerSliceIndex = bounds.lowerBound.pieceIndex
    let upperSliceIndex = bounds.upperBound.pieceIndex
    var results = [unichar]()
    var sliceIndex = lowerSliceIndex
    repeat {
      let slice = pieces[sliceIndex]
      let lowerBound = (sliceIndex == lowerSliceIndex) ? bounds.lowerBound.contentIndex : slice.startIndex
      let upperBound = (sliceIndex == upperSliceIndex) ? bounds.upperBound.contentIndex : slice.endIndex
      results.append(contentsOf: sourceArray(for: slice.source)[lowerBound ..< upperBound])
      sliceIndex += 1
    } while sliceIndex < upperSliceIndex
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
  public struct Index: Comparable {
    let pieceIndex: Int
    let contentIndex: Int

    public static func < (lhs: PieceTable.Index, rhs: PieceTable.Index) -> Bool {
      if lhs.pieceIndex != rhs.pieceIndex {
        return lhs.pieceIndex < rhs.pieceIndex
      }
      return lhs.contentIndex < rhs.contentIndex
    }
  }

  public var startIndex: Index { Index(pieceIndex: 0, contentIndex: pieces.first?.startIndex ?? 0) }
  public var endIndex: Index { Index(pieceIndex: pieces.endIndex, contentIndex: 0) }

  public func index(after i: Index) -> Index {
    let piece = pieces[i.pieceIndex]
    if i.contentIndex + 1 < piece.endIndex {
      return Index(pieceIndex: i.pieceIndex, contentIndex: i.contentIndex + 1)
    }
    let nextPieceIndex = i.pieceIndex + 1
    if nextPieceIndex < pieces.endIndex {
      return Index(pieceIndex: nextPieceIndex, contentIndex: pieces[nextPieceIndex].startIndex)
    } else {
      return Index(pieceIndex: nextPieceIndex, contentIndex: 0)
    }
  }

//  public func index(_ i: Index, offsetBy distance: Int) -> Index {
//    return index(i, offsetBy: distance, limitedBy: endIndex)!
//  }
//
//  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
//    var distance = distance
//    var contentIndex = i.contentIndex
//    for sliceIndex in i.pieceIndex ..< pieces.endIndex {
//      let slice = pieces[sliceIndex]
//      let charactersInSlice = sliceIndex == limit.pieceIndex
//        ? limit.contentIndex - contentIndex
//        : slice.endIndex - contentIndex
//      if distance < charactersInSlice {
//        return Index(pieceIndex: sliceIndex, contentIndex: contentIndex + distance)
//      }
//      if sliceIndex + 1 == pieces.endIndex {
//        contentIndex = 0
//      } else {
//        contentIndex = pieces[sliceIndex + 1].startIndex
//      }
//      distance -= charactersInSlice
//    }
//    if distance == 0 {
//      return limit
//    } else {
//      return nil
//    }
//  }
//
//  public func distance(from start: Index, to end: Index) -> Int {
//    var distance = 0
//    var contentIndex = start.contentIndex
//    for sliceIndex in start.pieceIndex ..< pieces.endIndex {
//      let slice = pieces[sliceIndex]
//      if end.pieceIndex == sliceIndex {
//        return distance + (end.contentIndex - contentIndex)
//      }
//      distance += (slice.endIndex - contentIndex)
//      contentIndex = pieces[sliceIndex + 1].startIndex
//    }
//    preconditionFailure()
//  }
//
  public subscript(position: Index) -> unichar {
    let sourceArray = self.sourceArray(for: pieces[position.pieceIndex].source)
    return sourceArray[position.contentIndex]
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
  ) where C: Collection, R: RangeExpression, unichar == C.Element, Index == R.Bound {
    let range = subrange.relative(to: self)
    let insertionPoint = deleteRange(range)
    guard !newElements.isEmpty else { return }

    let index = addedContents.endIndex
    addedContents.append(contentsOf: newElements)
    if pieces.isEmpty {
      pieces.append(Piece(source: .added, startIndex: index, endIndex: addedContents.endIndex))
    } else {
      if insertionPoint > 0, pieces[insertionPoint - 1].source == .added, pieces[insertionPoint - 1].endIndex == index {
        pieces[insertionPoint - 1].endIndex = addedContents.endIndex
      } else {
        let newSlice = Piece(source: .added, startIndex: index, endIndex: addedContents.endIndex)
        pieces.insert(newSlice, at: insertionPoint)
      }
    }
  }

  /// Deletes a range of contents from the piece table.
  /// Remember that we never actually remove the characters; all this will do is update `slices` so we no longer say the given
  /// range of content is part of our collection.
  /// - returns: The index of the insertion point in `slices` of a new slice that would replace the contents of `range`
  private mutating func deleteRange(_ range: Range<Index>) -> Int {
    if range.lowerBound.pieceIndex == pieces.endIndex { return pieces.endIndex }
    if range.lowerBound.pieceIndex == range.upperBound.pieceIndex {
      // We're removing characters from *within* a slice. That means we need to *split* this
      // existing slice.

      let existingSlice = pieces[range.lowerBound.pieceIndex]

      let lowerPart = Piece(source: existingSlice.source, startIndex: existingSlice.startIndex, endIndex: range.lowerBound.contentIndex)
      let upperPart = Piece(source: existingSlice.source, startIndex: range.upperBound.contentIndex, endIndex: existingSlice.endIndex)

      if !lowerPart.isEmpty {
        pieces[range.lowerBound.pieceIndex] = lowerPart
        if !upperPart.isEmpty {
          pieces.insert(upperPart, at: range.lowerBound.pieceIndex + 1)
          return range.lowerBound.pieceIndex + 1
        }
      } else if !upperPart.isEmpty {
        // lower empty, upper isn't
        pieces[range.lowerBound.pieceIndex] = upperPart
      } else {
        // we deleted a whole slice, nothing left!
        pieces.remove(at: range.lowerBound.pieceIndex)
      }
      return range.lowerBound.pieceIndex
    } else {
      // We are removing things between two or more slices.
      pieces.removeSubrange(range.lowerBound.pieceIndex + 1 ..< range.upperBound.pieceIndex)
      pieces[range.lowerBound.pieceIndex].endIndex = range.lowerBound.contentIndex

      // lowerBound might be the end of the array.
      if range.lowerBound.pieceIndex + 1 < pieces.endIndex {
        pieces[range.lowerBound.pieceIndex + 1].startIndex = range.upperBound.contentIndex
        if pieces[range.lowerBound.pieceIndex + 1].isEmpty {
          pieces.remove(at: range.lowerBound.pieceIndex + 1)
        }
      }

      if pieces[range.lowerBound.pieceIndex].isEmpty {
        pieces.remove(at: range.lowerBound.pieceIndex)
        return range.lowerBound.pieceIndex
      }
      return range.lowerBound.pieceIndex + 1
    }
  }
}
