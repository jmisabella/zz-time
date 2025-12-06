
import Foundation

struct CustomMeditation: Identifiable, Codable {
    let id: UUID
    var title: String
    var text: String
    var dateCreated: Date
    
    init(id: UUID = UUID(), title: String, text: String, dateCreated: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.dateCreated = dateCreated
    }
}
