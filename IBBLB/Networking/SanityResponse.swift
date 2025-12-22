import Foundation

struct SanityResponse<T: Decodable>: Decodable {
    let result: T
    let query: String?
    let ms: Int?
}
