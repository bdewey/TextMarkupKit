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
  static let delimiter: NodeType = "delimiter"
}

public struct Delimiter: NodeRecognizer {
  public init(_ delimiter: String) {
    self.delimiter = delimiter
  }

  public let delimiter: String

  public func recognizeNode(textBuffer: TextBuffer, position: TextBufferIndex) -> Node? {
    var currentPosition = position
    for character in delimiter.utf16 {
      guard character == textBuffer.utf16(at: currentPosition), let nextPosition = textBuffer.index(after: currentPosition) else {
        return nil
      }
      currentPosition = nextPosition
    }
    return Node(type: .delimiter, range: position ..< currentPosition)
  }
}
