import Foundation
import CryptoKit

/// Implements SSL certificate pinning for enhanced network security
/// Prevents man-in-the-middle attacks by validating server certificates against known fingerprints
/// Fingerprints are loaded from Info.plist (injected via Secrets.xcconfig)
/// SECURITY: Fails closed - rejects connections if fingerprints are configured but don't match
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    // MARK: - Configuration

    /// Maps hostnames to their Info.plist key for fingerprint lookup
    private let hostToPlistKey: [String: String] = [
        "kxqxnqbgebhqbvfbmgzv.supabase.co": "CERT_PIN_SUPABASE",
        "bck48elw.api.sanity.io": "CERT_PIN_SANITY",
        "i.ytimg.com": "CERT_PIN_YOUTUBE",
        "ibblb-website.vercel.app": "CERT_PIN_VERCEL"
    ]

    /// Loads fingerprints from Info.plist for a given host
    /// Returns nil if host is not configured for pinning
    /// Returns empty set if configured but no fingerprints provided (will fail closed)
    private func loadFingerprints(for host: String) -> Set<String>? {
        guard let plistKey = hostToPlistKey[host] else {
            return nil // Host not configured for pinning
        }

        guard let fingerprints = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
              !fingerprints.isEmpty,
              !fingerprints.hasPrefix("$(") else {
            // Key exists but no valid fingerprints - return empty set to fail closed
            return Set()
        }

        // Support multiple fingerprints separated by commas (for certificate rotation)
        return Set(fingerprints.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Check if we have pinning rules for this host
        guard let trustedFingerprints = loadFingerprints(for: host) else {
            // Host not configured for pinning - use default validation
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // FAIL CLOSED: If fingerprints set is empty, reject the connection
        guard !trustedFingerprints.isEmpty else {
            #if DEBUG
            print("❌ CertificatePinning: No fingerprints configured for \(host) - failing closed")
            print("   This means the certificate pinning key exists in Info.plist but has no value")
            print("   Check that CERT_PIN_* keys are properly set in Secrets.xcconfig")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get the server trust
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            #if DEBUG
            print("❌ CertificatePinning: No server trust found for \(host)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate the certificate chain first
        var secTrustError: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &secTrustError)

        guard isTrusted else {
            #if DEBUG
            print("❌ CertificatePinning: Certificate chain validation failed for \(host)")
            if let error = secTrustError {
                print("   Error: \(error)")
            }
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get the leaf certificate from the server
        let certificate: SecCertificate?
        if #available(iOS 15.0, *) {
            guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
                  !certificateChain.isEmpty else {
                #if DEBUG
                print("❌ CertificatePinning: Could not retrieve certificate chain for \(host)")
                #endif
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            certificate = certificateChain[0]
        } else {
            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            guard certificateCount > 0 else {
                #if DEBUG
                print("❌ CertificatePinning: Could not retrieve certificate for \(host)")
                #endif
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            certificate = SecTrustGetCertificateAtIndex(serverTrust, 0)
        }

        guard let certificate = certificate else {
            #if DEBUG
            print("❌ CertificatePinning: Could not retrieve certificate for \(host)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Compute SHA-256 fingerprint of the certificate
        let certificateData = SecCertificateCopyData(certificate) as Data
        let fingerprint = SHA256.hash(data: certificateData)
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")

        #if DEBUG
        print("🔐 CertificatePinning: Checking \(host)")
        print("   Received fingerprint: \(fingerprint)")
        #endif

        // Check if the fingerprint matches any of the trusted certificates
        if trustedFingerprints.contains(fingerprint) {
            #if DEBUG
            print("✅ CertificatePinning: Certificate verified for \(host)")
            #endif
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // PRODUCTION: Log mismatch but still reject for security
            // In production, this will cause API failures until app update
            #if DEBUG
            print("❌ CertificatePinning: Certificate mismatch for \(host) - REJECTING")
            print("   Expected one of: \(trustedFingerprints)")
            print("   Received: \(fingerprint)")
            print("   ⚠️ This will cause all API requests to fail!")
            print("   Update the certificate fingerprint in Secrets.xcconfig or disable pinning for this host")
            #else
            // In production, log to crash reporting service (if available)
            // This helps identify certificate rotation issues affecting users
            print("❌ CertificatePinning: Certificate mismatch for \(host)")
            // TODO: Send to crash reporting service (e.g., Sentry, Firebase Crashlytics)
            // Example: Crashlytics.recordError(error, userInfo: ["host": host, "fingerprint": fingerprint])
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
