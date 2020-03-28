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

public protocol MarkupRule {
  func nodeAtPosition(_ position: StringPosition) -> MarkupNode?
}

public struct ChoiceRule: MarkupRule {
  public let rules: [MarkupRule]

  public func nodeAtPosition(_ position: StringPosition) -> MarkupNode? {
    for rule in rules {
      if let node = rule.nodeAtPosition(position) {
        return node
      }
    }
    return nil
  }
}

public struct RepeatRule: MarkupRule {
  public let name: MarkupNode.Identifier
  public let subrule: MarkupRule

  public func nodeAtPosition(_ position: StringPosition) -> MarkupNode? {
    var children: [MarkupNode] = []
    var currentPosition = position
    while let child = subrule.nodeAtPosition(currentPosition) {
      children.append(child)
      currentPosition = child.range.upperBound
    }
    if let lastChild = children.last {
      return MarkupNode(name: name, range: position ..< lastChild.range.upperBound, children: children)
    } else {
      return nil
    }
  }
}

public struct SequenceRule: MarkupRule {
  public let name: MarkupNode.Identifier
  public let children: [MarkupRule]

  public func nodeAtPosition(_ position: StringPosition) -> MarkupNode? {
    var childNodes: [MarkupNode] = []
    var currentPosition = position
    for childRule in children {
      guard let childNode = childRule.nodeAtPosition(currentPosition) else {
        return nil
      }
      childNodes.append(childNode)
      currentPosition = childNode.range.upperBound
    }
    if let lastChild = childNodes.last {
      return MarkupNode(name: name, range: position ..< lastChild.range.upperBound, children: childNodes)
    } else {
      return nil
    }
  }
}

public struct TextMatchingRule: MarkupRule {
  public let name: MarkupNode.Identifier
  public let predicate: (Character) -> Bool

  public func nodeAtPosition(_ position: StringPosition) -> MarkupNode? {
    var endPosition = position
    while predicate(endPosition.character) {
      endPosition.advance()
    }
    guard endPosition > position else {
      return nil
    }
    return MarkupNode(name: name, range: position ..< endPosition, children: [])
  }
}
