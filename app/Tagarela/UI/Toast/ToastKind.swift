import Foundation
import SwiftUI

/// Razão semântica pelo fallback Identity. Mapeada de `RefinerError`.
enum RefinerFallbackReason: Equatable, Sendable {
    case networkOffline
    case unauthorized
    case timedOut
    case serverError(Int)
    case rateLimited
    case contextExceeded
    case modelNotFound(String)
    case malformedResponse

    /// Mapeia `RefinerError` pra `RefinerFallbackReason`. `.cancelled` retorna
    /// nil — cancel real é fluxo distinto, sem toast.
    init?(refinerError: RefinerError) {
        switch refinerError {
        case .networkOffline:        self = .networkOffline
        case .unauthorized:          self = .unauthorized
        case .timedOut:              self = .timedOut
        case .serverError(let code): self = .serverError(code)
        case .rateLimited:           self = .rateLimited
        case .contextExceeded:       self = .contextExceeded
        case .modelNotFound(let n):  self = .modelNotFound(n)
        case .malformedResponse:     self = .malformedResponse
        case .cancelled:             return nil
        }
    }
}

enum ToastKind: Equatable, Sendable {
    case refinerFellBack(reason: RefinerFallbackReason)
    case injectionFailed
    case historySaveFailed
    case permissionDenied(kind: PermissionKind)
    case captureFailed
    case emptyTranscription
    case transcriberRecovered
    case transcriberNotReady

    var displayMessage: String {
        switch self {
        case .refinerFellBack(let reason):
            switch reason {
            case .networkOffline:
                return String(localized: "toast.refiner.networkOffline",
                              defaultValue: "Sem rede — usando texto cru.")
            case .unauthorized:
                return String(localized: "toast.refiner.unauthorized",
                              defaultValue: "API key inválida — usando texto cru.")
            case .timedOut:
                return String(localized: "toast.refiner.timedOut",
                              defaultValue: "Timeout no refiner — usando texto cru.")
            case .serverError(let code):
                return String(localized: "toast.refiner.serverError",
                              defaultValue: "Erro do servidor (\(code)) — usando texto cru.")
            case .rateLimited:
                return String(localized: "toast.refiner.rateLimited",
                              defaultValue: "Rate limit no refiner — usando texto cru.")
            case .contextExceeded:
                return String(localized: "toast.refiner.contextExceeded",
                              defaultValue: "Texto longo demais — usando texto cru.")
            case .modelNotFound(let name):
                return String(localized: "toast.refiner.modelNotFound",
                              defaultValue: "Modelo '\(name)' não encontrado — usando texto cru.")
            case .malformedResponse:
                return String(localized: "toast.refiner.malformedResponse",
                              defaultValue: "Resposta malformada — usando texto cru.")
            }
        case .injectionFailed:
            // O histórico é salvo antes da cola desde a Tarefa 4, então esta
            // frase é verdadeira em todos os caminhos de falha — a anterior
            // ("texto na área de transferência") era falsa nos dois.
            return String(localized: "toast.injection.failed",
                          defaultValue: "Cola falhou — o ditado está salvo no histórico.")
        case .historySaveFailed:
            return String(localized: "toast.history.saveFailed",
                          defaultValue: "Histórico não salvou.")
        case .permissionDenied(let kind):
            switch kind {
            case .microphone:
                return String(localized: "toast.permission.microphone",
                              defaultValue: "Microfone negado — veja Preferências › Permissões.")
            case .accessibility:
                return String(localized: "toast.permission.accessibility",
                              defaultValue: "Sem Acessibilidade: o ditado ficou no clipboard e no histórico. Veja Preferências › Permissões.")
            case .inputMonitoring:
                return String(localized: "toast.permission.inputMonitoring",
                              defaultValue: "Monitoramento de Entrada negado — veja Preferências › Permissões.")
            }
        case .captureFailed:
            return String(localized: "toast.capture.failed",
                          defaultValue: "Não captei áudio do microfone. Confira o dispositivo de entrada.")
        case .emptyTranscription:
            return String(localized: "toast.transcription.empty",
                          defaultValue: "Não entendi nada — tente de novo.")
        case .transcriberRecovered:
            return String(localized: "toast.transcriber.recovered",
                          defaultValue: "Reconhecedor reiniciado.")
        case .transcriberNotReady:
            return String(localized: "toast.transcriber.notReady",
                          defaultValue: "Ainda carregando o reconhecedor — tente em alguns segundos.")
        }
    }

    var iconSystemName: String {
        switch self {
        case .refinerFellBack:    return "exclamationmark.triangle"
        case .injectionFailed:    return "doc.on.clipboard"
        case .historySaveFailed:  return "externaldrive.badge.xmark"
        case .permissionDenied:   return "lock.shield"
        case .captureFailed:      return "mic.slash"
        case .emptyTranscription: return "waveform.badge.exclamationmark"
        case .transcriberRecovered: return "arrow.clockwise"
        case .transcriberNotReady:  return "hourglass"
        }
    }

    var tintColor: Color {
        switch self {
        case .refinerFellBack:    return .orange
        case .injectionFailed:    return .red
        case .historySaveFailed:  return .red
        case .permissionDenied:   return .red
        case .captureFailed:      return .red
        case .emptyTranscription: return .orange
        case .transcriberRecovered: return .green
        case .transcriberNotReady:  return .orange
        }
    }
}
