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

import Foundation
import TextMarkupKit
import XCTest

final class MiniMarkdownParsingTests: XCTestCase {
  func testParseHeaderAndBody() {
    let text = """
    # This is a header

    And this is a body.
    The two lines are part of the same paragraph.

    The line break indicates a new paragraph.
    """
    do {
      let tree = try MarkupLanguage.miniMarkdown.parse(text)
      XCTAssertEqual(tree.compactStructure, "(document ((header (delimiter text)) line line line line line))")
    } catch MarkupLanguage.Error.incompleteParsing(let endpoint) {
      XCTFail("Did not parse the entire string. Remaining text: '\(endpoint.string[endpoint.position...].debugDescription)'")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
