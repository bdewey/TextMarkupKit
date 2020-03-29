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

extension NodeType {
  public static let markdownDocument: NodeType = "document"
  public static let paragraph: NodeType = "paragraph"
}

public struct MarkdownDocument: UnconditionalParser {
  public init(
    subparsers: [SentinelParser] = [
      Header(),
      BlankLine(),
    ],
    defaultParser: UnconditionalParser = Paragraph()
  ) {
    self.subparsers = SentinelParserCollection(subparsers)
    self.defaultParser = defaultParser
  }

  public var subparsers: SentinelParserCollection
  public let defaultParser: UnconditionalParser

  public func parse(textBuffer: TextBuffer, position: TextBuffer.Index) -> Node {
    var children = [Node]()
    var position = position
    while let scalar = textBuffer.unicodeScalar(at: position) {
      if
        subparsers.sentinels.contains(scalar),
        let node = subparsers.parse(textBuffer: textBuffer, position: position) {
        children.append(node)
        position = node.range.upperBound
      } else {
        let paragraphNode = defaultParser.parse(textBuffer: textBuffer, position: position)
        children.append(paragraphNode)
        position = paragraphNode.range.upperBound
      }
    }
    return Node(type: .markdownDocument, range: position ..< position, children: children)
  }
}
