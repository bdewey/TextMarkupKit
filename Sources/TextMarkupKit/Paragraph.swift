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

public struct Paragraph: Parser {
  public init() {}

  public func parse(textBuffer: TextBuffer, position: TextBufferIndex) -> Node {
    let paragraphTextBuffer = ParagraphTerminationTextBuffer(textBuffer: textBuffer, paragraphStartIndex: position)
    let children = TextSequenceRecognizer.miniMarkdown.parse(textBuffer: paragraphTextBuffer, position: position)
    if let childRange = children.encompassingRange {
      return Node(type: .paragraph, range: childRange, children: children)
    } else {
      // TODO -- change this from a parser?
      return Node(type: .paragraph, range: position ..< position)
    }
  }
}

private struct ParagraphTerminationTextBuffer: TextBuffer {
  private static let paragraphTermination: CharacterSet = [
    "#",
    "\n",
  ]

  let textBuffer: TextBuffer
  let paragraphStartIndex: TextBufferIndex

  private func isEndOfParagraph(_ index: TextBufferIndex) -> Bool {
    guard
      let previousIndex = textBuffer.index(before: index),
      let previousCharacter = textBuffer.character(at: previousIndex),
      previousCharacter == "\n",
      let currentScalar = textBuffer.unicodeScalar(at: index)
    else {
      return false
    }
    return Self.paragraphTermination.contains(currentScalar)
  }

  var startIndex: TextBufferIndex { paragraphStartIndex }

  func character(at index: TextBufferIndex) -> Character? {
    guard !isEndOfParagraph(index) else {
      return nil
    }
    return textBuffer.character(at: index)
  }

  func unicodeScalar(at index: TextBufferIndex) -> UnicodeScalar? {
    guard !isEndOfParagraph(index) else {
      return nil
    }
    return textBuffer.unicodeScalar(at: index)
  }

  func index(after index: TextBufferIndex) -> TextBufferIndex? {
    guard !isEndOfParagraph(index) else {
      return nil
    }
    return textBuffer.index(after: index)
  }

  func index(before index: TextBufferIndex) -> TextBufferIndex? {
    guard index != paragraphStartIndex else {
      return nil
    }
    return textBuffer.index(before: index)
  }
}
