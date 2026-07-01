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

import Logging

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

#if canImport(UIKit) || canImport(AppKit)

  private let logger = Logger(label: "org.brians-brain.AttributedStringAttributes")

  public typealias AttributedStringAttributes = [NSAttributedString.Key: Any]

  #if canImport(UIKit)
    public typealias TextMarkupKitFont = UIFont
    public typealias TextMarkupKitFontDescriptor = UIFontDescriptor
    public typealias TextMarkupKitFontDesign = UIFontDescriptor.SystemDesign
    public typealias TextMarkupKitTextStyle = UIFont.TextStyle
    public typealias TextMarkupKitColor = UIColor
    public typealias TextMarkupKitTextAttachment = NSTextAttachment
  #elseif canImport(AppKit)
    public typealias TextMarkupKitFont = NSFont
    public typealias TextMarkupKitFontDescriptor = NSFontDescriptor
    public typealias TextMarkupKitColor = NSColor
    public typealias TextMarkupKitTextAttachment = NSTextAttachment

    public enum TextMarkupKitFontDesign: Hashable {
      case `default`
      case monospaced
    }

    public enum TextMarkupKitTextStyle: Hashable {
      case body
      case title2
      case title3

      var defaultPointSize: CGFloat {
        switch self {
        case .body:
          return NSFont.systemFontSize
        case .title2:
          return 22
        case .title3:
          return 20
        }
      }
    }
  #endif

  public extension NSAttributedString.Key {
    /// A platform color to use when rendering a vertical bar on the leading edge of a block quote.
    static let blockquoteBorderColor = NSAttributedString.Key(rawValue: "verticalBarColor")
  }

  public struct AttributedStringAttributesDescriptor: Hashable {
    public init(textStyle: TextMarkupKitTextStyle = .body, familyName: String? = nil, fontSize: CGFloat = 0, color: TextMarkupKitColor? = nil, backgroundColor: TextMarkupKitColor? = nil, blockquoteBorderColor: TextMarkupKitColor? = nil, kern: CGFloat = 0, bold: Bool = false, italic: Bool = false, headIndent: CGFloat = 0, firstLineHeadIndent: CGFloat = 0, alignment: NSTextAlignment? = nil, lineHeightMultiple: CGFloat = 0, listLevel: Int = 0, attachment: TextMarkupKitTextAttachment? = nil) {
      self.textStyle = textStyle
      self.familyName = familyName
      self.fontSize = fontSize
      self.color = color
      self.backgroundColor = backgroundColor
      self.blockquoteBorderColor = blockquoteBorderColor
      self.kern = kern
      self.bold = bold
      self.italic = italic
      self.headIndent = headIndent
      self.firstLineHeadIndent = firstLineHeadIndent
      self.alignment = alignment
      self.lineHeightMultiple = lineHeightMultiple
      self.listLevel = listLevel
      self.attachment = attachment
    }

    public var textStyle: TextMarkupKitTextStyle = .body {
      didSet {
        fontSize = Self.defaultPointSize(for: textStyle)
      }
    }

    public var familyName: String?
    public var fontSize: CGFloat = 0
    public var fontDesign: TextMarkupKitFontDesign = .default
    public var color: TextMarkupKitColor?
    public var backgroundColor: TextMarkupKitColor?
    public var blockquoteBorderColor: TextMarkupKitColor?
    public var kern: CGFloat = 0
    public var bold: Bool = false
    public var italic: Bool = false
    public var headIndent: CGFloat = 0
    public var firstLineHeadIndent: CGFloat = 0
    public var alignment: NSTextAlignment?
    public var lineHeightMultiple: CGFloat = 0
    public var listLevel: Int = 0
    public var attachment: TextMarkupKitTextAttachment?

    public func makeAttributes() -> AttributedStringAttributes {
      var attributes: AttributedStringAttributes = [
        .font: makeFont(),
        .paragraphStyle: makeParagraphStyle(),
        .kern: kern,
      ]
      color.flatMap { attributes[.foregroundColor] = $0 }
      backgroundColor.flatMap { attributes[.backgroundColor] = $0 }
      blockquoteBorderColor.flatMap { attributes[.blockquoteBorderColor] = $0 }
      attachment.flatMap { attributes[.attachment] = $0 }
      return attributes
    }

    private func makeFont() -> TextMarkupKitFont {
      var fontAttributes = [TextMarkupKitFontDescriptor.AttributeName: Any]()
      var size = fontSize
      // Set EITHER the family name or the text style, but not both
      if let familyName = familyName {
        fontAttributes[.family] = familyName
        if size == 0 {
          size = Self.defaultPointSize(for: .body)
        }
      } else {
        #if canImport(UIKit)
          fontAttributes[.textStyle] = textStyle
        #endif
        if size == 0 {
          size = Self.defaultPointSize(for: textStyle)
        }
      }
      var fontDescriptor = TextMarkupKitFontDescriptor(fontAttributes: fontAttributes).withDesignIfPossible(fontDesign)
      if italic { fontDescriptor = fontDescriptor.withTextMarkupKitSymbolicTraits(.textMarkupKitItalic) }
      if bold { fontDescriptor = fontDescriptor.withTextMarkupKitSymbolicTraits(.textMarkupKitBold) }
      return TextMarkupKitFont.make(descriptor: fontDescriptor, size: size)
    }

    private static func defaultPointSize(for textStyle: TextMarkupKitTextStyle) -> CGFloat {
      #if canImport(UIKit)
        return TextMarkupKitFont.preferredFont(forTextStyle: textStyle).pointSize
      #else
        return textStyle.defaultPointSize
      #endif
    }

    private func makeParagraphStyle() -> NSParagraphStyle {
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.headIndent = headIndent
      paragraphStyle.firstLineHeadIndent = firstLineHeadIndent
      alignment.flatMap { paragraphStyle.alignment = $0 }
      paragraphStyle.lineHeightMultiple = lineHeightMultiple
      if listLevel > 0 {
        let indentAmountPerLevel: CGFloat = headIndent > 0 ? headIndent : 16
        paragraphStyle.headIndent = indentAmountPerLevel * CGFloat(listLevel)
        paragraphStyle.firstLineHeadIndent = indentAmountPerLevel * CGFloat(listLevel - 1)
        var tabStops: [NSTextTab] = []
        for i in 0 ..< 4 {
          let listTab = NSTextTab(
            textAlignment: .natural,
            location: paragraphStyle.headIndent + CGFloat(i) * indentAmountPerLevel,
            options: [:]
          )
          tabStops.append(listTab)
        }
        paragraphStyle.tabStops = tabStops
      }
      return paragraphStyle
    }
  }

  /// Convenience extensions for working with an NSAttributedString attributes dictionary.
  public extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    /// The font attribute.
    var font: TextMarkupKitFont {
      get { return (self[.font] as? TextMarkupKitFont) ?? TextMarkupKitFont.defaultBodyFont }
      set { self[.font] = newValue }
    }

    /// Setter only: Sets a dynamic font
    var textStyle: TextMarkupKitTextStyle? {
      get { return nil }
      set {
        if let textStyle = newValue {
          self[.font] = TextMarkupKitFont.defaultFont(forTextStyle: textStyle)
        } else {
          self[.font] = nil
        }
      }
    }

    /// the font family name
    var familyName: String {
      get {
        return font.familyName ?? font.fontName
      }
      set {
        font = TextMarkupKitFont.make(descriptor: font.fontDescriptor.withoutStyle().withFamily(newValue), size: 0)
      }
    }

    var fontSize: CGFloat {
      get {
        return font.pointSize
      }
      set {
        font = TextMarkupKitFont.make(descriptor: font.fontDescriptor.withSize(newValue), size: 0)
      }
    }

    /// Text foreground color.
    var color: TextMarkupKitColor? {
      get { return self[.foregroundColor] as? TextMarkupKitColor }
      set { self[.foregroundColor] = newValue }
    }

    /// Text background color.
    var backgroundColor: TextMarkupKitColor? {
      get { return self[.backgroundColor] as? TextMarkupKitColor }
      set { self[.backgroundColor] = newValue }
    }

    /// A color to use when drawing a vertical bar to the left side of block quotes
    var blockquoteBorderColor: TextMarkupKitColor? {
      get { return self[.blockquoteBorderColor] as? TextMarkupKitColor }
      set { self[.blockquoteBorderColor] = newValue }
    }

    /// Desired letter spacing.
    var kern: CGFloat {
      get { return self[.kern] as? CGFloat ?? 0 }
      set { self[.kern] = newValue }
    }

    /// Whether the font is bold.
    var bold: Bool {
      get { return containsSymbolicTrait(.textMarkupKitBold) }
      set {
        if newValue {
          symbolicTraitFormUnion(.textMarkupKitBold)
        } else {
          symbolicTraitSubtract(.textMarkupKitBold)
        }
      }
    }

    /// Whether the font is italic.
    var italic: Bool {
      get { return containsSymbolicTrait(.textMarkupKitItalic) }
      set {
        if newValue {
          symbolicTraitFormUnion(.textMarkupKitItalic)
        } else {
          symbolicTraitSubtract(.textMarkupKitItalic)
        }
      }
    }

    /// Tests if the font contains a given symbolic trait.
    func containsSymbolicTrait(_ symbolicTrait: TextMarkupKitFontDescriptor.SymbolicTraits) -> Bool {
      return font.fontDescriptor.symbolicTraits.contains(symbolicTrait)
    }

    /// Sets a symbolic trait.
    mutating func symbolicTraitFormUnion(_ symbolicTrait: TextMarkupKitFontDescriptor.SymbolicTraits) {
      symbolicTraits = font.fontDescriptor.symbolicTraits.union(symbolicTrait)
    }

    /// Clears a symbolic trait.
    mutating func symbolicTraitSubtract(_ symbolicTrait: TextMarkupKitFontDescriptor.SymbolicTraits) {
      symbolicTraits = font.fontDescriptor.symbolicTraits.subtracting(symbolicTrait)
    }

    /// The symbolic traits for the font. Can be nil if there is no font.
    /// Attempts to set the symbolic traits to nil will be ignored.
    var symbolicTraits: TextMarkupKitFontDescriptor.SymbolicTraits {
      get {
        return font.fontDescriptor.symbolicTraits
      }
      set {
        font = TextMarkupKitFont.make(descriptor: font.fontDescriptor.withTextMarkupKitSymbolicTraits(newValue), size: 0)
      }
    }

    private var paragraphStyle: NSParagraphStyle? {
      get { return self[.paragraphStyle] as? NSParagraphStyle }
      set { self[.paragraphStyle] = newValue }
    }

    private var mutableParagraphStyle: NSMutableParagraphStyle {
      if let paragraphStyle = paragraphStyle {
        // swiftlint:disable:next force_cast
        return paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
      } else {
        return NSMutableParagraphStyle()
      }
    }

    var headIndent: CGFloat {
      get { return paragraphStyle?.headIndent ?? 0 }
      set {
        let style = mutableParagraphStyle
        style.headIndent = newValue
        paragraphStyle = style
      }
    }

    var tailIndent: CGFloat {
      get { return paragraphStyle?.tailIndent ?? 0 }
      set {
        let style = mutableParagraphStyle
        style.tailIndent = newValue
        paragraphStyle = style
      }
    }

    var firstLineHeadIndent: CGFloat {
      get { return paragraphStyle?.firstLineHeadIndent ?? 0 }
      set {
        let style = mutableParagraphStyle
        style.firstLineHeadIndent = newValue
        paragraphStyle = style
      }
    }

    var alignment: NSTextAlignment {
      get { return paragraphStyle?.alignment ?? NSParagraphStyle.default.alignment }
      set {
        let style = mutableParagraphStyle
        style.alignment = newValue
        paragraphStyle = style
      }
    }

    var lineHeightMultiple: CGFloat {
      get { return paragraphStyle?.lineHeightMultiple ?? 0 }
      set {
        let style = mutableParagraphStyle
        style.lineHeightMultiple = newValue
        paragraphStyle = style
      }
    }

    var listLevel: Int {
      get { return self[.listLevel] as? Int ?? 0 }
      set {
        self[.listLevel] = newValue
        let indentAmountPerLevel: CGFloat = headIndent > 0 ? headIndent : 16
        let listStyling = mutableParagraphStyle
        if listLevel > 0 {
          listStyling.headIndent = indentAmountPerLevel * CGFloat(listLevel)
          listStyling.firstLineHeadIndent = indentAmountPerLevel * CGFloat(listLevel - 1)
          var tabStops: [NSTextTab] = []
          for i in 0 ..< 4 {
            let listTab = NSTextTab(
              textAlignment: .natural,
              location: listStyling.headIndent + CGFloat(i) * indentAmountPerLevel,
              options: [:]
            )
            tabStops.append(listTab)
          }
          listStyling.tabStops = tabStops
        } else {
          listStyling.headIndent = 0
          listStyling.firstLineHeadIndent = 0
          listStyling.tabStops = []
        }
        paragraphStyle = listStyling
      }
    }
  }

  private extension TextMarkupKitFontDescriptor {
    /// Returns a copy of the receiver without any .textStyle attribute.
    /// .textStyle takes precedence over familyName, so you need to remove the attribute if you want to customize the family.
    func withoutStyle() -> TextMarkupKitFontDescriptor {
      var attributes = fontAttributes
      #if canImport(UIKit)
        attributes.removeValue(forKey: .textStyle)
      #endif
      return TextMarkupKitFontDescriptor(fontAttributes: attributes)
    }

    func withDesignIfPossible(_ design: TextMarkupKitFontDesign) -> TextMarkupKitFontDescriptor {
      #if canImport(UIKit)
        if let newDescriptor = withDesign(design) {
          return newDescriptor
        } else {
          return self
        }
      #else
        switch design {
        case .default:
          return self
        case .monospaced:
          return TextMarkupKitFontDescriptor(fontAttributes: [.family: "Menlo"])
        }
      #endif
    }

    func withTextMarkupKitSymbolicTraits(_ symbolicTraits: SymbolicTraits) -> TextMarkupKitFontDescriptor {
      #if canImport(UIKit)
        return withSymbolicTraits(symbolicTraits) ?? self
      #else
        return withSymbolicTraits(symbolicTraits)
      #endif
    }
  }

  private extension TextMarkupKitFont {
    static var defaultBodyFont: TextMarkupKitFont {
      defaultFont(forTextStyle: .body)
    }

    static func defaultFont(forTextStyle textStyle: TextMarkupKitTextStyle) -> TextMarkupKitFont {
      #if canImport(UIKit)
        return preferredFont(forTextStyle: textStyle)
      #else
        return systemFont(ofSize: textStyle.defaultPointSize)
      #endif
    }

    static func make(descriptor: TextMarkupKitFontDescriptor, size: CGFloat) -> TextMarkupKitFont {
      #if canImport(UIKit)
        return TextMarkupKitFont(descriptor: descriptor, size: size)
      #else
        return TextMarkupKitFont(descriptor: descriptor, size: size) ?? systemFont(ofSize: size)
      #endif
    }
  }

  private extension TextMarkupKitFontDescriptor.SymbolicTraits {
    static var textMarkupKitBold: Self {
      #if canImport(UIKit)
        return .traitBold
      #else
        return .bold
      #endif
    }

    static var textMarkupKitItalic: Self {
      #if canImport(UIKit)
        return .traitItalic
      #else
        return .italic
      #endif
    }
  }

  public extension TextMarkupKitColor {
    static var textMarkupKitLabel: TextMarkupKitColor {
      #if canImport(UIKit)
        return .label
      #else
        return .labelColor
      #endif
    }

    static var textMarkupKitQuaternaryLabel: TextMarkupKitColor {
      #if canImport(UIKit)
        return .quaternaryLabel
      #else
        return .quaternaryLabelColor
      #endif
    }

    static var textMarkupKitSecondarySystemBackground: TextMarkupKitColor {
      #if canImport(UIKit)
        return .secondarySystemBackground
      #else
        return .windowBackgroundColor
      #endif
    }

    static var textMarkupKitSystemOrange: TextMarkupKitColor {
      #if canImport(UIKit)
        return .systemOrange
      #else
        return .systemOrange
      #endif
    }
  }

  private extension NSAttributedString.Key {
    static let listLevel = NSAttributedString.Key(rawValue: "org.brians-brain.list-level")
  }

#endif
