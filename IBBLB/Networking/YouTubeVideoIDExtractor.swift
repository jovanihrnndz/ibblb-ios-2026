//
//  YouTubeVideoIDExtractor.swift
//  IBBLB
//
//  Utility to extract YouTube video ID from various URL formats
//

import Foundation

enum YouTubeVideoIDExtractor {
    /// Extracts YouTube video ID from various URL formats or returns the string if it's already an ID
    /// Supports:
    /// - Full URLs: https://www.youtube.com/watch?v=VIDEO_ID
    /// - Short URLs: https://youtu.be/VIDEO_ID
    /// - Embed URLs: https://www.youtube.com/embed/VIDEO_ID
    /// - Direct IDs: VIDEO_ID
    static func extractVideoID(from string: String?) -> String? {
        guard let input = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else {
            return nil
        }

        // If it's already just an ID (no slashes, no query params, reasonable length)
        // YouTube IDs are typically 11 characters
        if !input.contains("/") && !input.contains("?") && !input.contains("&") && input.count <= 20 {
            return input
        }
        
        // Try to extract from various URL patterns
        // YouTube IDs can be 11-12 characters (some older videos have 12)
        let patterns = [
            // Standard watch URL: https://www.youtube.com/watch?v=VIDEO_ID
            #"youtube\.com/watch\?v=([a-zA-Z0-9_-]{11,12})"#,
            // Short URL: https://youtu.be/VIDEO_ID
            #"youtu\.be/([a-zA-Z0-9_-]{11,12})"#,
            // Embed URL: https://www.youtube.com/embed/VIDEO_ID
            #"youtube\.com/embed/([a-zA-Z0-9_-]{11,12})"#,
            // Mobile URL: https://m.youtube.com/watch?v=VIDEO_ID
            #"m\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11,12})"#,
            // Short URL with params: https://youtu.be/VIDEO_ID?t=123
            #"youtu\.be/([a-zA-Z0-9_-]{11,12})(?:\?|$)"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(input.startIndex..., in: input)
                if let match = regex.firstMatch(in: input, options: [], range: range),
                   let videoIDRange = Range(match.range(at: 1), in: input) {
                    let extracted = String(input[videoIDRange])
                    return extracted
                }
            }
        }

        // If no pattern matched, return the original string if it looks like an ID
        // This handles edge cases where the ID might be slightly different
        return input.count <= 20 ? input : nil
    }
}

