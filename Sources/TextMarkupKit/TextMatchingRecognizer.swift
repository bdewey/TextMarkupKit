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

public struct TextMatchingRecognizer: NodeRecognizer {
  public init(type: NodeType, matchFunction: @escaping (unichar) -> Bool) {
    self.type = type
    self.matchFunction = matchFunction
  }

  public let type: NodeType
  public let matchFunction: (unichar) -> Bool

  public func recognizeNode(textBuffer: TextBuffer, position: Int) -> Node? {
    var endPosition = position
    while textBuffer.utf16(at: endPosition).map(matchFunction) ?? false {
      endPosition += 1
    }
    guard endPosition > position else {
      return nil
    }
    return Node(type: type, range: position ..< endPosition, children: [])
  }
}
