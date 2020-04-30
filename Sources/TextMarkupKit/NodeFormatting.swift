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

public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]
public typealias FormattingFunction = (Node, inout AttributedStringAttributes) -> Void

private struct NodeAttributesKey: NodePropertyKey {
  typealias Value = AttributedStringAttributes

  static let key = "attributes"
}

public extension Node {
  func applyAttributes(
    defaultAttributes: AttributedStringAttributes,
    formattingFunctions: [NodeType: FormattingFunction]
  ) {
    // TODO: Actually apply formatting
    guard self[NodeAttributesKey.self] == nil else {
      return
    }
    self[NodeAttributesKey.self] = defaultAttributes
    for child in children {
      child.applyAttributes(defaultAttributes: defaultAttributes, formattingFunctions: formattingFunctions)
    }
  }
}
