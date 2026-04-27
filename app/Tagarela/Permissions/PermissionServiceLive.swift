import AppKit
import AVFoundation
import IOKit.hid
import OSLog

final class PermissionServiceLive: PermissionService, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "Permissions")
    nonisolated(unsafe) private var continuation: AsyncStream<PermissionsSnapshot>.Continuation?
    let snapshots: AsyncStream<PermissionsSnapshot>
    private var task: Task<Void, Never>?

    init() {
        var contRef: AsyncStream<PermissionsSnapshot>.Continuation!
        self.snapshots = AsyncStream { continuation in
            contRef = continuation
        }
        self.continuation = contRef
        startPolling()
    }

    func snapshot() -> PermissionsSnapshot {
        PermissionsSnapshot(
            microphone: micStatus(),
            accessibility: AXIsProcessTrusted() ? .granted : .needed,
            inputMonitoring: inputMonitoringStatus()
        )
    }

    func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    private func micStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .needed
        @unknown default: return .unknown
        }
    }

    private func inputMonitoringStatus() -> PermissionStatus {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch access {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .needed
        }
    }

    private func startPolling() {
        task = Task { [weak self] in
            guard let self else { return }
            var last: PermissionsSnapshot?
            while !Task.isCancelled {
                let now = self.snapshot()
                if now != last {
                    self.continuation?.yield(now)
                    last = now
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    deinit { task?.cancel(); continuation?.finish() }
}
