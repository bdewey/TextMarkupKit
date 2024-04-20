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

import UIKit

public struct HeaderFormatter: ParsedAttributedStringFormatter {
  public func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    guard let headingLevel = node.children.first?.length else {
      assertionFailure()
      return (currentAttributes, nil)
    }
    var attributes = currentAttributes
    switch headingLevel {
    case 1:
      attributes.textStyle = .title2
    case 2:
      attributes.textStyle = .title3
    default:
      attributes.textStyle = .title3
    }
    attributes.listLevel = 1
    return (attributes, nil)
  }
}

public extension MiniMarkdownGrammar {
  /// A style suitable for editing MiniMarkdown text in a UITextView.
  ///
  /// * Headers display with the `title` text style
  /// * Code is monospaced
  /// * Formatting delimiters are shown with `quarternaryLabel` color
  /// * Lists use hanging indents for their bullets
  /// * Unordered lists use a proper bullet character
  /// * Emojis show up appropriately
  static func defaultEditingStyle() -> ParsedAttributedString.Style {
    let defaultAttributes = AttributedStringAttributesDescriptor(textStyle: .body, color: .label, headIndent: 28, firstLineHeadIndent: 28)
    let formatters: [SyntaxTreeNodeType: AnyParsedAttributedStringFormatter] = [
      .header: AnyParsedAttributedStringFormatter(HeaderFormatter()),
      .list: .incrementListLevel,
      .delimiter: .color(.quaternaryLabel),
      .strongEmphasis: .toggleBold,
      .emphasis: .toggleItalic,
      .code: .fontDesign(.monospaced),
      .hashtag: .backgroundColor(.secondarySystemBackground),
      .blockquote: AnyParsedAttributedStringFormatter {
        $0.italic = true
        $0.blockquoteBorderColor = UIColor.systemOrange
        $0.listLevel += 1
      },
      .emoji: AnyParsedAttributedStringFormatter {
        $0.familyName = "Apple Color Emoji"
      },
      .softTab: .substitute("\t"),
      .unorderedListOpening: .substitute("\u{2022}"),
    ]
    return ParsedAttributedString.Style(grammar: MiniMarkdownGrammar(), defaultAttributes: defaultAttributes, formatters: formatters)
  }
}
