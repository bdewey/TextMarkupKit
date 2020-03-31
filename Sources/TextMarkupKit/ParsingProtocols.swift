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
  case incompleteParsing(Int)
}

/// Recognizes bits of structure inside of a text file.
public protocol NodeRecognizer {
  /// Returns a Node representing the structure at the specific position in the TextBuffer, if possible.
  /// - returns: The recognized node, or nil if the node is not present at this spot in the TextBuffer.
  func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node?
}

extension Sequence where Element: NodeRecognizer {}

/// Unlike a recognizer, a `parser` is guaranteed to succeed.
/// This is what distinguishes a lot of casual markup languages from computer programming
/// languages. There's no such thing as a "syntax error" in a Markdown document, for example; every text file is a valid Markdown file.
/// If you get the syntax wrong your formatting or links might not be recognized, but the text is still valid.
public protocol Parser {
  /// Parse the text at the given input.
  func parse(textBuffer: TextBuffer, position: TextBufferIndex) -> Node
}

extension Parser {
  /// Parses a string.
  public func parse(_ text: String) throws -> Node {
    let buffer = PieceTable(text)
    let node = parse(textBuffer: buffer, position: buffer.startIndex)
    if node.range.upperBound != buffer.endIndex {
      throw ParseError.incompleteParsing(node.range.upperBound.stringIndex)
    }
    return node
  }
}

/// A parser that succeeds when it recognizes a sequence of child nodes at the specified spot in the buffer.
public protocol SequenceRecognizer: NodeRecognizer {
  /// The type of node that will be created if the sequence is recognized.
  var type: NodeType { get }

  /// A function that recognizes a sequence of nodes, in consecutive order, at a spot in the TextBuffer.
  var sequenceRecognizer: (TextBuffer, TextBufferIndex) -> [Node] { get }
}

extension SequenceRecognizer {
  /// Default `parse` implementation for a SequenceParser.
  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    let children = sequenceRecognizer(textBuffer, position)
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: type, range: range, children: children)
  }
}

public protocol SentinelContaining {
  /// Unicode scalars that signify that a spot in a TextBuffer is "interesting"
  var sentinels: CharacterSet { get }
}

/// A collection of sentinel-containing recognizers. `sentinels` lets you know if you can skip looking at any of these.
public struct SentinelRecognizerCollection: NodeRecognizer {
  public typealias Element = NodeRecognizer & SentinelContaining

  public init(_ recognizers: [Element]) {
    self.recognizers = recognizers
    self.sentinels = Self.unionOfSentinels(in: recognizers)
  }

  /// The parsers in the collection.
  public var recognizers: [Element] {
    didSet {
      sentinels = Self.unionOfSentinels(in: recognizers)
    }
  }

  /// The union of all sentinels in the collection. If the unicode scalar at a spot in the TextBuffer is **not** in this set, then
  /// you can skip trying to recognize anything in this collection.
  public private(set) var sentinels: NSCharacterSet

  /// If you have an sequence of ConditionalParsers, returns the first non-nil result.
  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    for subparser in recognizers {
      if let node = subparser.recognizeNode(textBuffer: textBuffer, position: position) {
        return node
      }
    }
    return nil
  }

  private static func unionOfSentinels(in items: [SentinelContaining]) -> NSCharacterSet {
    let result = NSMutableCharacterSet()
    for item in items {
      result.formUnion(with: item.sentinels)
    }
    return result
  }
}
