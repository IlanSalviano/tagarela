import Foundation

protocol WhisperModelStore: Sendable {
    /// Retorna true se a pasta do modelo existe em disco com pelo menos 1 arquivo.
    func isDownloaded(_ name: String) -> Bool

    /// Retorna soma dos bytes de todos os arquivos da pasta do modelo, ou nil se ausente.
    func sizeOnDisk(_ name: String) -> Int64?

    /// URL da pasta do modelo se ele já está em disco, senão `nil`.
    /// Permite carregar sem tocar a rede — `WhisperKit.download` faz um HTTP
    /// incondicional a `huggingface.co` mesmo com o modelo já baixado.
    func modelFolderURL(for name: String) -> URL?

    /// Remove a pasta do modelo do disco. Lança `notFound` se não existe.
    func delete(_ name: String) async throws
}

enum WhisperModelStoreError: Error, Equatable {
    case notFound
    case ioFailure(String)
}
