    import XCTest
    @testable import SwiftRestTools

    final class SwiftRestToolsTests: XCTestCase {
        func testExample() {
            let client = RestClient(baseURL: "www.google.com")
            XCTAssert(client != nil)
        }
    }
