// Copyright (c) 2018-2021  Brian Dewey. Covered by the Apache 2.0 license.

// swiftlint:disable file_length

import Foundation

public extension Range where Range.Bound == PieceTable.Index {
  /// A constructor equivalent to Range(_: NSRange, in: String) for PieceTable use.
  init?(_ range: NSRange, in pieceTable: PieceTable) {
    let startIndex = pieceTable.index(pieceTable.startIndex, offsetBy: range.location)
    let endIndex = pieceTable.index(startIndex, offsetBy: range.length)
    self = startIndex ..< endIndex
  }
}

public extension NSRange {
  init<R: RangeExpression>(_ rangeExpression: R, in pieceTable: PieceTable) where R.Bound == PieceTable.Index {
    let range = rangeExpression.relative(to: pieceTable)
    let lowerBound = pieceTable.offset(for: range.lowerBound)
    let upperBound = pieceTable.offset(for: range.upperBound)
    self.init(location: lowerBound, length: upperBound - lowerBound)
  }
}

/// An efficient implementation of a range-replaceable collection of UTF-16 values.
///
/// A piece table is a range-replaceable collection of UTF-16 values. At the storage layer, it uses two arrays to store the values:
///
/// 1. Read-only *original contents*
/// 2. Append-only *addedContents*
///
/// It constructs a logical view of the contents from an array of slices of contents from the two arrays.
///
/// ## Topics
/// ### Indexing into a PieceTable
/// - ``findBound(_:forOriginalBound:)``
/// - ``findOriginalBound(_:forBound:)``
public struct PieceTable {
  /// The original, unedited contents
  private let originalContents: NSString

  /// All new characters added to the collection.
  private var addedContents: NSMutableString

  /// Identifies which of the two arrays holds the contents of the piece
  private enum PieceSource {
    case original
    case added
  }

  /// A contiguous range of text stored in one of the two contents arrays.
  private struct Piece {
    /// Which array holds the text.
    let source: PieceSource

    /// Start index of the text inside the contents array.
    var startIndex: Int

    /// End index of the text inside the contents array.
    var endIndex: Int

    /// True if this piece contains no characters.
    var isEmpty: Bool { startIndex == endIndex }

    /// How many characters are encompassed by this piece.
    var length: Int { endIndex - startIndex }

    func contains(_ index: Int) -> Bool { (startIndex ..< endIndex).contains(index) }
  }

  /// For performance, maintain the current count of UTF-16 characters instead of computing it from walking the pieces.
  public private(set) var count: Int

  /// The logical contents of the collection, expressed as an array of pieces from either `originalContents` or `newContents`
  private var pieces: [Piece]

  /// Initialize a piece table with the contents of a string.
  public init(_ originalContents: NSString) {
    self.originalContents = originalContents
    self.addedContents = NSMutableString()
    self.count = originalContents.length
    self.pieces = [Piece(source: .original, startIndex: 0, endIndex: originalContents.length)]
  }

  public init(_ string: String) {
    self.init(string as NSString)
  }

  public init() {
    self.init("")
  }

  /// How far the index is from the start of the collection. Convenient for thinking of 0-based indexing into the collection.
  public func offset(for index: Index) -> Int { distance(from: startIndex, to: index) }

  public func index(at offset: Int) -> Index { index(startIndex, offsetBy: offset) }

  public enum SearchResult<T>: Equatable where T: Equatable {
    case found(at: T) // swiftlint:disable:this identifier_name
    case notFound(lowerBound: T?, upperBound: T?)
  }

  public func indexForOriginalOffset(_ originalOffset: Int) -> SearchResult<Index> {
    var previousOriginalIndex: Index?
    for (index, piece) in pieces.enumerated() where piece.source == .original {
      if piece.contains(originalOffset) {
        return .found(at: Index(pieceIndex: index, contentIndex: originalOffset))
      }
      if piece.startIndex > originalOffset {
        // We've gone too far.
        return .notFound(lowerBound: previousOriginalIndex, upperBound: Index(pieceIndex: index, contentIndex: piece.startIndex))
      }
      if !piece.isEmpty {
        // this is the index of the original content with the highest offset less than the target offset that we've found.
        previousOriginalIndex = Index(pieceIndex: index, contentIndex: piece.endIndex - 1)
      }
    }
    return .notFound(lowerBound: previousOriginalIndex, upperBound: nil)
  }

  public func originalOffsetForIndex(_ index: Index) -> SearchResult<Int> {
    // special case endIndex?
    if index == endIndex {
      return .found(at: originalContents.length)
    }
    switch pieces[index.pieceIndex].source {
    case .original:
      return .found(at: index.contentIndex)
    case .added:
      let priorOriginalPiece = pieces.prefix(index.pieceIndex).reversed().first(where: { $0.source == .original && !$0.isEmpty })
      let nextOriginalPiece = pieces.dropFirst(index.pieceIndex).first(where: { $0.source == .original && !$0.isEmpty })
      return .notFound(lowerBound: priorOriginalPiece.flatMap { $0.endIndex - 1 }, upperBound: nextOriginalPiece.flatMap { $0.startIndex })
    }
  }

  public enum Bound {
    case lowerBound
    case upperBound
  }

  // swiftlint:disable:next cyclomatic_complexity
  public func findBound(_ bound: Bound, forOriginalBound originalOffset: Int) -> Index {
    var previousOriginalPieceIndex: Int?
    for (index, piece) in pieces.enumerated() where piece.source == .original {
      if piece.contains(originalOffset) {
        return Index(pieceIndex: index, contentIndex: originalOffset)
      }
      if bound == .upperBound, piece.endIndex == originalOffset {
        // We're looking for an upper bound at `originalOffset`, and whatever comes after
        // this current piece is the first thing past `originalOffset`
        return self.index(after: Index(pieceIndex: index, contentIndex: piece.endIndex - 1))
      }
      if piece.startIndex > originalOffset {
        switch (bound, previousOriginalPieceIndex) {
        case (.lowerBound, .none):
          return startIndex
        case (.lowerBound, .some(let pieceIndex)):
          if pieceIndex + 1 < pieces.endIndex {
            let piece = pieces[pieceIndex + 1]
            return Index(pieceIndex: pieceIndex + 1, contentIndex: piece.startIndex)
          } else {
            return endIndex
          }
        case (.upperBound, _):
          return Index(pieceIndex: index, contentIndex: piece.startIndex)
        }
      }
      if !piece.isEmpty {
        // this is the index of the original content with the highest offset less than the target offset that we've found.
        previousOriginalPieceIndex = index
      }
    }
    switch bound {
    case .lowerBound:
      return startIndex
    case .upperBound:
      return endIndex
    }
  }

  public func findOriginalBound(_ bound: Bound, forBound updatedBound: Index) -> Int {
    if updatedBound == endIndex {
      return originalContents.length
    }
    switch pieces[updatedBound.pieceIndex].source {
    case .original:
      return updatedBound.contentIndex
    case .added:
      // `updatedBound` references a bit of replacement text.
      //
      // If it references something *beyond* the start of the replacement text *and* we need an end range, then find the next
      // original index. Otherwise, return the *previous* original index.
      if updatedBound.contentIndex > pieces[updatedBound.pieceIndex].startIndex, bound == .upperBound {
        if let nextOriginalPiece = pieces.dropFirst(updatedBound.pieceIndex).first(where: { $0.source == .original && !$0.isEmpty }) {
          return nextOriginalPiece.startIndex
        } else {
          return originalContents.length
        }
      } else {
        if let priorOriginalPiece = pieces.prefix(updatedBound.pieceIndex).reversed().first(where: { $0.source == .original && !$0.isEmpty }) {
          return priorOriginalPiece.endIndex
        } else {
          return 0
        }
      }
    }
  }

  public mutating func revertToOriginal() {
    addedContents = NSMutableString()
    count = originalContents.length
    pieces = [Piece(source: .original, startIndex: 0, endIndex: originalContents.length)]
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

  public var startIndex: Index {
    if let piece = pieces.first, !piece.isEmpty {
      return Index(pieceIndex: 0, contentIndex: piece.startIndex)
    } else {
      // Special case: If the first piece is empty, we need to say startIndex == endIndex
      return endIndex
    }
  }

  public var endIndex: Index { Index(pieceIndex: pieces.endIndex, contentIndex: 0) }

  public func index(after i: Index) -> Index {
    let piece = pieces[i.pieceIndex]

    // Check if the next content index is within the bounds of this piece...
    if i.contentIndex + 1 < piece.endIndex {
      return Index(pieceIndex: i.pieceIndex, contentIndex: i.contentIndex + 1)
    }

    // Otherwise, construct an index that refers to the beginning of the next piece.
    let nextPieceIndex = i.pieceIndex + 1
    if nextPieceIndex < pieces.endIndex {
      return Index(pieceIndex: nextPieceIndex, contentIndex: pieces[nextPieceIndex].startIndex)
    } else {
      return Index(pieceIndex: nextPieceIndex, contentIndex: 0)
    }
  }

  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return index(i, offsetBy: distance, limitedBy: endIndex)!
  }

  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
    var distance = distance
    var contentIndex = i.contentIndex
    for sliceIndex in i.pieceIndex ..< pieces.endIndex {
      let slice = pieces[sliceIndex]
      let charactersInSlice = sliceIndex == limit.pieceIndex
        ? limit.contentIndex - contentIndex
        : slice.endIndex - contentIndex
      if distance < charactersInSlice {
        return Index(pieceIndex: sliceIndex, contentIndex: contentIndex + distance)
      }
      if sliceIndex + 1 == pieces.endIndex {
        contentIndex = 0
      } else {
        contentIndex = pieces[sliceIndex + 1].startIndex
      }
      distance -= charactersInSlice
    }
    if distance == 0 {
      return limit
    } else {
      return nil
    }
  }

  public func distance(from start: Index, to end: Index) -> Int {
    var distance = 0
    for sliceIndex in start.pieceIndex ... end.pieceIndex where sliceIndex < pieces.endIndex {
      let piece = pieces[sliceIndex]
      let lowerBound = (sliceIndex == start.pieceIndex) ? start.contentIndex : piece.startIndex
      let upperBound = (sliceIndex == end.pieceIndex) ? end.contentIndex : piece.endIndex
      distance += (upperBound - lowerBound)
    }
    return distance
  }

  public subscript(position: Index) -> unichar {
    switch pieces[position.pieceIndex].source {
    case .added:
      return addedContents.character(at: position.contentIndex)
    case .original:
      return originalContents.character(at: position.contentIndex)
    }
  }

  /// Gets a substring of the PieceTable contents.
  public subscript<R: RangeExpression>(boundsExpression: R) -> [unichar] where R.Bound == Index {
    let bounds = boundsExpression.relative(to: self)
    guard !bounds.isEmpty else { return [] }
    let count = distance(from: bounds.lowerBound, to: bounds.upperBound)
    let results = [unichar](unsafeUninitializedCapacity: count) { buffer, initializedCount in
      copyCharacters(at: bounds, to: buffer.baseAddress!)
      initializedCount = count
    }
    return results
  }

  /// Copies characters from a range into the provided buffer. The buffer must be the right size to hold the copied characters.
  public func copyCharacters<R: RangeExpression>(at range: R, to buffer: UnsafeMutablePointer<unichar>) where R.Bound == Index {
    var buffer = buffer
    let bounds = range.relative(to: self)
    guard !bounds.isEmpty else { return }
    for pieceIndex in bounds.lowerBound.pieceIndex ... bounds.upperBound.pieceIndex where pieceIndex < pieces.endIndex {
      let piece = pieces[pieceIndex]
      let lowerBound = (pieceIndex == bounds.lowerBound.pieceIndex) ? bounds.lowerBound.contentIndex : piece.startIndex
      let upperBound = (pieceIndex == bounds.upperBound.pieceIndex) ? bounds.upperBound.contentIndex : piece.endIndex
      let count = upperBound - lowerBound
      switch piece.source {
      case .original:
        originalContents.getCharacters(buffer, range: NSRange(lowerBound ..< upperBound))
      case .added:
        addedContents.getCharacters(buffer, range: NSRange(lowerBound ..< upperBound))
      }
      buffer += count
    }
  }

  /// Return the contents of the PieceTable as a string.
  public var string: String {
    return String(utf16CodeUnits: self[startIndex...], count: count)
  }
}

extension PieceTable: SafeUnicodeBuffer {
  /// Returns the unicode characters at a specific range.
  public subscript(range: NSRange) -> [unichar] {
    let tableRange = Range(range, in: self)!
    return self[tableRange]
  }

  /// Returns a single unicode character at a specific index. If the index is at or after the end of the buffer contents, returns nil.
  public func utf16(at index: Int) -> unichar? {
    guard let tableIndex = self.index(startIndex, offsetBy: index, limitedBy: endIndex), tableIndex < endIndex else {
      return nil
    }
    return self[tableIndex]
  }

  public func character(at index: Int) -> Character? {
    guard let tableIndex = self.index(startIndex, offsetBy: index, limitedBy: endIndex), tableIndex < endIndex else {
      return nil
    }
    let characterString: String
    switch pieces[tableIndex.pieceIndex].source {
    case .original:
      let range = originalContents.rangeOfComposedCharacterSequence(at: tableIndex.contentIndex)
      characterString = originalContents.substring(with: range)
    case .added:
      let range = addedContents.rangeOfComposedCharacterSequence(at: tableIndex.contentIndex)
      characterString = addedContents.substring(with: range)
    }
    assert(characterString.count == 1)
    return characterString.first
  }
}

extension PieceTable: RangeReplaceableSafeUnicodeBuffer {
  /// Replace the utf16 scalars in a range with the utf16 scalars from a string.
  public mutating func replaceCharacters(in range: NSRange, with str: String) {
    let tableRange = Range(range, in: self)!
    replaceSubrange(tableRange, with: str.utf16)
  }
}

extension PieceTable: RangeReplaceableCollection {
  /// This structure holds all of the information needed to change the pieces in a piece table.
  ///
  /// To create the most compact final `pieces` array as possible, we use the following rules when appending pieces:
  ///
  /// 1. No empty pieces -- if you try to insert something empty, we just omit it.
  /// 2. No consecutive adjoining pieces (where replacement[n].endIndex == replacement[n+1].startIndex). If we're about to store
  ///   something like this, we just "extend" replacement[n] to encompass the new range.
  private struct ChangeDescription {
    private(set) var values: [Piece] = []

    /// The smallest index of an existing piece added to `values`
    var lowerBound: Int?

    /// The largest index of an existing piece added to `values`
    var upperBound: Int?

    /// Adds a piece to the description.
    mutating func appendPiece(_ piece: Piece) {
      // No empty pieces in our replacements array.
      guard !piece.isEmpty else { return }

      // If `piece` starts were `replacements` ends, just extend the end of `replacements`
      if let last = values.last, last.source == piece.source, last.endIndex == piece.startIndex {
        values[values.count - 1].endIndex = piece.endIndex
      } else {
        // Otherwise, stick our new piece into the replacements.
        values.append(piece)
      }
    }
  }

  /// If `index` is valid, then retrieve the piece at that index, modify it, and append it to the change description.
  private func safelyAddToDescription(
    _ description: inout ChangeDescription,
    modifyPieceAt index: Int,
    modificationBlock: (inout Piece) -> Void
  ) {
    guard pieces.indices.contains(index) else { return }
    var piece = pieces[index]
    modificationBlock(&piece)
    description.lowerBound = description.lowerBound.map { Swift.min($0, index) } ?? index
    description.upperBound = description.upperBound.map { Swift.max($0, index) } ?? index
    description.appendPiece(piece)
  }

  /// Update the piece table with the changes contained in `changeDescription`
  private mutating func applyChangeDescription(_ changeDescription: ChangeDescription) {
    let range: Range<Int>
    if let minIndex = changeDescription.lowerBound, let maxIndex = changeDescription.upperBound {
      range = minIndex ..< maxIndex + 1
    } else {
      range = pieces.endIndex ..< pieces.endIndex
    }
    pieces.replaceSubrange(range, with: changeDescription.values)
  }

  /// Replace a range of characters with `newElements`. Note that `subrange` can be empty (in which case it's just an insert point).
  /// Similarly `newElements` can be empty (expressing deletion).
  ///
  /// Also remember that characters are never really deleted.
  public mutating func replaceSubrange<C, R>(
    _ subrange: R,
    with newElements: C
  ) where C: Collection, R: RangeExpression, unichar == C.Element, Index == R.Bound {
    let range = subrange.relative(to: self)
    let replacedDistance = distance(from: range.lowerBound, to: range.upperBound)
    count += (newElements.count - replacedDistance)

    // The (possibly) mutated copies of entries in the piece table
    var changeDescription = ChangeDescription()

    safelyAddToDescription(&changeDescription, modifyPieceAt: range.lowerBound.pieceIndex - 1) { _ in
      // No modification
      //
      // We might need to coalesce the contents we are inserting with the piece *before* this in the
      // piece table. Allow for this by inserting the unmodified piece table entry that comes before
      // the edit.
    }
    safelyAddToDescription(&changeDescription, modifyPieceAt: range.lowerBound.pieceIndex) { piece in
      piece.endIndex = range.lowerBound.contentIndex
    }

    if !newElements.isEmpty {
      // Append `newElements` to `addedContents`, build a piece to hold the new characters, and
      // insert that into the change description.
      let index = addedContents.length
      addedContents.append(String(utf16CodeUnits: Array(newElements), count: newElements.count))
      let addedPiece = Piece(source: .added, startIndex: index, endIndex: addedContents.length)
      changeDescription.appendPiece(addedPiece)
    }

    safelyAddToDescription(&changeDescription, modifyPieceAt: range.upperBound.pieceIndex) { piece in
      piece.startIndex = range.upperBound.contentIndex
    }

    applyChangeDescription(changeDescription)
  }
}
