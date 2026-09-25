import Foundation

/// `xcodebuild test` launches this same app — the Debug `Tagarela.app` — as the
/// test host: same bundle id as the release, different signature. Whatever the
/// app does at launch also happens on every test run, on the user's machine.
/// When the test host was granted the microphone, the grant moved to its
/// signature and the release asked again on its next launch ("Reincidência em
/// 2026-09-24" in `tagarela_docs/04-decisoes/cleanup-fase3.md`).
///
/// True from the start of the process: `Diag` gated its file log on this same
/// check, and the test host of 2026-09-24 23:09 wrote no line to that file.
enum RuntimeEnvironment {
    static let isRunningTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
}
