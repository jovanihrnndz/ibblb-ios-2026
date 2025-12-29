import Foundation

/// Text normalization and search utilities for human-friendly sermon search
/// All methods are nonisolated to allow use from any actor context
enum SearchUtilities: Sendable {

    // MARK: - Text Normalization

    /// Normalize text for search matching:
    /// - Lowercases
    /// - Removes diacritics (accents)
    /// - Replaces non-alphanumeric with spaces
    /// - Collapses whitespace
    /// - Trims
    ///
    /// Example: "Jóvenes 2025" → "jovenes 2025"
    nonisolated static func normalizeText(_ input: String) -> String {
        input
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(
                of: "[^a-z0-9]",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Year Extraction

    /// Result of extracting year tokens from text
    struct YearExtractionResult: Sendable {
        /// Extracted years (e.g., [2025])
        let years: [Int]
        /// Normalized text with years removed
        let normalized: String
    }

    /// Extract year tokens from normalized text and return years + cleaned text
    ///
    /// Detects:
    /// - 4-digit years: 2000-2099
    /// - 2-digit tokens at word boundaries or end of words (e.g., "yc25" → 2025)
    ///
    /// Example: "yc25" → YearExtractionResult(years: [2025], normalized: "yc")
    /// Example: "jovenes 2025" → YearExtractionResult(years: [2025], normalized: "jovenes")
    nonisolated static func extractYearTokens(_ input: String) -> YearExtractionResult {
        var years = Set<Int>()
        var normalized = input

        // Match 4-digit years (2000-2099)
        let fourDigitPattern = "\\b(20[0-9]{2})\\b"
        if let regex = try? NSRegularExpression(pattern: fourDigitPattern) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            let matches = regex.matches(in: normalized, range: range)

            for match in matches.reversed() {
                if let yearRange = Range(match.range(at: 1), in: normalized) {
                    if let year = Int(normalized[yearRange]), year >= 2000, year <= 2099 {
                        years.insert(year)
                    }
                }
            }

            // Remove 4-digit years from normalized string
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                range: range,
                withTemplate: " "
            )
        }

        // Match standalone 2-digit tokens (00-99)
        let twoDigitPattern = "\\b([0-9]{2})\\b"
        if let regex = try? NSRegularExpression(pattern: twoDigitPattern) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            let matches = regex.matches(in: normalized, range: range)

            for match in matches.reversed() {
                if let digitRange = Range(match.range(at: 1), in: normalized) {
                    if let twoDigit = Int(normalized[digitRange]), twoDigit >= 0, twoDigit <= 99 {
                        let year = 2000 + twoDigit
                        years.insert(year)
                    }
                }
            }

            // Remove 2-digit tokens from normalized string
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                range: range,
                withTemplate: " "
            )
        }

        // Match 2-digit at end of alphanumeric sequence (e.g., "yc25")
        let attachedPattern = "([a-z]+)([0-9]{2})(?:\\s|$)"
        if let regex = try? NSRegularExpression(pattern: attachedPattern) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            let matches = regex.matches(in: normalized, range: range)

            for match in matches.reversed() {
                if let digitRange = Range(match.range(at: 2), in: normalized),
                   let wordRange = Range(match.range(at: 1), in: normalized) {
                    if let twoDigit = Int(normalized[digitRange]), twoDigit >= 0, twoDigit <= 99 {
                        let year = 2000 + twoDigit
                        years.insert(year)
                        // Replace "word25" with "word "
                        let wordPart = String(normalized[wordRange])
                        if let fullRange = Range(match.range, in: normalized) {
                            normalized.replaceSubrange(fullRange, with: wordPart + " ")
                        }
                    }
                }
            }
        }

        // Clean up normalized string
        normalized = normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return YearExtractionResult(
            years: years.sorted(),
            normalized: normalized
        )
    }

    // MARK: - Synonym Expansion

    /// Expand synonyms to generate search variants
    ///
    /// Currently supports:
    /// - conf ↔ conference ↔ conferencia
    /// - jovenes ↔ youth
    ///
    /// Returns a set of normalized variants for matching
    nonisolated static func expandSynonyms(_ normalized: String) -> Set<String> {
        var variants = Set<String>([normalized])

        // conf/conference/conferencia synonyms
        if normalized.contains("conf") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconf\\b",
                    with: "conference",
                    options: .regularExpression
                )
            )
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconf\\b",
                    with: "conferencia",
                    options: .regularExpression
                )
            )
        }
        if normalized.contains("conference") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconference\\b",
                    with: "conf",
                    options: .regularExpression
                )
            )
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconference\\b",
                    with: "conferencia",
                    options: .regularExpression
                )
            )
        }
        if normalized.contains("conferencia") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconferencia\\b",
                    with: "conf",
                    options: .regularExpression
                )
            )
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bconferencia\\b",
                    with: "conference",
                    options: .regularExpression
                )
            )
        }

        // jovenes/youth synonyms
        if normalized.contains("jovenes") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bjovenes\\b",
                    with: "youth",
                    options: .regularExpression
                )
            )
        }
        if normalized.contains("youth") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\byouth\\b",
                    with: "jovenes",
                    options: .regularExpression
                )
            )
        }

        // youth conference / jovenes conference combo
        if normalized.contains("youth conference") || normalized.contains("youth conf") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\byouth\\s+(?:conference|conf)\\b",
                    with: "youth",
                    options: .regularExpression
                )
            )
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\byouth\\s+(?:conference|conf)\\b",
                    with: "jovenes",
                    options: .regularExpression
                )
            )
        }
        if normalized.contains("jovenes conference") || normalized.contains("jovenes conf") {
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bjovenes\\s+(?:conference|conf)\\b",
                    with: "jovenes",
                    options: .regularExpression
                )
            )
            variants.insert(
                normalized.replacingOccurrences(
                    of: "\\bjovenes\\s+(?:conference|conf)\\b",
                    with: "youth",
                    options: .regularExpression
                )
            )
        }

        return variants
    }

    // MARK: - Alias Building

    /// Build searchable aliases for a playlist item
    /// Includes title, slug, series_id, tags, explicit aliases, and auto-generated short codes
    nonisolated static func buildAliases(for item: PlaylistRegistryItem) -> Set<String> {
        var aliasSet = Set<String>()

        // Add explicit aliases (normalized)
        for alias in item.aliases {
            let normalized = normalizeText(alias)
            if !normalized.isEmpty {
                aliasSet.insert(normalized)
            }
        }

        // Add normalized title, slug, series_id
        aliasSet.insert(normalizeText(item.title))
        aliasSet.insert(normalizeText(item.slug))

        if let seriesId = item.seriesId {
            aliasSet.insert(normalizeText(seriesId))
            // Add Spanish-friendly variants for known series
            if seriesId == "youth-conference" {
                aliasSet.insert("jovenes")
                aliasSet.insert("conferencia de jovenes")
            }
        }

        // Add normalized tags
        for tag in item.tags {
            aliasSet.insert(normalizeText(tag))
        }

        // Auto-generate short code aliases if short_code and year are present
        if let shortCode = item.shortCode, let year = item.year {
            let normalizedCode = normalizeText(shortCode)
            let year2Digit = year % 100

            // Generate variants: yc25, yc 25, yc2025, yc 2025
            aliasSet.insert("\(normalizedCode)\(year2Digit)")
            aliasSet.insert("\(normalizedCode) \(year2Digit)")
            aliasSet.insert("\(normalizedCode)\(year)")
            aliasSet.insert("\(normalizedCode) \(year)")
        }

        // Remove empty strings
        aliasSet.remove("")

        return aliasSet
    }
}
