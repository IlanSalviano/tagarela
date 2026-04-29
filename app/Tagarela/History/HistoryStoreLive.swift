import Foundation
import OSLog
import SwiftData

@MainActor
final class HistoryStoreLive: HistoryStore {
    private let logger = Logger(subsystem: "com.tagarela", category: "History")
    private let container: ModelContainer

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("com.tagarela.Tagarela", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("History.store")
        let config = ModelConfiguration(url: url)
        self.container = try ModelContainer(for: Transcription.self, configurations: config)
    }

    init(inMemory: Bool) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: Transcription.self, configurations: config)
    }

    func save(_ input: TranscriptionInput, maxItems: Int, maxDays: Int) async throws {
        let ctx = container.mainContext
        let t = Transcription(
            durationSeconds: input.durationSeconds,
            rawText: input.rawText,
            refinedText: input.refinedText,
            refinerKind: input.refinerKind,
            llmModelName: input.llmModelName,
            whisperModelName: input.whisperModelName,
            styleName: input.styleName,
            frontmostAppBundleID: input.frontmostAppBundleID)
        ctx.insert(t)
        try ctx.save()
        try applyRetention(maxItems: maxItems, maxDays: maxDays)
    }

    func recent(limit: Int) async throws -> [Transcription] {
        let ctx = container.mainContext
        var fd = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        fd.fetchLimit = limit
        return try ctx.fetch(fd)
    }

    private func applyRetention(maxItems: Int, maxDays: Int) throws {
        let ctx = container.mainContext
        // (1) Apaga por idade
        let cutoff = Date().addingTimeInterval(-Double(maxDays) * 86_400)
        let oldFD = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.createdAt < cutoff })
        for old in try ctx.fetch(oldFD) { ctx.delete(old) }

        // (2) Mantém só os top maxItems
        let allFD = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = try ctx.fetch(allFD)
        if all.count > maxItems {
            for extra in all.dropFirst(maxItems) { ctx.delete(extra) }
        }
        try ctx.save()
    }
}
