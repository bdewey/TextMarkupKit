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
import MobileCoreServices
import ObjectiveCTextStorageWrapper
import os
import UIKit
import UniformTypeIdentifiers

private let log = OSLog(subsystem: "org.brians-brain.TextMarkupKit", category: "MarkupFormattingTextView")

private extension Logging.Logger {
  static let textView: Logging.Logger = {
    var logger = Logger(label: "org.brians-brain.TextMarkupKit")
    logger.logLevel = .info
    return logger
  }()
}

/// A protocol that the text views use to store images on paste
public protocol MarkupFormattingTextViewImageStorage {
  /// Store image data.
  /// - parameter imageData: The image data to store
  /// - parameter type: The type of image data (e.g., `UTType.png` or `UTType.jpeg`
  /// - returns: A string that represents this image in the markup language.
  @MainActor func storeImageData(_ imageData: Data, type: UTType) throws -> String
}

/// A UITextView subclass that uses a `ParsedAttributedString` for text storage and formatting.
public final class MarkupFormattingTextView: UITextView {
  /// Creates a `MarkupFormattingTextView` that uses `parsedAttributedString` as its textStorage.
  ///
  /// - Parameter parsedAttributedString: The `ParsedAttributedString` to use for text storage and formatting.
  /// - Parameter layoutManager: Optional custom NSLayoutManager to use.
  public init(
    parsedAttributedString: ParsedAttributedString,
    layoutManager: NSLayoutManager = NSLayoutManager()
  ) {
    self.parsedAttributedString = parsedAttributedString
    self.storage = ObjectiveCTextStorageWrapper(storage: parsedAttributedString)
    let layoutManager = layoutManager
    storage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    layoutManager.addTextContainer(textContainer)
    super.init(frame: .zero, textContainer: textContainer)
    pasteConfiguration = UIPasteConfiguration(
      acceptableTypeIdentifiers: [
        kUTTypeJPEG as String,
        kUTTypePNG as String,
        kUTTypeImage as String,
        kUTTypePlainText as String,
      ]
    )
  }

  /// An object that can store pasted image data.
  public var imageStorage: MarkupFormattingTextViewImageStorage?

  /// The `ParsedAttributedString` used for text storage and formatting.
  public let parsedAttributedString: ParsedAttributedString

  /// A private wrapper around `parsedAttributedString` for efficient interaction with TextKit.
  private let storage: ObjectiveCTextStorageWrapper

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override public func copy(_ sender: Any?) {
    guard let textStorage = textStorage as? ObjectiveCTextStorageWrapper, let parsedAttributedString = textStorage.storage as? ParsedAttributedString else {
      Logger.textView.error("Expected to get a ParsedAttributedString")
      return
    }
    let rawTextRange = parsedAttributedString.rawStringRange(forRange: selectedRange)
    let characters = parsedAttributedString.rawString[rawTextRange]
    UIPasteboard.general.string = String(utf16CodeUnits: characters, count: characters.count)
  }

  override public func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
    Logger.textView.info("Determining if we can paste from \(itemProviders)")
    let typeIdentifiers = pasteConfiguration!.acceptableTypeIdentifiers
    for itemProvider in itemProviders {
      for typeIdentifier in typeIdentifiers where itemProvider.hasItemConformingToTypeIdentifier(typeIdentifier) {
        Logger.textView.info("Item provider has type \(typeIdentifier) so we can paste")
        return true
      }
    }
    return false
  }

  override public func paste(itemProviders: [NSItemProvider]) {
    Logger.textView.info("Pasting \(itemProviders)")
    super.paste(itemProviders: itemProviders)
  }

  override public func paste(_ sender: Any?) {
    if let image = UIPasteboard.general.image, let imageStorage = imageStorage {
      Logger.textView.info("Pasting an image")
      let imageKey: String?
      if let jpegData = UIPasteboard.general.data(forPasteboardType: UTType.jpeg.identifier) {
        Logger.textView.info("Got JPEG data = \(jpegData.count) bytes")
        imageKey = try? imageStorage.storeImageData(jpegData, type: .jpeg)
      } else if let pngData = UIPasteboard.general.data(forPasteboardType: UTType.png.identifier) {
        Logger.textView.info("Got PNG data = \(pngData.count) bytes")
        imageKey = try? imageStorage.storeImageData(pngData, type: .png)
      } else if let convertedData = image.jpegData(compressionQuality: 0.8) {
        Logger.textView.info("Did JPEG conversion ourselves = \(convertedData.count) bytes")
        imageKey = try? imageStorage.storeImageData(convertedData, type: .jpeg)
      } else {
        Logger.textView.error("Could not get image data")
        imageKey = nil
      }
      if let imageKey = imageKey {
        textStorage.replaceCharacters(in: selectedRange, with: imageKey)
      }
    } else {
      Logger.textView.info("Using superclass to paste text")
      super.paste(sender)
    }
  }

  override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(paste(_:)), UIPasteboard.general.image != nil {
      Logger.textView.info("There's an image on the pasteboard, so allow pasting")
      return true
    }
    return super.canPerformAction(action, withSender: sender)
  }

  override public func insertText(_ text: String) {
    os_signpost(.begin, log: log, name: "keystroke")
    super.insertText(text)
    os_signpost(.end, log: log, name: "keystroke")
  }
}
