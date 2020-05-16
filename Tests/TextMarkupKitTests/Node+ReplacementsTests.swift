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
    let replacementRange = tree.computeTextReplacements(using: replacementFunctions)
    XCTAssertEqual(replacementRange, 0 ..< 39)
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
