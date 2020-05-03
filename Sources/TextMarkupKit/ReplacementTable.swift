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

/// Stores replacements: NSAttributedString values to substitute for ranges of another NSAttributedString.
final class ReplacementTable {
  /// A single replacement.
  struct Replacement: Equatable {
    /// The range of the original NSAttributedString to replace.
    /// Note that even if you intend to perform multiple replacements in a single NSAttributedString, all of the `range` values
    /// are in terms of the original unaltered NSAttributedString. (e.g., if an "earlier" NSAttributedString would change the length
    /// of the result, "later" replacements don't use the modified indexes.)
    let range: NSRange

    /// The replacement NSAttributedString.
    let replacement: NSAttributedString

    /// Computed value: How much
    var changeInLength: Int { replacement.length - range.length }
  }

  /// Inserts a replacement in the table.
  func insert(_ replacement: Replacement) {
    var previousLocation = 0

    for insertionPoint in 0 ..< nodes.endIndex {
      let nextLocation = previousLocation + nodes[insertionPoint].locationOffsetFromPreviousLocation
      if nextLocation > replacement.range.location {
        let node = Node(
          locationOffsetFromPreviousLocation: replacement.range.location - previousLocation,
          length: replacement.range.length,
          replacement: replacement.replacement
        )
        nodes[insertionPoint].locationOffsetFromPreviousLocation = nextLocation - replacement.range.location
        nodes.insert(node, at: insertionPoint)
      }
      previousLocation = nextLocation
    }
    let node = Node(
      locationOffsetFromPreviousLocation: replacement.range.location - previousLocation,
      length: replacement.range.length,
      replacement: replacement.replacement
    )
    nodes.append(node)
  }

  /// Wow I can't really describe this so I should probably refactor it!
  func wipeCharacters(in range: NSRange, replacementLength: Int) {
    deleteNodes(overlapping: range)
    let changeInLength = replacementLength - range.length
    var previousLocation = 0
    for (i, node) in nodes.enumerated() {
      let nextLocation = previousLocation + node.locationOffsetFromPreviousLocation
      if nextLocation > range.location {
        nodes[i].locationOffsetFromPreviousLocation += changeInLength
        return
      }
      previousLocation = nextLocation
    }
  }

  /// Returns all replacements that apply to the range of the original NSAttributedString.
  func replacements(in filterRange: NSRange) -> [Replacement] {
    var results: [Replacement] = []
    var location = 0
    for node in nodes {
      location += node.locationOffsetFromPreviousLocation
      let range = NSRange(location: location, length: node.length)
      if range.intersection(filterRange) == nil { continue }
      let result = Replacement(range: range, replacement: node.replacement)
      results.append(result)
    }
    return results
  }

  /// Computes the index in the original NSAttributedString for an index in the NSAttributedString with all modifications performed.
  func physicalIndex(for visibleIndex: Int) -> Int {
    var location = 0
    var visibleIndex = visibleIndex
    for node in nodes {
      location += node.locationOffsetFromPreviousLocation
      if visibleIndex >= location + node.replacement.length {
        visibleIndex += node.length - node.replacement.length
      } else {
        break
      }
    }
    return visibleIndex
  }

  func physicalRange(for visibleRange: NSRange) -> NSRange {
    let lowerBound = physicalIndex(for: visibleRange.lowerBound)
    let upperBound = physicalIndex(for: visibleRange.upperBound)
    return NSRange(location: lowerBound, length: upperBound - lowerBound)
  }

  // MARK: - Private

  private struct Node {
    var locationOffsetFromPreviousLocation: Int
    let length: Int
    let replacement: NSAttributedString
  }

  // TODO: Replace this with a tree
  private var nodes: [Node] = []

  private func deleteNodes(overlapping contentRange: NSRange) {
    guard let nodeRange = rangeOfNodes(overlapping: contentRange) else { return }
    if nodeRange.upperBound.index + 1 < nodes.endIndex {
      let targetOffset = nodeRange.upperBound.location + nodes[nodeRange.upperBound.index + 1].locationOffsetFromPreviousLocation
      let priorOffset = nodeRange.lowerBound.location - nodes[nodeRange.lowerBound.index].locationOffsetFromPreviousLocation
      nodes[nodeRange.upperBound.index + 1].locationOffsetFromPreviousLocation = targetOffset - priorOffset
    }
    nodes.removeSubrange(nodeRange.lowerBound.index ..< nodeRange.upperBound.index + 1)
  }

  private struct NodeIndexWithLocation: Comparable {
    let index: Int
    let location: Int

    static func < (lhs: ReplacementTable.NodeIndexWithLocation, rhs: ReplacementTable.NodeIndexWithLocation) -> Bool {
      return lhs.index < rhs.index
    }
  }

  private func rangeOfNodes(overlapping filterRange: NSRange) -> ClosedRange<NodeIndexWithLocation>? {
    var result: ClosedRange<NodeIndexWithLocation>?
    var location = 0
    for (i, node) in nodes.enumerated() {
      location += node.locationOffsetFromPreviousLocation
      let range = NSRange(location: location, length: node.length)
      if range.intersection(filterRange) != nil {
        let augmentedNode = NodeIndexWithLocation(index: i, location: location)
        result = result.flatMap { $0.lowerBound ... augmentedNode } ?? augmentedNode ... augmentedNode
      }
    }
    return result
  }
}
