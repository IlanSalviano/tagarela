import AppKit
import AVFoundation
import IOKit.hid
import os

final class PermissionServiceLive: PermissionService, @unchecked Sendable {
    /// Um continuation por assinante. Um `AsyncStream` compartilhado *divide*
    /// os elementos entre consumidores em vez de duplicá-los — e o app tem dois
    /// (auditoria §5.2).
    private struct Subscribers {
        var byID: [UUID: AsyncStream<PermissionsSnapshot>.Continuation] = [:]
        var latest: PermissionsSnapshot?
    }
    private let subscribers = OSAllocatedUnfairLock(uncheckedState: Subscribers())

    private var task: Task<Void, Never>?
    private let probe: (@Sendable () -> PermissionsSnapshot)?
    private let pollIntervalNs: UInt64

    init(probe: (@Sendable () -> PermissionsSnapshot)? = nil,
         pollIntervalNs: UInt64 = 1_000_000_000) {
        self.probe = probe
        self.pollIntervalNs = pollIntervalNs
        startPolling()
    }

    func makeSnapshots() -> AsyncStream<PermissionsSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<PermissionsSnapshot>.makeStream()
        let known = subscribers.withLock { state -> PermissionsSnapshot? in
            state.byID[id] = continuation
            return state.latest
        }
        continuation.onTermination = { [weak self] _ in
            self?.subscribers.withLock { _ = $0.byID.removeValue(forKey: id) }
        }
        // Quem chega depois recebe o estado atual em vez de esperar a próxima
        // transição — senão o onboarding só reagiria à mudança seguinte.
        if let known { continuation.yield(known) }
        return stream
    }

    private func broadcast(_ snapshot: PermissionsSnapshot) {
        let targets = subscribers.withLock { state -> [AsyncStream<PermissionsSnapshot>.Continuation] in
            state.latest = snapshot
            return Array(state.byID.values)
        }
        for continuation in targets { continuation.yield(snapshot) }
    }

    func snapshot() -> PermissionsSnapshot {
        if let probe { return probe() }
        return PermissionsSnapshot(
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
        let intervalNs = pollIntervalNs
        task = Task { [weak self] in
            var last: PermissionsSnapshot?
            while !Task.isCancelled {
                // `self` é resolvido a cada iteração e sai de escopo antes do
                // sleep: antes, um `guard let self` fora do laço mantinha o
                // serviço vivo para sempre e o `deinit` nunca rodava.
                do {
                    guard let self else { return }
                    let now = self.snapshot()
                    if now != last {
                        self.broadcast(now)
                        last = now
                    }
                }
                try? await Task.sleep(nanoseconds: intervalNs)
            }
        }
    }

    deinit {
        task?.cancel()
        let targets = subscribers.withLock { state -> [AsyncStream<PermissionsSnapshot>.Continuation] in
            let all = Array(state.byID.values)
            state.byID.removeAll()
            return all
        }
        for continuation in targets { continuation.finish() }
    }
}
