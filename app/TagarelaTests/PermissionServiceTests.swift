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

// MARK: - Fase 5: multicast

extension PermissionServiceTests {
    /// Auditoria §5.2: `snapshots` era um único `AsyncStream` iterado por dois
    /// consumidores (`AppContainer` e `OnboardingCoordinator`, este criado em
    /// todo launch). `AsyncStream` **divide** os elementos entre consumidores em
    /// vez de duplicá-los, então o checklist do onboarding perdia cerca de
    /// metade das transições de permissão.
    func test_makeSnapshots_deliversEveryUpdateToEverySubscriber() async {
        let probe = MutableSnapshot()
        let service = PermissionServiceLive(probe: { probe.current }, pollIntervalNs: 10_000_000)

        let first = SnapshotCollector()
        let second = SnapshotCollector()
        let streamA = service.makeSnapshots()
        let streamB = service.makeSnapshots()
        let taskA = Task { for await snap in streamA { await first.add(snap) } }
        let taskB = Task { for await snap in streamB { await second.add(snap) } }
        defer { taskA.cancel(); taskB.cancel() }

        let sequence: [PermissionsSnapshot] = [
            .init(microphone: .granted, accessibility: .needed,  inputMonitoring: .needed),
            .init(microphone: .granted, accessibility: .granted, inputMonitoring: .needed),
            .init(microphone: .granted, accessibility: .granted, inputMonitoring: .granted),
            .init(microphone: .denied,  accessibility: .granted, inputMonitoring: .granted),
        ]
        for snap in sequence {
            probe.current = snap
            try? await Task.sleep(nanoseconds: 60_000_000)
        }

        for _ in 0..<50 {
            if await first.count >= sequence.count, await second.count >= sequence.count { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let gotA = await first.items
        let gotB = await second.items
        for snap in sequence {
            XCTAssertTrue(gotA.contains(snap), "assinante A perdeu \(snap); recebeu \(gotA.count)")
            XCTAssertTrue(gotB.contains(snap), "assinante B perdeu \(snap); recebeu \(gotB.count)")
        }
    }
}

private actor SnapshotCollector {
    private(set) var items: [PermissionsSnapshot] = []
    var count: Int { items.count }
    func add(_ snapshot: PermissionsSnapshot) { items.append(snapshot) }
}

private final class MutableSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var value = PermissionsSnapshot(microphone: .needed,
                                            accessibility: .needed,
                                            inputMonitoring: .needed)
    var current: PermissionsSnapshot {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}
