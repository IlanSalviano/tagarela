import XCTest
@testable import Tagarela

final class PermissionServiceTests: XCTestCase {
    func test_snapshot_allGranted_isTrue_whenAllGranted() {
        let s = PermissionsSnapshot(microphone: .granted,
                                    accessibility: .granted,
                                    inputMonitoring: .granted)
        XCTAssertTrue(s.allGranted)
    }

    func test_snapshot_allGranted_isFalse_whenAnyMissing() {
        let s = PermissionsSnapshot(microphone: .granted,
                                    accessibility: .needed,
                                    inputMonitoring: .granted)
        XCTAssertFalse(s.allGranted)
    }

    func test_status_codable_roundTrip() throws {
        let s: PermissionStatus = .granted
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(PermissionStatus.self, from: data)
        XCTAssertEqual(s, decoded)
    }
}
