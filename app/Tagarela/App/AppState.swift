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
        case .idle: return "pronto"
        case .recording: return "gravando"
        case .processing: return "transcrevendo"
        case .refining: return "refinando"
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
