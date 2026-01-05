import Foundation
import SwiftUI

@MainActor
class CustomPoemManager: ObservableObject {
    @Published var poems: [CustomPoem] = []

    private let storageKey = "customPoems"

    init() {
        loadPoems()
    }

    func loadPoems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomPoem].self, from: data) else {
            // First time user - load default poem
            loadDefaultPoem()
            return
        }
        poems = decoded

        // If all poems were deleted, restore default
        if poems.isEmpty {
            loadDefaultPoem()
        }
    }

    private func loadDefaultPoem() {
        guard let url = Bundle.main.url(forResource: "default_custom_poem", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let defaultPoem = CustomPoem(
            title: "Welcome Poem",
            text: text
        )
        poems.append(defaultPoem)
        savePoems()
    }

    func savePoems() {
        if let encoded = try? JSONEncoder().encode(poems) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func addPoem(_ poem: CustomPoem) {
        poems.append(poem)
        savePoems()
    }

    func updatePoem(_ poem: CustomPoem) {
        if let index = poems.firstIndex(where: { $0.id == poem.id }) {
            poems[index] = poem
            savePoems()
        }
    }

    func deletePoem(_ poem: CustomPoem) {
        poems.removeAll { $0.id == poem.id }
        savePoems()

        // If all poems deleted, restore default
        if poems.isEmpty {
            loadDefaultPoem()
        }
    }

    func duplicatePoem(_ poem: CustomPoem) {
        // Remove existing " (Copy)" suffix if present to avoid stacking
        let baseTitle = poem.title.hasSuffix(" (Copy)")
            ? String(poem.title.dropLast(7))
            : poem.title

        let duplicate = CustomPoem(
            title: "\(baseTitle) (Copy)",
            text: poem.text
        )

        // Insert right after the original
        if let index = poems.firstIndex(where: { $0.id == poem.id }) {
            poems.insert(duplicate, at: index + 1)
        } else {
            poems.append(duplicate)
        }

        savePoems()
    }

    var canAddMore: Bool {
        true  // No limit on custom poems
    }
}
