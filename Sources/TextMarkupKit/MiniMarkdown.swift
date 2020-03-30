// 

import Foundation

public extension DocumentParser {
  static let miniMarkdown = DocumentParser(
    subparsers: [Header(), BlankLine()],
    defaultParser: Paragraph()
  )
}
