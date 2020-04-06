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

// let h2 = NodeType.header
//  .startsWith(.pattern("#", min: 1, max: 6))
//  .then([
//    .assert(.whitespace),
//    .styledText(),
//  ]),
//  .endsWith(unichar.newline)
//
// let p2 = NodeType.paragraph
//  .startsWith(.anything)
//  .then([.styledText()])
//  .endsWith(paragraphTermination)
//
// let e2 = NodeType.emphasis
//  .startsWith("*")
//  .then([.styledText()])
//  .endsWith("*")
//
// let c2 = NodeType.code
//  .startsWith("`")
//  .then(.anything)
//  .endsWith("`")

public typealias Recognizer = (NSStringIterator) -> Node?
public typealias SequenceRecognizer = (NSStringIterator) -> [Node]

func concat(_ recognizer: Recognizer?, _ sequence: @escaping SequenceRecognizer) -> SequenceRecognizer {
  guard let recognizer = recognizer else {
    return sequence
  }
  return { iterator in
    guard let initialNode = recognizer(iterator) else {
      return []
    }
    let remainder = sequence(iterator)
    return [initialNode] + remainder
  }
}

func bind(nodeType: NodeType, sequenceRecognizer: @escaping SequenceRecognizer) -> Recognizer {
  return { iterator in
    let children = sequenceRecognizer(iterator)
    guard let range = children.encompassingRange else {
      return nil
    }
    return Node(type: nodeType, range: range, children: children)
  }
}

func recognizer(
  type: NodeType,
  opening: Recognizer?,
  body: @escaping SequenceRecognizer,
  endingWith pattern: AnyPattern
) -> Recognizer {
  return { iterator in
    let savepoint = iterator.index
    var children: [Node] = []
    if let opening = opening {
      if let node = opening(iterator) {
        children.append(node)
      } else {
        iterator.index = savepoint
        return nil
      }
    }
    iterator.pushingScope(.endingBeforePattern(pattern))
    children.append(contentsOf: body(iterator))
    iterator.poppingScope()
    if let closingRecognizer = pattern.recognizer(type: .delimiter) {
      if let node = closingRecognizer(iterator) {
        children.append(node)
      } else {
        iterator.index = savepoint
        return nil
      }
    }
    if let range = children.encompassingRange {
      return Node(type: type, range: range, children: children)
    } else {
      iterator.index = savepoint
      return nil
    }
  }
}

func recognizer(
  type: NodeType,
  opening: Recognizer?,
  body: @escaping SequenceRecognizer,
  endingAfter pattern: AnyPattern
) -> Recognizer {
  return { iterator in
    let savepoint = iterator.index
    var children: [Node] = []
    if let opening = opening {
      if let node = opening(iterator) {
        children.append(node)
      } else {
        iterator.index = savepoint
        return nil
      }
    }
    iterator.pushingScope(.endingAfterPattern(pattern))
    children.append(contentsOf: body(iterator))
    iterator.poppingScope()
    if let range = children.encompassingRange {
      return Node(type: type, range: range, children: children)
    } else {
      iterator.index = savepoint
      return nil
    }
  }
}

public struct RuleBuilder {
  public let type: NodeType

  public init(_ type: NodeType) {
    self.type = type
  }

  private struct TypedPattern {
    let type: NodeType
    let pattern: Pattern

    var recognizer: Recognizer? {
      pattern.recognizer(type: type)
    }
  }

  private var startsWith: TypedPattern?

  public func startsWith(_ openingSequence: AnyPattern, type: NodeType = .delimiter) -> Self {
    var copy = self
    copy.startsWith = TypedPattern(type: type, pattern: openingSequence.innerPattern)
    return copy
  }

  private var body: SequenceRecognizer?

  public func then(_ sequenceRecognizer: @escaping SequenceRecognizer) -> Self {
    var copy = self
    copy.body = sequenceRecognizer
    return copy
  }

  private var endsWith: TypedPattern?

  public func endsWith(_ endingSequence: AnyPattern, type: NodeType = .delimiter) -> Self {
    var copy = self
    copy.endsWith = TypedPattern(type: type, pattern: endingSequence.innerPattern)
    return copy
  }

  private var endsAfterPattern: Pattern?

  public func endsAfter(_ endingSequence: AnyPattern) -> Self {
    var copy = self
    copy.endsAfterPattern = endingSequence.innerPattern
    return copy
  }

  public func build() -> RuleCollection.Rule {
    let sentinels = startsWith?.pattern.sentinels ?? CharacterSet.illegalCharacters.inverted
    return RuleCollection.Rule(sentinels, makeRecognizer())
  }

  private func makeRecognizer() -> Recognizer {
    guard let body = self.body else {
      return startsWith?.pattern.recognizer(type: type) ?? { _ in nil }
    }
    let opening = startsWith?.recognizer
    let closing = endsWith?.recognizer
    let scope: Scope?
    if let pattern = endsAfterPattern {
      scope = Scope.endingAfterPattern(pattern.asAnyPattern())
    } else if let pattern = endsWith?.pattern {
      scope = Scope.endingBeforePattern(pattern.asAnyPattern())
    } else {
      scope = nil
    }
    return { [type] iterator in
      let savepoint = iterator.index
      var children: [Node] = []
      if let opening = opening {
        if let node = opening(iterator) {
          children.append(node)
        } else {
          iterator.index = savepoint
          return nil
        }
      }
      if let scope = scope {
        iterator.pushingScope(scope)
        children.append(contentsOf: body(iterator))
        iterator.poppingScope()
      } else {
        children.append(contentsOf: body(iterator))
      }
      if let closing = closing {
        if let node = closing(iterator) {
          children.append(node)
        } else {
          iterator.index = savepoint
          return nil
        }
      }
      if let range = children.encompassingRange {
        return Node(type: type, range: range, children: children)
      } else {
        iterator.index = savepoint
        return nil
      }
    }
  }
}
