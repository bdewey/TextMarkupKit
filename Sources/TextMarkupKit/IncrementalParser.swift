// 

import Foundation

public final class IncrementalParser {
  public init(_ string: String, grammar: PackratGrammar) throws {
    self.pieceTable = PieceTable(string)
    self.parser = PackratParser(buffer: pieceTable, grammar: grammar)
    self.tree = try parser.parse()
  }

  // TODO: Make this private; I can do this when PieceTable and IncrementalParser conform
  // to a common interface.
  public let pieceTable: PieceTable
  public let parser: PackratParser
  public private(set) var tree: Node

  public func replaceCharacters(in range: NSRange, with str: String) throws {
    pieceTable.replaceCharacters(in: range, with: str)
    parser.applyEdit(originalRange: range, replacementLength: str.utf16.count)
    tree = try parser.parse()
  }

  // MARK: - Accessing text

  public var length: Int { pieceTable.length }
  public var string: String { pieceTable.string }
  public subscript(range: NSRange) -> String { pieceTable[range] }
}
