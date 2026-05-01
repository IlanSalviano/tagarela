import Foundation

/// Metadata estática de um modelo Whisper exibido no picker.
///
/// Nomes técnicos seguem a convenção do `argmaxinc/whisperkit-coreml` no Hugging
/// Face: `large-v3_turbo` (underscore), `large-v3` (hífen sem suffix), `medium`.
/// Tamanhos display são aproximações pro picker; cleanup prompt usa
/// `WhisperModelStore.sizeOnDisk` real.
struct WhisperModelInfo: Equatable, Hashable, Identifiable {
    let name: String          // "large-v3_turbo" — nome técnico passado pro WhisperKit
    let displaySize: String   // "~1.6 GB" — pra UI
    let displayRAM: String    // "≥ 4 GB" — pra UI
    let approxBytes: Int64    // pra cálculo de "libera X MB" no cleanup prompt
    let recommended: Bool     // badge "recom." na UI

    var id: String { name }
}

/// Fonte da verdade dos modelos disponíveis na v1.
/// Ordem aqui = ordem de exibição no picker.
enum WhisperModelCatalog {
    static let all: [WhisperModelInfo] = [
        WhisperModelInfo(
            name: "large-v3_turbo",
            displaySize: "~1.6 GB",
            displayRAM: "≥ 4 GB",
            approxBytes: 1_600 * 1024 * 1024,
            recommended: true
        ),
        WhisperModelInfo(
            name: "large-v3",
            displaySize: "2.9 GB",
            displayRAM: "≥ 16 GB",
            approxBytes: 2_900 * 1024 * 1024,
            recommended: false
        ),
        WhisperModelInfo(
            name: "medium",
            displaySize: "1.4 GB",
            displayRAM: "≥ 8 GB",
            approxBytes: 1_400 * 1024 * 1024,
            recommended: false
        ),
    ]

    static func info(for name: String) -> WhisperModelInfo? {
        all.first { $0.name == name }
    }
}
