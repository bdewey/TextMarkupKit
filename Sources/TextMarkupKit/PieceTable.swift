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

/// A piece table in a range-replacable collection of UTF-16 values (unichar). Internally it uses two `NSStrings` to store these:
/// A read-only *originalContents* `NSString` and an append-only *newContents* `NSMutableString` that holds all added content.
///
/// The logical view of the modified string is built from a collection of `Run` structures, where a `Run` is a slice of unichar
/// values from one of the two storage strings.
public final class PieceTable: CustomStringConvertible {
  public init(_ string: String) {
    self.originalContents = Array(string.utf16)
    self.slices = [originalContents[0...]]
  }

  public init() {
    self.originalContents = []
    self.slices = [originalContents[0...]]
  }

  /// Holds all of the original, unedited contents of the buffer.
  private let originalContents: [unichar]

  /// Holds all new characters added to the buffer.
  private var newContents = [unichar]()

  private typealias SourceSlice = ArraySlice<unichar>

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

  public var eofRead = 0
  public var charactersRead = 0

  public func utf16(at index: Int) -> unichar? {
    return self[index]
  }

  /// Implementation of the core NSTextStorage method.
  public func replaceCharacters(in range: NSRange, with str: String) {
    let lowerBound = index(for: range.lowerBound)
    let upperBound = index(for: range.upperBound)
    replaceSubrange(lowerBound ..< upperBound, with: str.utf16)
  }

  public subscript(range: NSRange) -> String {
    let lowerBound = index(for: range.lowerBound)
    let upperBound = index(for: range.upperBound)
    return self[lowerBound ..< upperBound]
  }

  public subscript(bounds: Range<Index>) -> String {
    var results = [unichar]()
    for sliceIndex in bounds.lowerBound.sliceIndex ... bounds.upperBound.sliceIndex {
      let slice = slices[sliceIndex]
      let lowerBound = (sliceIndex == bounds.lowerBound.sliceIndex) ? bounds.lowerBound.contentIndex : slice.startIndex
      let upperBound = (sliceIndex == bounds.upperBound.sliceIndex) ? bounds.upperBound.contentIndex : slice.endIndex
      results.append(contentsOf: slice[lowerBound ..< upperBound])
    }
    return String(utf16CodeUnits: results, count: results.count)
  }

  public var description: String {
    let properties: [String: Any] = [
      "length": originalContents.count,
      "charactersRead": charactersRead,
      "eofRead": eofRead,
    ]
    return "PieceTable \(properties)"
  }
}

extension PieceTable: Collection {
  /// There are two kinds of index into the contents of a PieceTable. A `ContentIndex` treats the contents as a single array
  /// of `unichar` elements, so the indexes range from 0 to (count - 1) and you can do simple arithmetic to manipulate indexes.
  public typealias ContentIndex = Int

  /// Then there is the actual `Index`, which tells you specifically how to find a character within the two contents arrays.
  public struct Index: Comparable {
    /// The index of the slice in `slices`
    let sliceIndex: Int

    /// The index of a unichar within a specific slice.
    let contentIndex: Int

    public static func < (lhs: PieceTable.Index, rhs: PieceTable.Index) -> Bool {
      if lhs.sliceIndex != rhs.sliceIndex { return lhs.sliceIndex < rhs.sliceIndex }
      return lhs.contentIndex < rhs.contentIndex
    }
  }

  /// Given an `Index`, returns the corresponding `ContentIndex`.
  /// - note: O(N) in the size of `slices`
  public func contentIndex(for index: Index) -> ContentIndex {
    var sliceOffset: ContentIndex = 0
    for i in 0 ..< index.sliceIndex - 1 {
      sliceOffset += slices[i].count
    }
    return sliceOffset + (index.contentIndex - slices[index.sliceIndex].startIndex)
  }

  /// Given a `ContentIndex`, returns the corresponding `Index`
  /// - note: O(N) in the size of `slices`
  public func index(for contentIndex: ContentIndex) -> Index {
    var contentLength = 0
    for (index, slice) in slices.enumerated() {
      if contentLength + slice.count > contentIndex {
        return Index(sliceIndex: index, contentIndex: slice.startIndex + (contentIndex - contentLength))
      }
      contentLength += slice.count
    }
    return endIndex
  }

  /// The index of the first character of content.
  public var startIndex: Index {
    Index(sliceIndex: 0, contentIndex: slices.first?.startIndex ?? 0)
  }

  public var endIndex: Index {
    Index(sliceIndex: slices.count - 1, contentIndex: slices.last?.endIndex ?? 0)
  }

  public func index(after i: Index) -> Index {
    if i.contentIndex == slices[i.sliceIndex].endIndex - 1, i.sliceIndex < slices.count {
      return Index(sliceIndex: i.sliceIndex + 1, contentIndex: slices[i.sliceIndex + 1].startIndex)
    }
    return Index(sliceIndex: i.sliceIndex, contentIndex: i.contentIndex + 1)
  }

  public subscript(position: Index) -> unichar {
    return slices[position.sliceIndex][position.contentIndex]
  }

  /// For convenience reading contents with a parser, an accessor that accepts a contentIndex and returns nil when the index is
  /// out of bounds versus crashing.
  public subscript(contentIndex: ContentIndex) -> unichar? {
    let index = self.index(for: contentIndex)
    if index < endIndex {
      return self[index]
    } else {
      return nil
    }
  }
}

extension PieceTable: RangeReplaceableCollection {
  public func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C : Collection, R : RangeExpression, unichar == C.Element, Index == R.Bound {
    // TODO
    let range = subrange.relative(to: self)
    deleteRange(range)
    guard !newElements.isEmpty else { return }

    let index = newContents.endIndex
    newContents.append(contentsOf: newElements)
    slices.insert(newContents[index ..< newContents.endIndex], at: range.lowerBound.sliceIndex + 1)
  }

  private func deleteRange(_ range: Range<Index>) {
    if range.lowerBound.sliceIndex == range.upperBound.sliceIndex {
      // We're removing characters from *within* a slice. That means we need to *split* this
      // existing slice.

      let existingSlice = slices[range.lowerBound.sliceIndex]

      let lowerPart = existingSlice[existingSlice.startIndex ..< range.lowerBound.contentIndex]
      let upperPart = existingSlice[range.upperBound.contentIndex ..< existingSlice.endIndex]

      slices[range.lowerBound.sliceIndex] = lowerPart
      slices.insert(upperPart, at: range.lowerBound.sliceIndex + 1)
    } else {
      // We are removing things between two or more slices.
      slices.removeSubrange(range.lowerBound.sliceIndex + 1 ..< range.upperBound.sliceIndex)
      slices[range.lowerBound.sliceIndex].settingEndIndex(range.lowerBound.contentIndex)
      slices[range.lowerBound.sliceIndex + 1].settingStartIndex(range.upperBound.contentIndex)
    }
  }
}

extension ArraySlice {
  mutating func settingEndIndex(_ endIndex: Index) {
    self = self[startIndex ..< endIndex]
  }

  mutating func settingStartIndex(_ startIndex: Index) {
    self = self[startIndex ..< endIndex]
  }
}
