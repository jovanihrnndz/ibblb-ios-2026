//
//  YouTubeThumbnail.swift
//  IBBLB
//
//  Utility for generating YouTube thumbnail URLs with fallback support
//

import Foundation

/// YouTube thumbnail quality options
enum YouTubeThumbnailQuality: String, CaseIterable {
    case maxres = "maxresdefault"
    case sd = "sddefault"
    case hq = "hqdefault"
    
    var filename: String {
        return "\(rawValue).jpg"
    }
}

enum YouTubeThumbnail {
    /// Extracts YouTube video ID from a thumbnail URL
    /// Supports URLs like: https://i.ytimg.com/vi/VIDEO_ID/maxresdefault.jpg
    static func videoId(from url: URL) -> String? {
        return videoId(from: url.absoluteString)
    }
    
    /// Extracts YouTube video ID from a thumbnail URL string
    static func videoId(from urlString: String) -> String? {
        // Pattern: https://i.ytimg.com/vi/VIDEO_ID/quality.jpg
        let pattern = #"i\.ytimg\.com/vi/([a-zA-Z0-9_-]{11,12})/"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive) {
            let range = NSRange(urlString.startIndex..., in: urlString)
            if let match = regex.firstMatch(in: urlString, options: [], range: range),
               let videoIDRange = Range(match.range(at: 1), in: urlString) {
                return String(urlString[videoIDRange])
            }
        }
        
        return nil
    }
    
    /// Validates a YouTube video ID format
    /// YouTube IDs are typically 11 characters: alphanumeric, hyphens, underscores
    private static func isValidVideoId(_ videoId: String) -> Bool {
        let videoIdPattern = "^[a-zA-Z0-9_-]{11,12}$"
        guard let regex = try? NSRegularExpression(pattern: videoIdPattern) else {
            return false
        }
        let range = NSRange(videoId.startIndex..., in: videoId)
        return regex.firstMatch(in: videoId, range: range) != nil
    }

    /// Generates a YouTube thumbnail URL for a given video ID and quality
    /// SECURITY: Validates video ID to prevent path traversal and injection
    /// - Returns: URL if video ID is valid, nil otherwise
    static func url(videoId: String, quality: YouTubeThumbnailQuality) -> URL? {
        // Validate video ID format
        guard isValidVideoId(videoId) else {
            #if DEBUG
            print("⚠️ YouTubeThumbnail: Invalid video ID format: '\(videoId)'")
            #endif
            return nil
        }

        let urlString = "https://i.ytimg.com/vi/\(videoId)/\(quality.filename)"
        return URL(string: urlString)
    }

    /// Generates fallback URLs for a YouTube video ID
    /// Returns URLs in order: [maxresdefault, sddefault, hqdefault]
    /// Only returns valid URLs (invalid video IDs result in empty array)
    static func fallbackURLs(videoId: String) -> [URL] {
        return YouTubeThumbnailQuality.allCases.compactMap { quality in
            url(videoId: videoId, quality: quality)
        }
    }
    
    /// Generates fallback URLs from an existing thumbnail URL
    /// If the URL is not a YouTube thumbnail URL, returns empty array
    static func fallbackURLs(from url: URL) -> [URL] {
        guard let videoId = videoId(from: url) else {
            return []
        }
        return fallbackURLs(videoId: videoId)
    }
    
    /// Generates fallback URLs from a thumbnail URL string
    static func fallbackURLs(from urlString: String) -> [URL] {
        guard let videoId = videoId(from: urlString) else {
            return []
        }
        return fallbackURLs(videoId: videoId)
    }
    
    /// Checks if a URL is a YouTube thumbnail URL
    static func isYouTubeThumbnail(_ url: URL) -> Bool {
        return url.absoluteString.contains("i.ytimg.com/vi/")
    }
    
    /// Checks if a URL string is a YouTube thumbnail URL
    static func isYouTubeThumbnail(_ urlString: String) -> Bool {
        return urlString.contains("i.ytimg.com/vi/")
    }
}

