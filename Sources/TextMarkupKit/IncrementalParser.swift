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
