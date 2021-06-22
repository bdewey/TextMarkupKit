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
    self.text = string
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
