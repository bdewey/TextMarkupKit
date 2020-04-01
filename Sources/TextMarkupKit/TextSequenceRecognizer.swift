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
  public static let text: NodeType = "text"
}

public struct TextSequenceRecognizer {
  public init(
    textRecognizers: [SentinelRecognizerCollection.Element],
    defaultType: NodeType
  ) {
    self.textRecognizers = SentinelRecognizerCollection(textRecognizers)
    self.defaultType = defaultType
  }

  public var textRecognizers: SentinelRecognizerCollection
  public var defaultType: NodeType

  public func parse(textBuffer: TextBuffer, position: Int) -> [Node] {
    var children = [Node]()
    var defaultRange = position ..< position
    var position = position
    while let utf16 = textBuffer.utf16(at: position) {
      if
        textRecognizers.sentinels.characterIsMember(utf16),
        let node = textRecognizers.recognizeNode(textBuffer: textBuffer, position: position) {
        if !defaultRange.isEmpty {
          let defaultNode = Node(type: defaultType, range: defaultRange)
          children.append(defaultNode)
        }
        children.append(node)
        position = node.range.upperBound
        defaultRange = position ..< position
      } else {
        position += 1
      }
      defaultRange = defaultRange.settingUpperBound(position)
    }
    if !defaultRange.isEmpty {
      let defaultNode = Node(type: defaultType, range: defaultRange)
      children.append(defaultNode)
    }
    return children
  }
}

public extension TextSequenceRecognizer {
  static let miniMarkdown = TextSequenceRecognizer(
    textRecognizers: [
      DelimitedText.strongEmphasis,
      DelimitedText.emphasis,
      DelimitedText.code,
    ],
    defaultType: .text
  )
}

private extension Range {
  func settingUpperBound(_ newUpperBound: Bound) -> Range<Bound> {
    return lowerBound ..< newUpperBound
  }
}
