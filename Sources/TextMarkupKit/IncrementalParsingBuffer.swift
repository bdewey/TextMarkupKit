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

public final class IncrementalParsingBuffer {
  public init(_ string: String, grammar: PackratGrammar) {
    let pieceTable = PieceTable(string)
    self.grammar = grammar
    let memoizationTable = MemoizationTable()
    let result = Result {
      try pieceTable.parse(grammar: grammar, memoizationTable: memoizationTable)
    }
    self.pieceTable = pieceTable
    self.memoizationTable = memoizationTable
    self.result = result
  }

  // TODO: Make this private; I can do this when PieceTable and IncrementalParser conform
  // to a common interface.
  private let pieceTable: PieceTable
  public let memoizationTable: MemoizationTable
  public let grammar: PackratGrammar
  public private(set) var result: Result<Node, Error>
}

extension IncrementalParsingBuffer: RangeReplaceableSafeUnicodeBuffer {
  public var count: Int { pieceTable.count }

  public subscript(range: NSRange) -> String { pieceTable[range] }

  public subscript<R>(range: R) -> String where R: RangeExpression, R.Bound == Int {
    return pieceTable[range]
  }

  public func utf16(at index: Int) -> unichar? {
    return pieceTable.utf16(at: index)
  }

  public func replaceCharacters(in range: NSRange, with str: String) {
    pieceTable.replaceCharacters(in: range, with: str)
    memoizationTable.applyEdit(originalRange: range, replacementLength: str.utf16.count)
    result = Result {
      try pieceTable.parse(grammar: grammar, memoizationTable: memoizationTable)
    }
  }
}
