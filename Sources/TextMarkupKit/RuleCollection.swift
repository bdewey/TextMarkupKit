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

/// A collection of sentinel-containing recognizers. `sentinels` lets you know if you can skip looking at any of these.
public struct RuleCollection: ExpressibleByArrayLiteral {
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

  /// Tries all of the rules in the collection in order and returns the first non-nil result.
  public func recognize(iterator: inout NSStringIterator) -> Node? {
    for rule in rules {
      let restorePoint = iterator
      if let node = rule.recognizer(&iterator) {
        return node
      }
      iterator = restorePoint
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
