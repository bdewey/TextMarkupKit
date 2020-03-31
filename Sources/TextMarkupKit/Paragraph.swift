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

  private static let paragraphTermination = NSCharacterSet(charactersIn: "#\n")

  /// True if a character belongs to a paragraph. Criteria for a paragraph boundary:
  /// 1. `character` is a member of `paragraphTermination`
  /// 2. The *previous* character is a newline.
  /// A character that meets this criteria is the first character in a **new** block and gets filtered out.
  private static func shouldIncludeInParagraph(
    character: unichar,
    textBuffer: TextBuffer,
    index: Int
  ) -> Bool {
    if paragraphTermination.characterIsMember(character), textBuffer.utf16(at: index - 1) == .newline {
      return false
    }
    return true
  }

  public func parse(textBuffer: TextBuffer, position: Int) -> Node {
    let filteredTextBuffer = FilteringTextBuffer(
      textBuffer: textBuffer,
      startIndex: position,
      isIncluded: Self.shouldIncludeInParagraph(character:textBuffer:index:)
    )
    let children = TextSequenceRecognizer.miniMarkdown.parse(
      textBuffer: filteredTextBuffer,
      position: position
    )
    if let childRange = children.encompassingRange {
      return Node(type: .paragraph, range: childRange, children: children)
    } else {
      // TODO: -- change this from a parser?
      assertionFailure()
      return Node(type: .paragraph, range: position ..< position)
    }
  }
}
