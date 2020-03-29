// 

import Foundation

public extension CharacterSet {
  func contains(_ scalar: UnicodeScalar?, includesNil: Bool) -> Bool {
    scalar.map(contains) ?? includesNil
  }
}
