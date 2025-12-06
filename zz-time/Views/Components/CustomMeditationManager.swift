import Foundation
import SwiftUI

@MainActor
class CustomMeditationManager: ObservableObject {
    @Published var meditations: [CustomMeditation] = []
    
    private let storageKey = "customMeditations"
    private let maxMeditations = 10
    
    init() {
        loadMeditations()
    }
        
    func loadMeditations() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomMeditation].self, from: data) else {
            // First time user - load default meditation
            loadDefaultMeditation()
            
            // Migrate old single meditation if it exists
            if let oldText = UserDefaults.standard.string(forKey: "customMeditationText"),
               !oldText.isEmpty {
                meditations.append(CustomMeditation(title: "My Meditation", text: oldText))
                saveMeditations()
                UserDefaults.standard.removeObject(forKey: "customMeditationText")
            }
            return
        }
        meditations = decoded
        
        // If all meditations were deleted, restore default
        if meditations.isEmpty {
            loadDefaultMeditation()
        }
    }
    
    private func loadDefaultMeditation() {
        guard let url = Bundle.main.url(forResource: "default-custom-meditation", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        
        let defaultMeditation = CustomMeditation(
            title: "Welcome Meditation",
            text: text
        )
        meditations.append(defaultMeditation)
        saveMeditations()
    }
    
    func saveMeditations() {
        if let encoded = try? JSONEncoder().encode(meditations) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func addMeditation(_ meditation: CustomMeditation) {
        guard meditations.count < maxMeditations else { return }
        meditations.append(meditation)
        saveMeditations()
    }
    
    func updateMeditation(_ meditation: CustomMeditation) {
        if let index = meditations.firstIndex(where: { $0.id == meditation.id }) {
            meditations[index] = meditation
            saveMeditations()
        }
    }
    
    func deleteMeditation(_ meditation: CustomMeditation) {
        meditations.removeAll { $0.id == meditation.id }
        saveMeditations()
        
        // If all meditations deleted, restore default
        if meditations.isEmpty {
            loadDefaultMeditation()
        }
    }
    
    func duplicateMeditation(_ meditation: CustomMeditation) {
        guard meditations.count < maxMeditations else { return }
        
        let duplicate = CustomMeditation(
            title: "\(meditation.title) (Copy)",
            text: meditation.text
        )
        
        // Insert right after the original
        if let index = meditations.firstIndex(where: { $0.id == meditation.id }) {
            meditations.insert(duplicate, at: index + 1)
        } else {
            meditations.append(duplicate)
        }
        
        saveMeditations()
    }
    
    var canAddMore: Bool {
        meditations.count < maxMeditations
    }
}
