//
//  SecureURLHandler.swift
//  IBBLB
//
//  Secure URL validation and opening utility
//

import Foundation
import UIKit

enum URLValidationError: Error {
    case invalidScheme
    case missingHost
    case untrustedDomain
    case malformedURL

    var userMessage: String {
        switch self {
        case .invalidScheme:
            return "Only HTTPS links are supported for security."
        case .missingHost:
            return "Invalid URL format."
        case .untrustedDomain:
            return "This link goes to an external website."
        case .malformedURL:
            return "The provided link is not valid."
        }
    }
}

class SecureURLHandler {
    // Whitelist of allowed URL schemes
    private static let allowedSchemes = ["https"]

    // Whitelist of trusted domains for different purposes
    private static let trustedGivingDomains = [
        "give.ibblb.org",
        "giving.ibblb.org",
        "donate.ibblb.org",
        "secure.ibblb.org",
        "ibblb.org"
    ]

    // Generic trusted domains for all church-related URLs
    private static let trustedChurchDomains = [
        "ibblb.org",
        "ibblb-website.vercel.app"
    ]

    /// Validates a URL against security criteria
    /// - Parameters:
    ///   - url: The URL to validate
    ///   - trustedDomains: List of trusted domains (optional, defaults to church domains)
    /// - Returns: Validated URL
    /// - Throws: URLValidationError if validation fails
    static func validateURL(_ url: URL, trustedDomains: [String]? = nil) throws -> URL {
        // 1. Validate scheme
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            throw URLValidationError.invalidScheme
        }

        // 2. Validate host exists
        guard let host = url.host?.lowercased() else {
            throw URLValidationError.missingHost
        }

        // 3. Check against whitelist
        let domainsToCheck = trustedDomains ?? trustedChurchDomains
        let isTrusted = domainsToCheck.contains { trustedDomain in
            host == trustedDomain || host.hasSuffix(".\(trustedDomain)")
        }

        guard isTrusted else {
            throw URLValidationError.untrustedDomain
        }

        return url
    }

    /// Safely opens a URL after validation
    /// - Parameters:
    ///   - urlString: The URL string to open
    ///   - trustedDomains: Optional list of trusted domains
    ///   - onUntrusted: Optional callback for untrusted URLs (allows user confirmation)
    /// - Returns: true if URL was opened, false otherwise
    @MainActor
    static func openURL(
        _ urlString: String,
        trustedDomains: [String]? = nil,
        onUntrusted: ((URL) -> Void)? = nil
    ) -> Bool {
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("⚠️ SecureURLHandler: Invalid URL string")
            #endif
            return false
        }

        do {
            let validatedURL = try validateURL(url, trustedDomains: trustedDomains)
            UIApplication.shared.open(validatedURL)
            return true
        } catch URLValidationError.untrustedDomain {
            // Allow caller to handle untrusted domains (e.g., show confirmation dialog)
            if let onUntrusted = onUntrusted {
                onUntrusted(url)
            } else {
                #if DEBUG
                print("⚠️ SecureURLHandler: Blocked untrusted domain: \(url.host ?? "unknown")")
                #endif
            }
            return false
        } catch {
            #if DEBUG
            print("⚠️ SecureURLHandler: URL validation failed: \(error)")
            #endif
            return false
        }
    }

    /// Creates a validated URL from a string
    /// - Parameters:
    ///   - urlString: The URL string
    ///   - trustedDomains: Optional list of trusted domains
    /// - Returns: Validated URL or nil if validation fails
    static func validatedURL(
        from urlString: String,
        trustedDomains: [String]? = nil
    ) -> URL? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        return try? validateURL(url, trustedDomains: trustedDomains)
    }
}

// MARK: - MainActor Extensions for SwiftUI

extension SecureURLHandler {
    /// Shows an alert for untrusted URLs
    /// Use this in SwiftUI views to present user confirmation
    @MainActor
    static func confirmUntrustedURL(
        _ url: URL,
        onConfirm: @escaping () -> Void
    ) {
        // In a real implementation, this would show a SwiftUI alert
        // For now, we'll just log and allow advanced users to confirm
        #if DEBUG
        print("🔔 SecureURLHandler: Untrusted URL requires confirmation: \(url)")
        #endif

        // In production, you'd show an alert here
        // For now, we'll just call the confirmation handler
        // onConfirm()
    }
}
