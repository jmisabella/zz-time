import Foundation

struct StoryCollection: Identifiable, Codable, Equatable {
    let id: UUID
    let directoryName: String    // e.g., "Signal_Decay"
    var displayName: String       // e.g., "Signal Decay"
    var storyFiles: [StoryFile]
    var poemFiles: [String]

    struct StoryFile: Codable, Equatable {
        let filename: String
        let sequenceNumber: Int
    }

    init(directoryName: String) {
        self.id = UUID()
        self.directoryName = directoryName
        self.displayName = Self.formatDisplayName(directoryName)
        self.storyFiles = []
        self.poemFiles = []
    }

    static func formatDisplayName(_ dirName: String) -> String {
        dirName.replacingOccurrences(of: "_", with: " ")
               .replacingOccurrences(of: "-", with: " ")
    }

    var sortedChapters: [StoryFile] {
        storyFiles.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }
}
