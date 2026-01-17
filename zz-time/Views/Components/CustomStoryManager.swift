import Foundation
import SwiftUI

@MainActor
class CustomStoryManager: ObservableObject {
    @Published var stories: [CustomStory] = []

    private let storageKey = "customStories"
    
    init() {
        loadStories()
    }
        
    func loadStories() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomStory].self, from: data) else {
            // First time user - load default story
            loadDefaultStory()
            
            // Migrate old single story if it exists
            if let oldText = UserDefaults.standard.string(forKey: "customStoryText"),
               !oldText.isEmpty {
                stories.append(CustomStory(title: "My Story", text: oldText))
                saveStories()
                UserDefaults.standard.removeObject(forKey: "customStoryText")
            }
            return
        }
        stories = decoded
        
        // If all stories were deleted, restore default
        if stories.isEmpty {
            loadDefaultStory()
        }
    }
    
    private func loadDefaultStory() {
        guard let url = Bundle.main.url(forResource: "default_custom_story", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        
        let defaultStory = CustomStory(
            title: "Welcome Story",
            text: text
        )
        stories.append(defaultStory)
        saveStories()
    }
    
    func saveStories() {
        if let encoded = try? JSONEncoder().encode(stories) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func addStory(_ story: CustomStory) {
        stories.append(story)
        saveStories()
    }
    
    func updateStory(_ story: CustomStory) {
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories[index] = story
            saveStories()
        }
    }
    
    func deleteStory(_ story: CustomStory) {
        stories.removeAll { $0.id == story.id }
        saveStories()
        
        // If all stories deleted, restore default
        if stories.isEmpty {
            loadDefaultStory()
        }
    }
    
    func duplicateStory(_ story: CustomStory) {
        // Remove existing " (Copy)" suffix if present to avoid stacking
        let baseTitle = story.title.hasSuffix(" (Copy)")
            ? String(story.title.dropLast(7))
            : story.title

        let duplicate = CustomStory(
            title: "\(baseTitle) (Copy)",
            text: story.text
        )

        // Insert right after the original
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories.insert(duplicate, at: index + 1)
        } else {
            stories.append(duplicate)
        }

        saveStories()
    }

    var canAddMore: Bool {
        true  // No limit on custom stories
    }
}
