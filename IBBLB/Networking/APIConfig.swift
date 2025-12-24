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

    // SECURITY: Credentials are now loaded from Info.plist (injected via Secrets.xcconfig)
    // This prevents hardcoded secrets from being committed to version control
    static var supabaseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !url.isEmpty else {
            fatalError("SUPABASE_URL not configured in Info.plist. Please ensure Secrets.xcconfig is properly set up.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist. Please ensure Secrets.xcconfig is properly set up.")
        }
        return key
    }

    static let sanityProjectID = "bck48elw"
    static let sanityDataset = "production"
}
