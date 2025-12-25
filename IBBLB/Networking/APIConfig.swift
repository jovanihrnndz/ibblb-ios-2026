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

    // MARK: - Preview Mode Detection
    
    /// Detects if the app is running in SwiftUI Preview mode
    /// Checks the environment variable set by Xcode when running Previews
    static var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    /// Helper to safely read Info.plist values with Preview mode support
    /// - Parameters:
    ///   - key: The Info.plist key to read
    ///   - defaultValue: Default value to return in Preview mode if value is missing/unsubstituted
    /// - Returns: The value from Info.plist, or defaultValue only if value is truly unavailable
    /// - Note: In Preview mode, uses real values if available, only falls back to placeholder if missing.
    ///         This allows Previews to work with real data when possible.
    private static func info(_ key: String, defaultValue: String = "") -> String {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)
        let value = (rawValue as? String) ?? ""
        let isUnsubstituted = value.hasPrefix("$(") && value.hasSuffix(")")
        let isEmpty = value.isEmpty
        
        // Check if we're in Preview mode (via environment variable)
        let inPreviewMode = isPreviewMode
        
        // If value is valid (not empty, not unsubstituted), use it even in Preview mode
        // This allows Previews to work with real data
        if !isEmpty && !isUnsubstituted {
            #if DEBUG
            if inPreviewMode {
                print("✅ [Preview Mode] Using real value for '\(key)': \(value.prefix(30))...")
            }
            #endif
            return value
        }
        
        // If we're in Preview mode and value is missing/unsubstituted, use placeholder
        if inPreviewMode {
            #if DEBUG
            print("🔍 [Preview Mode] Config key '\(key)': \(isEmpty ? "empty" : "unsubstituted (\(value))") - using placeholder")
            #endif
            return defaultValue
        }
        
        // Normal runtime: if unsubstituted, log warning but try to use it
        if isUnsubstituted {
            #if DEBUG
            print("⚠️ [Normal Runtime] Config key '\(key)' is unsubstituted (\(value)). Ensure Secrets.xcconfig is properly configured.")
            #endif
        }
        
        // Return the value (even if unsubstituted - let the build system handle it)
        // If empty, return empty string (will cause API calls to fail, which is better than silent placeholder)
        return value
    }

    // SECURITY: Credentials are now loaded from Info.plist (injected via Secrets.xcconfig)
    // This prevents hardcoded secrets from being committed to version control
    static var supabaseURL: String {
        let value = info("SUPABASE_URL", defaultValue: "https://preview-mode-placeholder.supabase.co")
        
        // If value is just the project ID (not a full URL), construct the full URL
        if !value.isEmpty && !value.hasPrefix("http") && !value.hasPrefix("$(") {
            let fullURL = "https://\(value).supabase.co"
            #if DEBUG
            print("🔧 Constructed full Supabase URL from project ID: \(fullURL)")
            #endif
            return fullURL
        }
        
        // If we got an unsubstituted value or empty in normal runtime, fail with clear error
        if (value.hasPrefix("$(") && value.hasSuffix(")")) || (value.isEmpty && !isPreviewMode) {
            #if DEBUG
            print("❌ SUPABASE_URL substitution failed!")
            print("   Original value from Info.plist: '\(value.isEmpty ? "empty" : value)'")
            print("   Ensure Secrets.xcconfig is properly linked in Xcode project settings.")
            print("   Go to: Project → Target → Info → Configurations → Set 'Secrets.xcconfig' for Debug and Release")
            #endif
            // In normal runtime, fail fast rather than using hardcoded values
            fatalError("SUPABASE_URL not configured. Please ensure Secrets.xcconfig is properly linked in Xcode project settings.")
        }
        
        // Validate the URL format - must not be empty and must start with http
        if value.isEmpty || (!value.hasPrefix("http://") && !value.hasPrefix("https://")) {
            #if DEBUG
            print("❌ SUPABASE_URL appears invalid: '\(value.isEmpty ? "empty" : value)'")
            #endif
            // In normal runtime, fail fast rather than using hardcoded values
            if !isPreviewMode {
                fatalError("SUPABASE_URL is invalid. Please check Secrets.xcconfig configuration.")
            }
        }
        
        #if DEBUG
        if !value.isEmpty && value.hasPrefix("https://") {
            print("✅ Using Supabase URL: \(value.prefix(30))...") // Log first 30 chars for security
        }
        #endif
        
        return value
    }

    static var supabaseAnonKey: String {
        let rawValue = info("SUPABASE_ANON_KEY", defaultValue: "preview-mode-placeholder-key")
        
        // Remove quotes if present (xcconfig files sometimes add them, or they come from Info.plist)
        let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        // If unsubstituted or empty after cleaning, fail with clear error in normal runtime
        if (value.hasPrefix("$(") && value.hasSuffix(")")) || value.isEmpty {
            #if DEBUG
            if isPreviewMode {
                print("⚠️ [Preview Mode] SUPABASE_ANON_KEY substitution failed. Using placeholder.")
            } else {
                print("❌ SUPABASE_ANON_KEY substitution failed!")
                print("   Original value from Info.plist: '\(rawValue.isEmpty ? "empty" : rawValue.prefix(20))...'")
                print("   Ensure Secrets.xcconfig is properly linked in Xcode project settings.")
                print("   Go to: Project → Target → Info → Configurations → Set 'Secrets.xcconfig' for Debug and Release")
            }
            #endif
            // In normal runtime, fail fast rather than using hardcoded values
            if !isPreviewMode {
                fatalError("SUPABASE_ANON_KEY not configured. Please ensure Secrets.xcconfig is properly linked in Xcode project settings.")
            }
        }
        
        return value
    }

    static let sanityProjectID = "bck48elw"
    static let sanityDataset = "production"
}
