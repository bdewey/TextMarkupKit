//
//  TextMarkupKitSampleDocument.swift
//  TextMarkupKitSample
//
//  Created by Brian Dewey on 6/22/21.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static var exampleText: UTType {
    UTType(importedAs: "com.example.plain-text")
  }
}

struct TextMarkupKitSampleDocument: FileDocument {
  var text: String

  init(text: String = welcomeContent) {
    self.text = text
  }

  static var readableContentTypes: [UTType] { [.exampleText] }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents,
          let string = String(data: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    text = string
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let data = text.data(using: .utf8)!
    return .init(regularFileWithContents: data)
  }
}

private let welcomeContent = """
# Welcome to TextMarkupKit!

`TextMarkupKit` gives you the tools you need to provide a *format as you type* experience in iOS. Out of the box, it provides support for a subset of Markdown formatting, including:

* **Bold**
* *Italics* (also formatted _this way_)
* `code`

1. Lists can be numbered, too.

## Now you try!

Go ahead and edit this file! You will see the formatting adjust as you type.

## Learning more

Checkout `README.md` inside TextMarkupKit.
"""
