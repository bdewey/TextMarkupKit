import XCTest
@testable import TextMarkupKit

final class TextMarkupKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TextMarkupKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
