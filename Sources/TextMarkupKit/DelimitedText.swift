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

public struct DelimitedText: NodeRecognizer, SentinelContaining {
  public init(type: NodeType, leftDelimiter: String, rightDelimiter: String? = nil) {
    self.type = type
    self.leftDelimiter = leftDelimiter
    self.rightDelimiter = rightDelimiter ?? leftDelimiter
  }

  public let type: NodeType
  public let leftDelimiter: String
  public let rightDelimiter: String

  public var sentinels: CharacterSet { CharacterSet(charactersIn: leftDelimiter) }

  public func recognizeNode(textBuffer: TextBuffer, position: Int) -> Node? {
    guard
      let leftNode = Delimiter(leftDelimiter).recognizeNode(textBuffer: textBuffer, position: position),
      let rightDelimiterStart = textBuffer.firstIndex(of: rightDelimiter, startingPosition: leftNode.range.upperBound)
    else {
      return nil
    }
    // TODO: Recursively look for more styled text here
    let textNode = Node(type: .text, range: leftNode.range.upperBound ..< rightDelimiterStart)
    guard let rightNode = Delimiter(rightDelimiter).recognizeNode(textBuffer: textBuffer, position: textNode.range.upperBound) else {
      return nil
    }
    let children = [leftNode, textNode, rightNode]
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: type, range: range, children: children)
  }
}

public extension NodeType {
  static let emphasis: NodeType = "emphasis"
  static let strongEmphasis: NodeType = "strong_emphasis"
}

public extension DelimitedText {
  static let emphasis = DelimitedText(type: .emphasis, leftDelimiter: "*")
  static let strongEmphasis = DelimitedText(type: .strongEmphasis, leftDelimiter: "**")
}
