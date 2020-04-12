// 

import Foundation

/// Used for tracing the execution of rules.
public final class TraceBuffer: CustomStringConvertible {

  /// All completed test entries.
  public var traceEntries: [Entry] = []

  /// Start working on an entry.
  public func pushEntry(_ entry: Entry) {
    entryStack.append(entry)
  }

  /// Finish the most recent entry
  public func popEntry() {
    guard let popped = entryStack.popLast() else {
      assertionFailure()
      return
    }
    if let last = entryStack.last {
      last.subentries.append(popped)
    } else {
      traceEntries.append(popped)
    }
  }

  /// All in-progress entries
  private var entryStack: [Entry] = []

  public var description: String {
    traceEntries.enumerated().map { index, entry in
      "\(index):\n\(entry)\n\n"
    }.joined()
  }

  public final class Entry: CustomStringConvertible {
    public init(rule: ParsingRule, index: Int, locationHint: String) {
      self.rule = rule
      self.index = index
      self.locationHint = locationHint
    }

    public let rule: ParsingRule
    public let index: Int
    public let locationHint: String
    public var result: ParsingResult?
    public var subentries: [Entry] = []

    public var description: String {
      var buffer = ""
      writeRecursiveDescription(to: &buffer, indexPath: [], maxLevel: 2)
      return buffer
    }

    public var fullDescription: String {
      var buffer = ""
      writeRecursiveDescription(to: &buffer, indexPath: [])
      return buffer
    }

    private func writeRecursiveDescription(to buffer: inout String, indexPath: IndexPath, maxLevel: Int = Int.max) {
      let indentLevel = indexPath.count
      guard indentLevel <= maxLevel else { return }
      let space = String(repeating: "| ", count: indentLevel)
      buffer.append("\(space)+ \(rule)@\(index): \(locationHint) \(indexPath)\n")
      for (index, subentry) in subentries.enumerated() {
        subentry.writeRecursiveDescription(to: &buffer, indexPath: indexPath.appending(index), maxLevel: maxLevel)
      }
      let resultString = result.map(String.init(describing:)) ?? "nil"
      buffer.append("\(space)= \(rule)@\(index): \(resultString)\n")
    }
  }


}
