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

/// Possible parsing errors.
public enum ParseError: Swift.Error {
  /// The parsing routine did not parse the entire document.
  case incompleteParsing(TextBuffer.Index)
}

/// A parser for something that *might* be at a spot in the input.
public protocol ConditionalParser {
  /// If possible to parse a node at a specific position in the input, do so.
  func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node?
}

extension Sequence where Element: ConditionalParser {
  /// If you have an sequence of ConditionalParsers, returns the first non-nil result.
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    for subparser in self {
      if let node = subparser.parse(textBuffer: textBuffer, position: position) {
        return node
      }
    }
    return nil
  }
}

/// A parser that is guaranteed to succeed. This is what distinguishes a lot of casual markup languages from computer programming
/// languages. There's no such thing as a "syntax error" in a Markdown document, for example; every text file is a valid Markdown file.
/// If you get the syntax wrong your formatting or links might not be recognized, but the text is still valid.
public protocol UnconditionalParser {
  /// Parse the text at the given input.
  func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node
}

extension UnconditionalParser {
  /// Parses a string.
  public func parse(_ text: String) throws -> Node {
    let buffer = TextBuffer(text)
    let node = parse(textBuffer: buffer, position: buffer.startIndex)
    if node.range.upperBound != text.endIndex {
      throw ParseError.incompleteParsing(node.range.upperBound)
    }
    return node
  }
}

/// A parser that succeeds when it recognizes a sequence of child nodes at the specified spot in the buffer.
public protocol SequenceParser: ConditionalParser {
  /// The type of node that will be created if the sequence is recognized.
  var type: NodeType { get }

  /// A function that recognizes a sequence of nodes, in consecutive order, at a spot in the TextBuffer.
  var sequenceRecognizer: (TextBuffer, TextBuffer.Index) -> [Node] { get }
}

extension SequenceParser {
  /// Default `parse` implementation for a SequenceParser.
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    let children = sequenceRecognizer(textBuffer, position)
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: type, range: range, children: children)
  }
}

/// A `SentinelParser` is a parser that has one or more unicode scalars that indicates that its possible to recognize
/// its node at a given point in the input stream.
public protocol SentinelParser: ConditionalParser {
  var sentinels: CharacterSet { get }
}

/// A collection of `SentinelParsers`
public struct SentinelParserCollection {
  public init(_ parsers: [SentinelParser]) {
    self.parsers = parsers
    self.sentinels = Self.unionOfSentinels(in: parsers)
  }

  /// The parsers in the collection.
  public var parsers: [SentinelParser] {
    didSet {
      self.sentinels = Self.unionOfSentinels(in: parsers)
    }
  }

  /// The union of all sentinels in the collection. If the unicode scalar at a spot in the TextBuffer is **not** in this set, then
  /// you can skip trying to recognize anything in this collection.
  public private(set) var sentinels: CharacterSet

  /// Attempt to recognize a node at the given point in the TextBuffer. It will return the first result from any of the recognizers.
  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node? {
    for subparser in parsers {
      if let node = subparser.parse(textBuffer: textBuffer, position: position) {
        return node
      }
    }
    return nil
  }

  private static func unionOfSentinels(in parsers: [SentinelParser]) -> CharacterSet {
    parsers
      .map { $0.sentinels }
      .reduce(into: CharacterSet()) { $0.formUnion($1) }
  }
}
