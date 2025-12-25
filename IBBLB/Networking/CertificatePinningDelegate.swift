import Foundation
import CryptoKit

/// Implements SSL certificate pinning for enhanced network security
/// Prevents man-in-the-middle attacks by validating server certificates against known fingerprints
class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    // MARK: - Certificate Fingerprints

    /// SHA-256 fingerprints of trusted certificates for each domain
    /// To update these fingerprints, use the following command:
    /// ```
    /// echo | openssl s_client -connect <domain>:443 2>/dev/null | \
    ///   openssl x509 -fingerprint -sha256 -noout
    /// ```
    private let trustedCertificates: [String: Set<String>] = [
        // Supabase - Update these with actual certificate fingerprints
        "kxqxnqbgebhqbvfbmgzv.supabase.co": [
            // TODO: Add actual SHA-256 fingerprints for Supabase certificates
            // Example: "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
        ],

        // Sanity.io - Update these with actual certificate fingerprints
        "bck48elw.api.sanity.io": [
            // TODO: Add actual SHA-256 fingerprints for Sanity certificates
        ],

        // YouTube thumbnails - Update these with actual certificate fingerprints
        "i.ytimg.com": [
            // TODO: Add actual SHA-256 fingerprints for YouTube certificates
        ],

        // Vercel API - Update these with actual certificate fingerprints
        "ibblb-website.vercel.app": [
            // TODO: Add actual SHA-256 fingerprints for Vercel certificates
        ]
    ]

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
        guard let trustedFingerprints = trustedCertificates[host],
              !trustedFingerprints.isEmpty else {
            // No pinning configured for this host, use default validation
            #if DEBUG
            print("⚠️ CertificatePinning: No pins configured for \(host), using default validation")
            #endif
            completionHandler(.performDefaultHandling, nil)
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

        // Get the certificate from the server (leaf certificate is at index 0)
        // Use modern API for iOS 15+, fallback to deprecated API for older versions
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
            certificate = certificateChain[0] // Leaf certificate is first
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

        // Get certificate data and compute SHA-256 fingerprint
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
            #if DEBUG
            print("❌ CertificatePinning: Certificate mismatch for \(host)")
            print("   Expected one of: \(trustedFingerprints)")
            print("   Received: \(fingerprint)")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Helper Extension

extension CertificatePinningDelegate {
    /// Generates the fingerprint for a given certificate
    /// - Parameter certificate: The certificate to fingerprint
    /// - Returns: SHA-256 fingerprint in colon-separated hex format
    static func fingerprint(for certificate: SecCertificate) -> String {
        let certificateData = SecCertificateCopyData(certificate) as Data
        return SHA256.hash(data: certificateData)
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    /// Convenience method to print the fingerprint of a certificate from a URL
    /// Use this in DEBUG builds to get fingerprints for configuration
    /// - Parameter url: The URL to fetch the certificate from
    static func printCertificateFingerprint(for url: String) async {
        #if DEBUG
        guard let url = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                print("❌ Error fetching certificate: \(error)")
                return
            }

            print("⚠️ Note: Use openssl command instead for accurate fingerprints:")
            print("   echo | openssl s_client -connect \(url.host ?? ""):\(url.port ?? 443) 2>/dev/null | openssl x509 -fingerprint -sha256 -noout")
        }
        task.resume()
        #endif
    }
}
