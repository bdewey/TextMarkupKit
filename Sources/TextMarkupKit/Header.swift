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

extension NodeType {
  public static let header: NodeType = "header"
}

public struct Header: SequenceRecognizer, SentinelContaining {
  public init() {}
  public var sentinels: CharacterSet { CharacterSet(charactersIn: "#") }
  public var type: NodeType { .header }
  public let sequenceRecognizer = Node.sequence(of: [
    Node.text(matching: { $0 == unichar.octothorpe }, named: "delimiter"),
    Node.text(matching: { CharacterSet.whitespaces.contains(Unicode.Scalar($0)!) }),
    Node.text(upToAndIncluding: unichar.newline, named: "text"),
  ])
}