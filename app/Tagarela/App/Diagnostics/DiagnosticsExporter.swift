import AppKit
import AVFoundation
import CoreGraphics
import IOKit.hid

/// Junta num diretório só tudo que a próxima investigação vai querer: o log
/// rotativo, um retrato do estado do app e o `vmmap -summary` do processo.
///
/// Substitui na prática o botão "Abrir logs no Console", que a auditoria de
/// 2026-09-07 mostrou ser inútil para falhas de dias atrás — o log unificado
/// já as descartou.
///
/// Nada de segredo entra aqui: a API key mora no Keychain e nunca é lida, e o
/// texto ditado nunca chega ao log (ver `Diag`).
@MainActor
enum DiagnosticsExporter {
    struct Context {
        var health: PipelineHealth?
        var prefs: PreferencesStore?
        var loadedModelName: String?
        var modelDownloaded: Bool?

        init(health: PipelineHealth? = nil,
             prefs: PreferencesStore? = nil,
             loadedModelName: String? = nil,
             modelDownloaded: Bool? = nil) {
            self.health = health
            self.prefs = prefs
            self.loadedModelName = loadedModelName
            self.modelDownloaded = modelDownloaded
        }
    }

    @discardableResult
    static func export(_ context: Context = Context(),
                       log: DiagnosticsLog = .shared,
                       destination: URL? = nil,
                       reveal: Bool = true,
                       audioInput: @MainActor () -> [String] = DiagnosticsExporter.liveAudioInput) throws -> URL {
        let fm = FileManager.default
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd-HHmmss"
        let base = destination ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let folder = base.appendingPathComponent("tagarela-diagnostico-\(stamp.string(from: Date()))",
                                                 isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        // 1. Log rotativo (o que existir).
        for index in 0..<3 {
            let source = log.fileURL(index: index)
            guard fm.fileExists(atPath: source.path) else { continue }
            try? fm.copyItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
        }

        // 2. Retrato do estado.
        try snapshot(context, audioInput: audioInput)
            .write(to: folder.appendingPathComponent("snapshot.txt"), atomically: true, encoding: .utf8)

        // 3. vmmap — best-effort: falha (ou demora) não pode impedir a exportação.
        if let vmmap = runVmmap() {
            try? vmmap.write(to: folder.appendingPathComponent("vmmap.txt"),
                             atomically: true, encoding: .utf8)
        }

        Diag.notice(.health, "diagnóstico exportado para \(folder.lastPathComponent)")
        if reveal { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
        return folder
    }

    static func snapshot(_ context: Context,
                         audioInput: @MainActor () -> [String] = DiagnosticsExporter.liveAudioInput) -> String {
        var out: [String] = []
        func section(_ title: String) { out.append(""); out.append("## \(title)") }

        let info = Bundle.main.infoDictionary
        out.append("# tagarela — snapshot de diagnóstico")
        out.append("gerado: \(ISO8601DateFormatter().string(from: Date()))")
        out.append("versão: \(info?["CFBundleShortVersionString"] as? String ?? "?") "
                   + "(build \(info?["CFBundleVersion"] as? String ?? "?"))")
        out.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        out.append("pid: \(ProcessInfo.processInfo.processIdentifier)")

        section("saúde")
        if let health = context.health {
            out.append("uptime do app: \(health.uptimeLabel) (desde \(health.launchedAt))")
            out.append("gravações: \(health.recordings)")
            out.append("descartadas por buffer curto: \(health.discardedShort)")
            out.append("transcrições vazias: \(health.emptyTranscriptions) "
                       + "(seguidas agora: \(health.consecutiveEmpty))")
            out.append("colas falhas: \(health.injectionFailures)")
            out.append("recuperações automáticas: \(health.recoveries)")
            out.append("último sucesso: \(health.lastSuccessAt.map(String.init(describing:)) ?? "nenhum")")
        } else {
            out.append("(indisponível)")
        }

        section("modelo")
        out.append("carregado: \(context.loadedModelName ?? "nenhum")")
        out.append("presente em disco: \(context.modelDownloaded.map { $0 ? "sim" : "não" } ?? "?")")

        section("preferências (sem segredos)")
        if let prefs = context.prefs {
            out.append("refinerKind: \(prefs.refinerKind.rawValue)")
            out.append("whisperModelName: \(prefs.whisperModelName)")
            out.append("transcriptionLanguage: \(prefs.transcriptionLanguage.rawValue)")
            out.append("ollamaBaseURL: \(prefs.ollamaBaseURL)")
            out.append("ollamaModel: \(prefs.ollamaModel)")
            out.append("openAIModel: \(prefs.openAIModel)")
            out.append("refinerTimeoutSec: \(prefs.refinerTimeoutSec)")
            out.append("audioBoostMaxGain: \(prefs.audioBoostMaxGain)")
            out.append("historyMaxItems: \(prefs.historyMaxItems) / historyMaxDays: \(prefs.historyMaxDays)")
            out.append("indicatorVariant: \(prefs.indicatorVariant.rawValue)")
            out.append("(a API key mora no Keychain e não é lida por esta exportação)")
        } else {
            out.append("(indisponível)")
        }

        section("áudio")
        out.append(contentsOf: audioInput())

        section("permissões")
        out.append("AXIsProcessTrusted (Acessibilidade): \(AXIsProcessTrusted())")
        let hid = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        out.append("IOHIDCheckAccess (Input Monitoring): \(hid.rawValue) "
                   + "(\(hid == kIOHIDAccessTypeGranted ? "granted" : "não concedido"))")
        out.append("microfone: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue) "
                   + "(0=notDetermined, 1=restricted, 2=denied, 3=authorized)")

        section("event taps deste processo")
        for line in ownEventTaps() { out.append(line) }

        return out.joined(separator: "\n") + "\n"
    }

    // MARK: - sondagens

    /// The input format the capture tap will see. Opening `inputNode` makes
    /// coreaudiod check the microphone permission for this process — in the
    /// test host that meant a permission prompt, so tests pass their own probe.
    static func liveAudioInput() -> [String] {
        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        return ["inputNode: \(format.sampleRate)Hz / \(format.channelCount)ch",
                "device de entrada default: \(defaultInputDeviceName())"]
    }

    private static func defaultInputDeviceName() -> String {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != AudioDeviceID(kAudioObjectUnknown) else { return "?" }
        var name = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil,
                                         &nameSize, &name) == noErr else { return "id=\(deviceID)" }
        return name as String
    }

    /// Só os taps do próprio processo — é o que responde "a hotkey ainda está
    /// viva?" (S4 da auditoria §3.4) sem expor os taps de outros apps.
    private static func ownEventTaps() -> [String] {
        var count: UInt32 = 0
        _ = CGGetEventTapList(0, nil, &count)
        guard count > 0 else { return ["(nenhum)"] }
        var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &taps, &count) == .success else { return ["(falha ao listar)"] }
        let pid = ProcessInfo.processInfo.processIdentifier
        let mine = taps.prefix(Int(count)).filter { $0.tappingProcess == pid }
        guard !mine.isEmpty else { return ["(nenhum tap deste processo — hotkey morta)"] }
        return mine.map {
            String(format: "tap id=%u enabled=%@ options=%u point=%u mask=0x%llx",
                   $0.eventTapID, $0.enabled ? "YES" : "NO",
                   $0.options.rawValue, $0.tapPoint.rawValue, $0.eventsOfInterest)
        }
    }

    private static func runVmmap() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vmmap")
        process.arguments = ["-summary", "\(ProcessInfo.processInfo.processIdentifier)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
