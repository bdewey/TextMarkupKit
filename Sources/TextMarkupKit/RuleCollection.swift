// 

import Foundation

/// A collection of sentinel-containing recognizers. `sentinels` lets you know if you can skip looking at any of these.
public struct RuleCollection: NodeRecognizer, ExpressibleByArrayLiteral {
  public struct Rule {
    let sentinels: CharacterSet
    let recognizer: Recognizer

    public init(_ sentinels: CharacterSet, _ recognizer: @escaping Recognizer) {
      self.sentinels = sentinels
      self.recognizer = recognizer
    }
  }

  public init(_ recognizers: [Rule]) {
    self.rules = recognizers
    self.sentinels = Self.unionOfSentinels(in: recognizers)
  }

  public init(arrayLiteral elements: Rule...) {
    self.rules = elements
    self.sentinels = Self.unionOfSentinels(in: rules)
  }

  /// The parsers in the collection.
  public var rules: [Rule] {
    didSet {
      sentinels = Self.unionOfSentinels(in: rules)
    }
  }

  /// The union of all sentinels in the collection. If the unicode scalar at a spot in the TextBuffer is **not** in this set, then
  /// you can skip trying to recognize anything in this collection.
  public private(set) var sentinels: NSCharacterSet

  /// If you have an sequence of ConditionalParsers, returns the first non-nil result.
  public func recognizeNode(textBuffer: TextBuffer, position: Int) -> Node? {
    for rule in rules {
      if let node = rule.recognizer(textBuffer, position) {
        return node
      }
    }
    return nil
  }

  private static func unionOfSentinels(in items: [Rule]) -> NSCharacterSet {
    let result = NSMutableCharacterSet()
    for item in items {
      result.formUnion(with: item.sentinels)
    }
    return result
  }
}
