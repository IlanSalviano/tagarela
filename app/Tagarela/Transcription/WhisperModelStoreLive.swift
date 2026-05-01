import Foundation
import OSLog

/// Impl que assume o layout de cache do WhisperKit:
/// `<rootDirectory>/openai_whisper-<name>/`.
/// `rootDirectory` default = `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml`,
/// que é onde o WhisperKit 0.9.x baixa por padrão.
final class WhisperModelStoreLive: WhisperModelStore, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tagarela", category: "ModelStore")
    private let root: URL
    private let fm: FileManager

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fm = fileManager
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            // Mesmo path que o WhisperKit 0.9.x usa por default
            // (referência: WhisperKit.HubApi defaultDownloadBase).
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            self.root = docs
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
        }
    }

    func isDownloaded(_ name: String) -> Bool {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else { return false }
        let contents = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return !contents.isEmpty
    }

    func sizeOnDisk(_ name: String) -> Int64? {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else { return nil }
        guard let enumerator = fm.enumerator(at: dir,
                                             includingPropertiesForKeys: [.fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { return nil }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    func delete(_ name: String) async throws {
        let dir = modelDir(for: name)
        guard fm.fileExists(atPath: dir.path) else {
            throw WhisperModelStoreError.notFound
        }
        do {
            try fm.removeItem(at: dir)
            logger.info("deleted model: \(name, privacy: .public)")
        } catch {
            throw WhisperModelStoreError.ioFailure(String(describing: error))
        }
    }

    private func modelDir(for name: String) -> URL {
        root.appendingPathComponent("openai_whisper-\(name)")
    }
}
