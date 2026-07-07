import Foundation
import SwiftUI

@MainActor
class StoryCollectionManager: ObservableObject {
    @Published var collections: [StoryCollection] = []

    // Per-story chapter tracking: [directoryName: chapterIndex]
    @AppStorage("storyChapterPositions") private var chapterPositionsData: Data = Data()
    private var chapterPositions: [String: Int] = [:]

    // Persist selected collection ID
    @AppStorage("selectedCollectionID") private var selectedCollectionIDString: String = ""

    @Published var selectedCollectionID: UUID? {
        didSet {
            // Save to AppStorage whenever it changes
            if let id = selectedCollectionID {
                selectedCollectionIDString = id.uuidString
            } else {
                selectedCollectionIDString = ""
            }
        }
    }

    init() {
        loadChapterPositions()
        // Restore saved selection before loading collections
        if !selectedCollectionIDString.isEmpty, let uuid = UUID(uuidString: selectedCollectionIDString) {
            selectedCollectionID = uuid
            print("📖 StoryCollectionManager: Restored selected collection ID: \(selectedCollectionIDString)")
        }
        loadCollections()
    }

    // MARK: - Discovery

    func loadCollections() {
        collections = []

        guard let ttsContentURL = Bundle.main.url(forResource: "TTSContent", withExtension: nil) else {
            // Fallback: TTSContent doesn't exist, no collections available
            print("❌ StoryCollectionManager: TTSContent directory not found in bundle")
            return
        }

        print("✅ StoryCollectionManager: Found TTSContent at \(ttsContentURL.path)")

        // Scan for subdirectories
        let fileManager = FileManager.default
        guard let subdirs = try? fileManager.contentsOfDirectory(
            at: ttsContentURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            print("❌ StoryCollectionManager: Could not read contents of TTSContent")
            return
        }

        print("📁 StoryCollectionManager: Found \(subdirs.count) items in TTSContent")

        for dir in subdirs {
            guard let isDir = try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDir,
                  !dir.lastPathComponent.hasPrefix(".") else { continue }

            // Skip default custom files
            if dir.lastPathComponent.hasSuffix(".txt") { continue }

            var collection = StoryCollection(directoryName: dir.lastPathComponent)

            // Scan Stories/ subdirectory
            let storiesURL = dir.appendingPathComponent("Stories")
            if let storyFiles = try? fileManager.contentsOfDirectory(
                at: storiesURL,
                includingPropertiesForKeys: nil
            ) {
                collection.storyFiles = storyFiles
                    .filter { $0.pathExtension == "txt" }
                    .compactMap { url -> StoryCollection.StoryFile? in
                        let filename = url.lastPathComponent
                        guard let seq = extractSequenceNumber(from: filename) else { return nil }
                        return StoryCollection.StoryFile(filename: filename, sequenceNumber: seq)
                    }
            }

            // Only add if has content
            if !collection.storyFiles.isEmpty || !collection.poemFiles.isEmpty {
                collections.append(collection)
            }
        }

        let displayOrder = ["Sensorium", "Aphelion", "Calibration"]
        collections.sort { a, b in
            let ai = displayOrder.firstIndex(of: a.directoryName) ?? Int.max
            let bi = displayOrder.firstIndex(of: b.directoryName) ?? Int.max
            if ai != bi { return ai < bi }
            return a.directoryName < b.directoryName
        }

        print("📚 StoryCollectionManager: Loaded \(collections.count) story collections")
        for collection in collections {
            print("   - \(collection.displayName): \(collection.storyFiles.count) chapters")
        }

        // Auto-select collection if none selected
        if selectedCollectionID == nil {
            let defaultCollection = collections.first
            if let collection = defaultCollection {
                selectedCollectionID = collection.id
                print("✨ StoryCollectionManager: Auto-selected '\(collection.displayName)'")
            }
        }
    }

    private func extractSequenceNumber(from filename: String) -> Int? {
        // Extract leading digits before underscore: "01_prelude.txt" -> 1
        let pattern = "^(\\d+)_"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
              let range = Range(match.range(at: 1), in: filename),
              let num = Int(filename[range]) else {
            return nil
        }
        return num
    }

    // MARK: - Chapter Position Tracking

    private func loadChapterPositions() {
        if let decoded = try? JSONDecoder().decode([String: Int].self, from: chapterPositionsData) {
            chapterPositions = decoded
        }
    }

    private func saveChapterPositions() {
        if let encoded = try? JSONEncoder().encode(chapterPositions) {
            chapterPositionsData = encoded
        }
    }

    func getChapterIndex(for directoryName: String) -> Int {
        chapterPositions[directoryName] ?? 1  // Default to chapter 1
    }

    func setChapterIndex(_ index: Int, for directoryName: String) {
        chapterPositions[directoryName] = index
        saveChapterPositions()
    }

    // MARK: - Accessors

    var selectedCollection: StoryCollection? {
        if let id = selectedCollectionID {
            return collections.first(where: { $0.id == id })
        }
        return nil
    }

    func getStoryText(for collection: StoryCollection, chapterIndex: Int) -> String? {
        guard let chapter = collection.sortedChapters.first(where: { $0.sequenceNumber == chapterIndex }) else {
            // Fall back to first chapter if index out of bounds
            if let first = collection.sortedChapters.first {
                setChapterIndex(first.sequenceNumber, for: collection.directoryName)
                return getStoryText(for: collection, chapterIndex: first.sequenceNumber)
            }
            return nil
        }

        let filename = chapter.filename.replacingOccurrences(of: ".txt", with: "")
        guard let url = Bundle.main.url(
            forResource: "TTSContent/\(collection.directoryName)/Stories/\(filename)",
            withExtension: "txt"
        ),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getRandomPoem() -> String? {
        guard let ttsContentURL = Bundle.main.url(forResource: "TTSContent", withExtension: nil) else { return nil }
        let poemsURL = ttsContentURL.appendingPathComponent("Poems")
        guard let files = try? FileManager.default.contentsOfDirectory(at: poemsURL, includingPropertiesForKeys: nil) else { return nil }
        let txts = files.filter { $0.pathExtension == "txt" }
        guard let randomURL = txts.randomElement(),
              let text = try? String(contentsOf: randomURL, encoding: .utf8) else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
