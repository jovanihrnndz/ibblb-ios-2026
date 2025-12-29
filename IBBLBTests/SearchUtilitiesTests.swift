//
//  SearchUtilitiesTests.swift
//  IBBLBTests
//
//  Unit tests for search utilities: text normalization, year extraction, synonym expansion.
//

import XCTest
@testable import IBBLB

final class SearchUtilitiesTests: XCTestCase {

    // MARK: - normalizeText Tests

    func testNormalizeText_lowercase() {
        XCTAssertEqual(SearchUtilities.normalizeText("HELLO"), "hello")
        XCTAssertEqual(SearchUtilities.normalizeText("Hello World"), "hello world")
    }

    func testNormalizeText_removesAccents() {
        XCTAssertEqual(SearchUtilities.normalizeText("Jóvenes"), "jovenes")
        XCTAssertEqual(SearchUtilities.normalizeText("Música"), "musica")
        XCTAssertEqual(SearchUtilities.normalizeText("Conferéncia"), "conferencia")
        XCTAssertEqual(SearchUtilities.normalizeText("señor"), "senor")
    }

    func testNormalizeText_collapsesWhitespace() {
        XCTAssertEqual(SearchUtilities.normalizeText("hello   world"), "hello world")
        XCTAssertEqual(SearchUtilities.normalizeText("  hello  world  "), "hello world")
        XCTAssertEqual(SearchUtilities.normalizeText("a\t\nb"), "a b")
    }

    func testNormalizeText_removesPunctuation() {
        XCTAssertEqual(SearchUtilities.normalizeText("hello, world!"), "hello world")
        XCTAssertEqual(SearchUtilities.normalizeText("youth-conference"), "youth conference")
        XCTAssertEqual(SearchUtilities.normalizeText("test's"), "test s")
    }

    func testNormalizeText_preservesNumbers() {
        XCTAssertEqual(SearchUtilities.normalizeText("2025"), "2025")
        XCTAssertEqual(SearchUtilities.normalizeText("yc25"), "yc25")
        XCTAssertEqual(SearchUtilities.normalizeText("Conferencia 2025"), "conferencia 2025")
    }

    func testNormalizeText_complexInput() {
        XCTAssertEqual(
            SearchUtilities.normalizeText("Conferencia de Jóvenes 2025"),
            "conferencia de jovenes 2025"
        )
        XCTAssertEqual(
            SearchUtilities.normalizeText("  YC  25  "),
            "yc 25"
        )
    }

    func testNormalizeText_emptyInput() {
        XCTAssertEqual(SearchUtilities.normalizeText(""), "")
        XCTAssertEqual(SearchUtilities.normalizeText("   "), "")
    }

    // MARK: - extractYearTokens Tests

    func testExtractYearTokens_fourDigitYear() {
        let result = SearchUtilities.extractYearTokens("jovenes 2025")
        XCTAssertEqual(result.years, [2025])
        XCTAssertEqual(result.normalized, "jovenes")
    }

    func testExtractYearTokens_twoDigitStandalone() {
        let result = SearchUtilities.extractYearTokens("yc 25")
        XCTAssertEqual(result.years, [2025])
        XCTAssertEqual(result.normalized, "yc")
    }

    func testExtractYearTokens_twoDigitAttached() {
        let result = SearchUtilities.extractYearTokens("yc25")
        XCTAssertEqual(result.years, [2025])
        XCTAssertEqual(result.normalized, "yc")
    }

    func testExtractYearTokens_multipleYears() {
        let result = SearchUtilities.extractYearTokens("2024 2025")
        XCTAssertEqual(result.years.sorted(), [2024, 2025])
        XCTAssertEqual(result.normalized, "")
    }

    func testExtractYearTokens_noYear() {
        let result = SearchUtilities.extractYearTokens("jovenes")
        XCTAssertEqual(result.years, [])
        XCTAssertEqual(result.normalized, "jovenes")
    }

    func testExtractYearTokens_mixedInput() {
        let result = SearchUtilities.extractYearTokens("youth conference 2025")
        XCTAssertEqual(result.years, [2025])
        XCTAssertEqual(result.normalized, "youth conference")
    }

    func testExtractYearTokens_yearRangeValidation() {
        // Year outside 2000-2099 range should still be extracted if it matches pattern
        let result = SearchUtilities.extractYearTokens("2050")
        XCTAssertEqual(result.years, [2050])
    }

    // MARK: - expandSynonyms Tests

    func testExpandSynonyms_conf() {
        let variants = SearchUtilities.expandSynonyms("conf")
        XCTAssertTrue(variants.contains("conf"))
        XCTAssertTrue(variants.contains("conference"))
        XCTAssertTrue(variants.contains("conferencia"))
    }

    func testExpandSynonyms_conference() {
        let variants = SearchUtilities.expandSynonyms("conference")
        XCTAssertTrue(variants.contains("conference"))
        XCTAssertTrue(variants.contains("conf"))
        XCTAssertTrue(variants.contains("conferencia"))
    }

    func testExpandSynonyms_jovenes() {
        let variants = SearchUtilities.expandSynonyms("jovenes")
        XCTAssertTrue(variants.contains("jovenes"))
        XCTAssertTrue(variants.contains("youth"))
    }

    func testExpandSynonyms_youth() {
        let variants = SearchUtilities.expandSynonyms("youth")
        XCTAssertTrue(variants.contains("youth"))
        XCTAssertTrue(variants.contains("jovenes"))
    }

    func testExpandSynonyms_noMatch() {
        let variants = SearchUtilities.expandSynonyms("fundamentos")
        XCTAssertEqual(variants.count, 1)
        XCTAssertTrue(variants.contains("fundamentos"))
    }

    func testExpandSynonyms_youthConference() {
        let variants = SearchUtilities.expandSynonyms("youth conference")
        XCTAssertTrue(variants.contains("youth conference"))
        // Should also expand to just "youth" and "jovenes"
        XCTAssertTrue(variants.contains("youth") || variants.contains("jovenes"))
    }

    // MARK: - buildAliases Tests

    func testBuildAliases_includesTitle() {
        let item = PlaylistRegistryItem(
            id: "1",
            youtubePlaylistId: "PL123",
            title: "Conferencia de Jóvenes 2025",
            kind: .event,
            contentType: .sermon,
            seriesId: "youth-conference",
            year: 2025,
            slug: "youth-conference-2025",
            tags: ["series:youth-conference"],
            aliases: ["youth conference", "jovenes"],
            shortCode: "yc"
        )

        let aliases = SearchUtilities.buildAliases(for: item)

        // Should contain normalized title
        XCTAssertTrue(aliases.contains("conferencia de jovenes 2025"))
    }

    func testBuildAliases_includesExplicitAliases() {
        let item = PlaylistRegistryItem(
            id: "1",
            youtubePlaylistId: "PL123",
            title: "Conferencia de Jóvenes 2025",
            kind: .event,
            contentType: .sermon,
            seriesId: "youth-conference",
            year: 2025,
            slug: "youth-conference-2025",
            tags: [],
            aliases: ["youth conference", "jovenes"],
            shortCode: "yc"
        )

        let aliases = SearchUtilities.buildAliases(for: item)

        XCTAssertTrue(aliases.contains("youth conference"))
        XCTAssertTrue(aliases.contains("jovenes"))
    }

    func testBuildAliases_generatesShortCodeVariants() {
        let item = PlaylistRegistryItem(
            id: "1",
            youtubePlaylistId: "PL123",
            title: "Conferencia de Jóvenes 2025",
            kind: .event,
            contentType: .sermon,
            seriesId: "youth-conference",
            year: 2025,
            slug: "youth-conference-2025",
            tags: [],
            aliases: [],
            shortCode: "yc"
        )

        let aliases = SearchUtilities.buildAliases(for: item)

        // Should generate: yc25, yc 25, yc2025, yc 2025
        XCTAssertTrue(aliases.contains("yc25"))
        XCTAssertTrue(aliases.contains("yc 25"))
        XCTAssertTrue(aliases.contains("yc2025"))
        XCTAssertTrue(aliases.contains("yc 2025"))
    }

    func testBuildAliases_includesSeriesId() {
        let item = PlaylistRegistryItem(
            id: "1",
            youtubePlaylistId: "PL123",
            title: "Test",
            kind: .event,
            contentType: .sermon,
            seriesId: "youth-conference",
            year: 2025,
            slug: "test",
            tags: [],
            aliases: [],
            shortCode: nil
        )

        let aliases = SearchUtilities.buildAliases(for: item)

        XCTAssertTrue(aliases.contains("youth conference"))
        // Also adds Spanish variants for youth-conference
        XCTAssertTrue(aliases.contains("jovenes"))
        XCTAssertTrue(aliases.contains("conferencia de jovenes"))
    }

    // MARK: - Integration Tests

    func testSearchFlow_yc25() {
        // Simulate the full search flow for "yc25"
        let query = "yc25"

        // Step 1: Normalize
        let normalized = SearchUtilities.normalizeText(query)
        XCTAssertEqual(normalized, "yc25")

        // Step 2: Extract years
        let yearResult = SearchUtilities.extractYearTokens(normalized)
        XCTAssertEqual(yearResult.years, [2025])
        XCTAssertEqual(yearResult.normalized, "yc")

        // Step 3: Expand synonyms
        let variants = SearchUtilities.expandSynonyms(yearResult.normalized)
        XCTAssertTrue(variants.contains("yc"))
    }

    func testSearchFlow_jovenесWithAccent() {
        // Simulate search for "Jóvenes" (with accent)
        let query = "Jóvenes"

        // Step 1: Normalize (should remove accent)
        let normalized = SearchUtilities.normalizeText(query)
        XCTAssertEqual(normalized, "jovenes")

        // Step 2: Expand synonyms (should include "youth")
        let variants = SearchUtilities.expandSynonyms(normalized)
        XCTAssertTrue(variants.contains("jovenes"))
        XCTAssertTrue(variants.contains("youth"))
    }
}
