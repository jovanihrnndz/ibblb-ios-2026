import Foundation

enum APIConfig {
    enum Environment {
        case development
        case production
        
        var baseURL: String {
            switch self {
            case .development:
                return "https://ibblb-website.vercel.app"
            case .production:
                return "https://ibblb-website.vercel.app"
            }
        }
    }
    
    // Change this flag to switch environments
    static let currentEnvironment: Environment = .development
    
    static var baseURL: String {
        currentEnvironment.baseURL
    }
    
    static let supabaseURL = "https://kxqxnqbgebhqbvfbmgzv.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4cXhucWJnZWJocWJ2ZmJtZ3p2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0ODQzODIsImV4cCI6MjA3OTA2MDM4Mn0.jW1x6SY6it_RknwUlkKiLdaPHi1XelSJEd551DhccZw"
    
    static let sanityProjectID = "bck48elw"
    static let sanityDataset = "production"
}
