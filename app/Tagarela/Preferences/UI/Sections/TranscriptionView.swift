import SwiftUI

struct TranscriptionView: View {
    @ObservedObject var prefs: PreferencesStore
    @ObservedObject var swapCoordinator: WhisperModelSwapCoordinator
    let modelStore: WhisperModelStore

    @State private var pendingTarget: String?            // alerta de confirmação
    @State private var pendingCleanup: String?           // alerta de cleanup pós-swap
    @State private var errorSheetVisible: Bool = false
    @State private var lastActive: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(localized: "preferences.section.transcricao", defaultValue: "Transcrição"))
                    .font(DS.Font.display(22))
                Text(String(localized: "preferences.transcription.activeModel",
                             defaultValue: "Modelo ativo: \(activeName)"))
                    .font(DS.Font.mono(11))
                    .foregroundStyle(DS.Color.ink2)
                WhisperModelPicker(
                    selected: Binding(
                        get: { activeName },
                        set: { newValue in
                            guard newValue != activeName else { return }
                            pendingTarget = newValue
                        }
                    ),
                    enabled: pickerEnabled
                )
                statusBlock
            }
            .padding(20)
        }
        .alert(String(localized: "preferences.transcription.swapConfirm.title",
                       defaultValue: "Trocar pra \(pendingTarget ?? "")?"),
               isPresented: Binding(
                    get: { pendingTarget != nil },
                    set: { if !$0 { pendingTarget = nil } }
               )) {
            Button(String(localized: "common.cancel", defaultValue: "Cancelar"),
                   role: .cancel) { pendingTarget = nil }
            Button(String(localized: "preferences.transcription.swapConfirm.proceed",
                           defaultValue: "Trocar")) {
                if let target = pendingTarget {
                    swapCoordinator.requestSwap(target: target)
                }
                pendingTarget = nil
            }
        } message: {
            if let target = pendingTarget,
               let info = WhisperModelCatalog.info(for: target) {
                Text(String(localized: "preferences.transcription.swapConfirm.body",
                             defaultValue: "Vai baixar \(info.displaySize). Você pode continuar usando o app durante o download."))
            }
        }
        .alert(String(localized: "preferences.transcription.deletePrevious.title",
                       defaultValue: "Apagar \(pendingCleanup ?? "")?"),
               isPresented: Binding(
                    get: { pendingCleanup != nil },
                    set: { if !$0 { pendingCleanup = nil } }
               )) {
            Button(String(localized: "preferences.transcription.deletePrevious.keep",
                           defaultValue: "Manter"), role: .cancel) {
                pendingCleanup = nil
            }
            Button(String(localized: "preferences.transcription.deletePrevious.delete",
                           defaultValue: "Apagar"), role: .destructive) {
                if let target = pendingCleanup {
                    Task {
                        try? await modelStore.delete(target)
                    }
                }
                pendingCleanup = nil
            }
        } message: {
            if let target = pendingCleanup,
               let bytes = modelStore.sizeOnDisk(target) {
                Text(String(localized: "preferences.transcription.deletePrevious.body",
                             defaultValue: "Libera \(formatBytes(bytes)) de espaço."))
            }
        }
        .sheet(isPresented: $errorSheetVisible) {
            if case .failed(_, let target, let err) = swapCoordinator.state {
                SwapErrorSheet(
                    target: target,
                    errorMessage: errorDescription(err),
                    onRetry: {
                        errorSheetVisible = false
                        swapCoordinator.retry()
                    },
                    onClose: {
                        errorSheetVisible = false
                        swapCoordinator.dismissError()
                    }
                )
            }
        }
        .onChange(of: swapCoordinator.state) { _, newState in
            handleStateTransition(newState)
        }
    }

    private var activeName: String {
        switch swapCoordinator.state {
        case .idle(let active): return active
        case .downloading(let active, _, _): return active
        case .swapping(let active, _): return active
        case .failed(let active, _, _): return active
        }
    }

    private var pickerEnabled: Bool {
        if case .idle = swapCoordinator.state { return true }
        return false
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch swapCoordinator.state {
        case .idle:
            EmptyView()
        case .downloading(_, let target, let progress):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress).progressViewStyle(.linear).tint(DS.Color.carmine)
                HStack {
                    Text(String(localized: "preferences.transcription.swap.downloading",
                                 defaultValue: "Baixando \(target) — \(Int(progress * 100))%"))
                        .font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
                    Spacer()
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) {
                        swapCoordinator.cancel()
                    }
                    .buttonStyle(.plain)
                    .font(DS.Font.mono(10))
                }
            }
        case .swapping(_, let target):
            Text(String(localized: "preferences.transcription.swap.swapping",
                         defaultValue: "Trocando pra \(target)…"))
                .font(DS.Font.mono(10)).foregroundStyle(DS.Color.ink3)
        case .failed:
            EmptyView()  // sheet cobre
        }
    }

    private func handleStateTransition(_ state: SwapState) {
        switch state {
        case .idle(let active):
            // se acabei de mudar (vinha de .swapping), ofereço cleanup do antigo
            if let last = lastActive, last != active, modelStore.isDownloaded(last) {
                pendingCleanup = last
                prefs.whisperModelName = active
            }
            lastActive = active
            errorSheetVisible = false
        case .downloading(let active, _, _):
            lastActive = active
        case .swapping(let active, _):
            lastActive = active
        case .failed:
            errorSheetVisible = true
        }
    }

    private func errorDescription(_ error: SwapError) -> String {
        switch error {
        case .downloadFailed(let r): return "Falha ao baixar: \(r)"
        case .loadFailed(let r):     return "Falha ao carregar: \(r)"
        case .cancelled:             return "Cancelado."
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        let mb = Double(b) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
