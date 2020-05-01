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

/// Just a handy alias for NSAttributedString attributes
public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]

/// A function that modifies NSAttributedString attributes based the syntax tree.
public typealias FormattingFunction = (Node, inout AttributedStringAttributes) -> Void

/// Key for storing the string attributes associated with a node.
private struct NodeAttributesKey: NodePropertyKey {
  typealias Value = AttributedStringAttributes

  static let key = "attributes"
}

public extension Node {
  /// Associates AttributedStringAttributes with this part of the syntax tree.
  func applyAttributes(
    attributes: AttributedStringAttributes,
    formattingFunctions: [NodeType: FormattingFunction],
    startingIndex: Int,
    leafNodeRange: inout Range<Int>?
  ) {
    // If we already have attributes we don't need to do anything else.
    guard self[NodeAttributesKey.self] == nil else {
      return
    }
    var attributes = attributes
    formattingFunctions[type]?(self, &attributes)
    self[NodeAttributesKey.self] = attributes
    var childLength = 0
    if children.isEmpty {
      // We are a leaf. Adjust leafNodeRange.
      let lowerBound = min(startingIndex, leafNodeRange?.lowerBound ?? Int.max)
      let upperBound = max(startingIndex + length, leafNodeRange?.upperBound ?? Int.min)
      leafNodeRange = lowerBound ..< upperBound
    }
    for child in children {
      child.applyAttributes(
        attributes: attributes,
        formattingFunctions: formattingFunctions,
        startingIndex: startingIndex + childLength,
        leafNodeRange: &leafNodeRange
      )
      childLength += child.length
    }
  }
}
