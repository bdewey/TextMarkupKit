// 

import Foundation

//let h2 = NodeType.header
//  .startsWith(.pattern("#", min: 1, max: 6))
//  .then([
//    .assert(.whitespace),
//    .styledText(),
//  ]),
//  .endsWith(unichar.newline)
//
//let p2 = NodeType.paragraph
//  .startsWith(.anything)
//  .then([.styledText()])
//  .endsWith(paragraphTermination)
//
//let e2 = NodeType.emphasis
//  .startsWith("*")
//  .then([.styledText()])
//  .endsWith("*")
//
//let c2 = NodeType.code
//  .startsWith("`")
//  .then(.anything)
//  .endsWith("`")

public typealias Recognizer = (inout NSStringIterator) -> Node?
public typealias SequenceRecognizer = (inout NSStringIterator) -> [Node]

func concat(_ recognizer: Recognizer?, _ sequence: @escaping SequenceRecognizer) -> SequenceRecognizer {
  guard let recognizer = recognizer else {
    return sequence
  }
  return { iterator in
    guard let initialNode = recognizer(&iterator) else {
      return []
    }
    let remainder = sequence(&iterator)
    return [initialNode] + remainder
  }
}

func bind(nodeType: NodeType, sequenceRecognizer: @escaping SequenceRecognizer) -> Recognizer {
  return { iterator in
    let children = sequenceRecognizer(&iterator)
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
    let savepoint = iterator
    var children: [Node] = []
    if let opening = opening {
      if let node = opening(&iterator) {
        children.append(node)
      } else {
        iterator = savepoint
        return nil
      }
    }
    var scopedIterator = iterator.pushScope(.endBeforePattern, pattern: pattern)
    children.append(contentsOf: body(&scopedIterator))
    iterator = scopedIterator.popScope()
    if let closingRecognizer = pattern.recognizer(type: .delimiter) {
      if let node = closingRecognizer(&iterator) {
        children.append(node)
      } else {
        iterator = savepoint
        return nil
      }
    }
    if let range = children.encompassingRange {
      return Node(type: type, range: range, children: children)
    } else {
      iterator = savepoint
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
    let savepoint = iterator
    var children: [Node] = []
    if let opening = opening {
      if let node = opening(&iterator) {
        children.append(node)
      } else {
        iterator = savepoint
        return nil
      }
    }
    var scopedIterator = iterator.pushScope(.endAfterPattern, pattern: pattern)
    children.append(contentsOf: body(&scopedIterator))
    iterator = scopedIterator.popScope()
    if let range = children.encompassingRange {
      return Node(type: type, range: range, children: children)
    } else {
      iterator = savepoint
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
    let pattern = endsAfterPattern ?? endsWith?.pattern
    let scopeType: NSStringIteratorScopeType = (endsAfterPattern == nil) ? .endBeforePattern : .endAfterPattern
    return { [type] iterator in
      let savepoint = iterator
      var children: [Node] = []
      if let opening = opening {
        if let node = opening(&iterator) {
          children.append(node)
        } else {
          iterator = savepoint
          return nil
        }
      }
      if let pattern = pattern {
        var scopedIterator = iterator.pushScope(scopeType, pattern: pattern.asAnyPattern())
        children.append(contentsOf: body(&scopedIterator))
        iterator = scopedIterator.popScope()
      } else {
        children.append(contentsOf: body(&iterator))
      }
      if let closing = closing {
        if let node = closing(&iterator) {
          children.append(node)
        } else {
          iterator = savepoint
          return nil
        }
      }
      if let range = children.encompassingRange {
        return Node(type: type, range: range, children: children)
      } else {
        iterator = savepoint
        return nil
      }
    }
  }
}
