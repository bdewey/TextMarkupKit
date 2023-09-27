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

/// Determines the attributes and optional replacement text for parsed text in a string.
public protocol ParsedAttributedStringFormatter {
  func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?)
}

/// Can perform simple attribute modifications and string substitutions that do not depend upon the actual contents of the parsed string.
public struct AnyParsedAttributedStringFormatter: ParsedAttributedStringFormatter {
  public init(
    _ wrappedFormatter: ParsedAttributedStringFormatter? = nil,
    substitution: String? = nil,
    formattingFunction: @escaping (inout AttributedStringAttributesDescriptor) -> Void = { _ in /* nothing */ }
  ) {
    self.wrappedFormatter = wrappedFormatter
    self.substitution = substitution
    self.formattingFunction = formattingFunction
  }

  public let wrappedFormatter: ParsedAttributedStringFormatter?

  /// The substitution string to use for this node, or nil if the text should remain unchanged.
  public let substitution: String?

  /// Modifies the current attributes.
  public let formattingFunction: (inout AttributedStringAttributesDescriptor) -> Void

  public func formatNode(
    _ node: SyntaxTreeNode,
    in buffer: SafeUnicodeBuffer,
    at offset: Int,
    currentAttributes: AttributedStringAttributesDescriptor
  ) -> (attributes: AttributedStringAttributesDescriptor, replacementCharacters: [unichar]?) {
    var (attributes, replacementCharacters) = wrappedFormatter?.formatNode(node, in: buffer, at: offset, currentAttributes: currentAttributes) ?? (currentAttributes, nil)
    formattingFunction(&attributes)
    return (attributes, replacementCharacters ?? substitution.flatMap { Array($0.utf16) })
  }
}

/// Some common formatters.
public extension AnyParsedAttributedStringFormatter {
  /// A simple formatter that does nothing.
  static let passthrough = AnyParsedAttributedStringFormatter()

  static let toggleItalic = AnyParsedAttributedStringFormatter { $0.italic.toggle() }
  static let toggleBold = AnyParsedAttributedStringFormatter { $0.bold.toggle() }
  static func fontDesign(_ fontDesign: UIFontDescriptor.SystemDesign) -> AnyParsedAttributedStringFormatter {
    AnyParsedAttributedStringFormatter { $0.fontDesign = fontDesign }
  }

  static let remove = AnyParsedAttributedStringFormatter(substitution: "")
  static let unselectable = AnyParsedAttributedStringFormatter { $0.isUnselectable = true }
  static let incrementListLevel = AnyParsedAttributedStringFormatter { $0.listLevel += 1 }
  static func color(_ color: UIColor?) -> AnyParsedAttributedStringFormatter {
    AnyParsedAttributedStringFormatter { $0.color = color }
  }

  static func backgroundColor(_ color: UIColor?) -> AnyParsedAttributedStringFormatter {
    AnyParsedAttributedStringFormatter { $0.backgroundColor = color }
  }

  static func substitute(_ substitution: String) -> AnyParsedAttributedStringFormatter {
    AnyParsedAttributedStringFormatter(substitution: substitution)
  }
}
