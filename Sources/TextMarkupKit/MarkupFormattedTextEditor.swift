//
//  SwiftUIView.swift
//  
//
//  Created by Brian Dewey on 6/22/21.
//

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
