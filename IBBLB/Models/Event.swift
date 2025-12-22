import Foundation

struct Event: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let imageUrl: String?
    let description: String?
    let registrationEnabled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case startDate
        case endDate
        case location
        case imageUrl
        case description
        case registrationEnabled
    }
}
