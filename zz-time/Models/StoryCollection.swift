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
        // Generate stable UUID from directory name so it's consistent across app launches
        self.id = UUID(uuidString: Self.stableUUID(from: directoryName)) ?? UUID()
        self.directoryName = directoryName
        self.displayName = Self.formatDisplayName(directoryName)
        self.storyFiles = []
        self.poemFiles = []
    }

    // Generate stable UUID from string
    private static func stableUUID(from string: String) -> String {
        // Use MD5-like approach to generate consistent UUID from directory name
        let hash = string.utf8.reduce(0) { ($0 &+ UInt64($1)) &* 31 }
        let uuidString = String(format: "%08X-%04X-%04X-%04X-%012X",
                               UInt32(hash >> 32),
                               UInt16((hash >> 16) & 0xFFFF),
                               UInt16(hash & 0xFFFF),
                               UInt16((hash >> 48) & 0xFFFF),
                               hash & 0xFFFFFFFFFFFF)
        return uuidString
    }

    static func formatDisplayName(_ dirName: String) -> String {
        dirName.replacingOccurrences(of: "_", with: " ")
               .replacingOccurrences(of: "-", with: " ")
    }

    var sortedChapters: [StoryFile] {
        storyFiles.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }
}
