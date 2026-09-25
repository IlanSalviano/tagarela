import XCTest
@testable import Tagarela

final class RuntimeEnvironmentTests: XCTestCase {
    /// The launch guards in `AppContainer` and `TagarelaApp` depend on this.
    /// If a future Xcode changes how it hosts the suite, this fails before the
    /// test host goes back to requesting permissions on the user's machine.
    func test_isRunningTests_isTrueInsideTheSuite() {
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
    }
}
