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

public struct MarkupFormattedTextEditor: UIViewRepresentable {
  public init(text: Binding<String>, style: ParsedAttributedString.Style = MiniMarkdownGrammar.defaultEditingStyle()) {
    self._text = text
    self.style = style
  }

  @Binding public var text: String
  public let style: ParsedAttributedString.Style

  public func makeUIView(context: Context) -> MarkupFormattingTextView {
    let view = MarkupFormattingTextView(parsedAttributedString: ParsedAttributedString(string: text, style: style))
    view.delegate = context.coordinator
    return view
  }

  public func updateUIView(_ uiView: MarkupFormattingTextView, context: Context) {
    uiView.text = text
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  public final class Coordinator: NSObject, UITextViewDelegate {
    @Binding private var text: String

    init(text: Binding<String>) {
      self._text = text
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
      text = textView.text
    }
  }
}
