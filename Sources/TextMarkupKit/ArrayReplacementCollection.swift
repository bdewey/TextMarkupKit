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

/// Stores a collection of non-overlapping replacement operations to apply to an array to generate a new array.
public final class ArrayReplacementCollection<Element: Equatable> {
  enum Error: Swift.Error {
    case cannotInsertOverlappingRange
  }

  public struct Replacement: Equatable {
    let range: Range<Int>
    let elements: [Element]

    var changeInLength: Int { elements.count - range.count }
  }

  /// Inserts a replacement in the table.
  public func insert(_ replacement: [Element], at range: Range<Int>) throws {
    var previousLocation = 0

    for insertionPoint in 0 ..< nodes.endIndex {
      let nextLocation = previousLocation + nodes[insertionPoint].locationOffsetFromPreviousLocation
      if range.overlaps(nextLocation ..< nextLocation + nodes[insertionPoint].length) {
        throw Error.cannotInsertOverlappingRange
      }
      if nextLocation > range.lowerBound {
        let node = Node(
          locationOffsetFromPreviousLocation: range.lowerBound - previousLocation,
          length: range.count,
          replacement: replacement
        )
        nodes[insertionPoint].locationOffsetFromPreviousLocation = nextLocation - range.lowerBound
        nodes.insert(node, at: insertionPoint)
      }
      previousLocation = nextLocation
    }
    let node = Node(
      locationOffsetFromPreviousLocation: range.lowerBound - previousLocation,
      length: range.count,
      replacement: replacement
    )
    nodes.append(node)
  }

  /// Moves the ranges of all replacements that come after `contentLocation` by a fixed amount.
  public func shiftReplacements(
    after contentLocation: Int,
    by offsetAmount: Int
  ) {
    guard offsetAmount != 0 else { return }
    var previousLocation = 0
    for (i, node) in nodes.enumerated() {
      let nextLocation = previousLocation + node.locationOffsetFromPreviousLocation
      if nextLocation > contentLocation {
        nodes[i].locationOffsetFromPreviousLocation += offsetAmount
        return
      }
      previousLocation = nextLocation
    }
  }

  /// Removes all replacements that overlap a content range.
  public func removeReplacements<R: RangeExpression>(
    overlapping contentRange: R
  ) where R.Bound == Int {
    guard let nodeRange = rangeOfNodes(overlapping: contentRange) else { return }
    if nodeRange.upperBound.index + 1 < nodes.endIndex {
      let targetOffset = nodeRange.upperBound.location + nodes[nodeRange.upperBound.index + 1].locationOffsetFromPreviousLocation
      let priorOffset = nodeRange.lowerBound.location - nodes[nodeRange.lowerBound.index].locationOffsetFromPreviousLocation
      nodes[nodeRange.upperBound.index + 1].locationOffsetFromPreviousLocation = targetOffset - priorOffset
    }
    nodes.removeSubrange(nodeRange.lowerBound.index ..< nodeRange.upperBound.index + 1)
  }

  /// Returns all replacements that apply to the range of the original NSAttributedString.
  public func replacements<R: RangeExpression>(in filterRange: R) -> [Replacement] where R.Bound == Int {
    let filterRange = filterRange.relative(to: 0 ..< Int.max)
    var results: [Replacement] = []
    var location = 0
    for node in nodes {
      location += node.locationOffsetFromPreviousLocation
      let range = location ..< location + node.length
      if !range.overlaps(filterRange) { continue }
      let result = Replacement(range: range, elements: node.replacement)
      results.append(result)
    }
    return results
  }

  /// Computes the index in the original NSAttributedString for an index in the NSAttributedString with all modifications performed.
  public func physicalIndex(for visibleIndex: Int) -> Int {
    var location = 0
    var visibleIndex = visibleIndex
    for node in nodes {
      location += node.locationOffsetFromPreviousLocation
      if visibleIndex >= location + node.replacement.count {
        visibleIndex += node.length - node.replacement.count
      } else {
        break
      }
    }
    return visibleIndex
  }

  public func physicalRange(for visibleRange: NSRange) -> NSRange {
    let lowerBound = physicalIndex(for: visibleRange.lowerBound)
    let upperBound = physicalIndex(for: visibleRange.upperBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  // MARK: - Private

  private struct Node {
    var locationOffsetFromPreviousLocation: Int
    let length: Int
    let replacement: [Element]
  }

  // TODO: Replace this with a tree
  private var nodes: [Node] = []

  private struct NodeIndexWithLocation: Comparable {
    let index: Int
    let location: Int

    static func < (lhs: ArrayReplacementCollection.NodeIndexWithLocation, rhs: ArrayReplacementCollection.NodeIndexWithLocation) -> Bool {
      return lhs.index < rhs.index
    }
  }

  private func rangeOfNodes<R: RangeExpression>(overlapping filterRange: R) -> ClosedRange<NodeIndexWithLocation>? where R.Bound == Int {
    let filterRange = filterRange.relative(to: 0 ..< Int.max)
    var result: ClosedRange<NodeIndexWithLocation>?
    var location = 0
    for (i, node) in nodes.enumerated() {
      location += node.locationOffsetFromPreviousLocation
      let range = location ..< location + node.length
      if range.overlaps(filterRange) {
        let augmentedNode = NodeIndexWithLocation(index: i, location: location)
        result = result.flatMap { $0.lowerBound ... augmentedNode } ?? augmentedNode ... augmentedNode
      }
    }
    return result
  }
}

extension ArrayReplacementCollection: RandomAccessCollection {
  public var startIndex: Int { nodes.startIndex }
  public var endIndex: Int { nodes.endIndex }
  public func index(after i: Int) -> Int {
    return i + 1
  }
  public func index(before i: Int) -> Int {
    return i - 1
  }

  // TODO: Ewww, this is O(N)
  public subscript(position: Int) -> Replacement {
    var lowerBound = 0
    for i in 0 ..< position {
      lowerBound += nodes[i].locationOffsetFromPreviousLocation
    }
    lowerBound += nodes[position].locationOffsetFromPreviousLocation
    let upperBound = lowerBound + nodes[position].length
    return Replacement(range: lowerBound ..< upperBound, elements: nodes[position].replacement)
  }
}
