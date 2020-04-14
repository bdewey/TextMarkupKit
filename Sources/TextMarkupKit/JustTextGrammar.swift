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

/// This is the simplest possible grammar: All content of the buffer gets parsed into a single node typed `text` with no
/// children. This represents the very best parsing performance you could get.
public final class JustTextGrammar: PackratGrammar {
  public static let shared = JustTextGrammar()

  public var start: ParsingRule = ParsingRule.dot.repeating(0...).as(.text)
}
