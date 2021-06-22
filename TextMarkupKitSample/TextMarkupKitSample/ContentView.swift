//
//  ContentView.swift
//  TextMarkupKitSample
//
//  Created by Brian Dewey on 6/22/21.
//

import TextMarkupKit
import SwiftUI

struct ContentView: View {
  @Binding var document: TextMarkupKitSampleDocument

  var body: some View {
    MarkupFormattedTextEditor(text: $document.text)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(document: .constant(TextMarkupKitSampleDocument()))
  }
}
