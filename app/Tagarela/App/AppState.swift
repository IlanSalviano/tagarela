import Foundation
import Combine

enum PipelineState: Equatable {
    case idle
    case recording(elapsedSeconds: Double, audioLevel: Double)
    case processing
    case refining
    case error(message: String)

    var dotColorName: String {
        switch self {
        case .idle: return "Moss"
        case .recording: return "Carmine"
        case .processing, .refining: return "Amber"
        case .error: return "CarmineDeep"
        }
    }

    var label: String {
        switch self {
        case .idle:       return String(localized: "pipeline.state.idle",        defaultValue: "pronto")
        case .recording:  return String(localized: "pipeline.state.recording",   defaultValue: "gravando")
        case .processing: return String(localized: "pipeline.state.processing",  defaultValue: "transcrevendo")
        case .refining:   return String(localized: "pipeline.state.refining",    defaultValue: "refinando")
        case .error(let msg): return msg
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var pipeline: PipelineState = .idle
    @Published var permissionsAllGranted: Bool = false
    @Published var whisperModelReady: Bool = false
}
