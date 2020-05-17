// 

import Foundation
import TextMarkupKit
import XCTest

final class NodeReplacementsTests: XCTestCase {
  private let replacementFunctions: [NodeType: ReplacementFunction] = [
    .headerDelimiter: formatHeader,
    .softTab: formatTab,
  ]

  func testLengthChangingReplacements() {
    let buffer = Array("# Main heading\n\n## Second heading\n\n### Third level header".utf16)
    let memoizationTable = MemoizationTable()
    let tree = try! buffer.parse(grammar: MiniMarkdownGrammar(), memoizationTable: memoizationTable)
    let replacements = tree.computeTextReplacements(using: replacementFunctions)
    XCTAssertEqual(replacements.count, 6)
    var replaced = buffer
    tree.applyTextReplacements(startingIndex: 0, to: &replaced)
    XCTAssertEqual(replaced.string, "H1\tMain heading\n\nH2\tSecond heading\n\nH3\tThird level header")

    // Any character inside a replacement maps to the first character of the replaced range.
    XCTAssertEqual(tree.indexBeforeReplacements(0), 0)
    XCTAssertEqual(tree.indexBeforeReplacements(1), 0)

    // Any character inside a range-to-be-replaced maps to the first character of the replaced range.
    XCTAssertEqual(tree.indexAfterReplacements(0), 0)
    XCTAssertEqual(tree.indexAfterReplacements(16), 17) // first "#" in second heading
    XCTAssertEqual(tree.indexAfterReplacements(17), 17) // second "#" in second heading

    // Do we accurately find the tab?
    XCTAssertEqual(tree.indexAfterReplacements(1), 2)
    XCTAssertEqual(tree.indexBeforeReplacements(2), 1)

    // Make sure indexes round-trip
    for i in buffer.indices {
      let indexAfterReplacement = tree.indexAfterReplacements(i)
      let indexBeforeReplacement = tree.indexBeforeReplacements(indexAfterReplacement)
      let (leaf, offset) = try! tree.leafNode(containing: i)
      if leaf.hasTextReplacement {
        // the round-trip is going to point back to the start of the leaf
        XCTAssertEqual(indexBeforeReplacement, offset)
      } else {
        XCTAssertEqual(indexBeforeReplacement, i)
      }
    }
  }

  func testH3Replacements() {
    let buffer = Array("### Third level header".utf16)
    let memoizationTable = MemoizationTable()
    let tree = try! buffer.parse(grammar: MiniMarkdownGrammar(), memoizationTable: memoizationTable)
    let replacements = tree.computeTextReplacements(using: replacementFunctions)
    XCTAssertEqual(replacements.count, 2)
    var replaced = buffer
    tree.applyTextReplacements(startingIndex: 0, to: &replaced)
    XCTAssertEqual("H3\tThird level header", replaced.string)

    XCTAssertEqual(tree.indexBeforeReplacements(0), 0) // "H"
    XCTAssertEqual(tree.indexBeforeReplacements(1), 0) // "3" -- maps to start of ###
    XCTAssertEqual(tree.indexBeforeReplacements(2), 3) // "\t" -- maps to space
    XCTAssertEqual(tree.indexBeforeReplacements(3), 4) // "T"
    XCTAssertEqual(tree.indexBeforeReplacements(replaced.count - 1), buffer.count - 1) // ends align

    XCTAssertEqual(tree.indexAfterReplacements(0), 0) // "#" -> "H3"
    XCTAssertEqual(tree.indexAfterReplacements(1), 0) // "#"
    XCTAssertEqual(tree.indexAfterReplacements(2), 0) // "#"
    XCTAssertEqual(tree.indexAfterReplacements(3), 2) // " " -> "\t"
    XCTAssertEqual(tree.indexAfterReplacements(4), 3) // "T"
    XCTAssertEqual(tree.indexAfterReplacements(buffer.count - 1), replaced.count - 1)

    // Make sure indexes round-trip
    for i in buffer.indices {
      let indexAfterReplacement = tree.indexAfterReplacements(i)
      let indexBeforeReplacement = tree.indexBeforeReplacements(indexAfterReplacement)
      let (leaf, offset) = try! tree.leafNode(containing: i)
      if leaf.hasTextReplacement {
        // the round-trip is going to point back to the start of the leaf
        XCTAssertEqual(indexBeforeReplacement, offset)
      } else {
        XCTAssertEqual(indexBeforeReplacement, i)
      }
    }
  }
}

extension Array: SafeUnicodeBuffer where Element == unichar {
  public subscript<R>(range: R) -> [unichar] where R : RangeExpression, R.Bound == Int {
    let r = range.relative(to: self)
    var results = [unichar]()
    for i in r {
      results.append(self[i])
    }
    return results
  }

  public subscript(range: NSRange) -> [unichar] {
    return Array(self[range.lowerBound ..< range.upperBound])
  }

  public func utf16(at index: Int) -> unichar? {
    guard index < endIndex else { return nil }
    return self[index]
  }

  public var string: String {
    return String(utf16CodeUnits: self, count: count)
  }
}

private func formatTab(
  node: Node,
  startIndex: Int
) -> [unichar] {
  return Array("\t".utf16)
}

private func formatHeader(
  node: Node,
  startIndex: Int
) -> [unichar] {
  return Array("H\(node.length)".utf16)
}
