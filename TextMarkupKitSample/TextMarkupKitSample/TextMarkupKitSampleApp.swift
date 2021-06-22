//
//  TextMarkupKitSampleApp.swift
//  TextMarkupKitSample
//
//  Created by Brian Dewey on 6/22/21.
//

import SwiftUI

@main
struct TextMarkupKitSampleApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: TextMarkupKitSampleDocument()) { file in
      ContentView(document: file.$document)
    }
  }
}
