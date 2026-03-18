//
//  DevotionalParser.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

// Functions for parsing the raw Devotional into UI friendly components.

import Foundation

enum DevotionalParser {

    // MARK: - Public interface

    static func buildParsedDevotional(from devotional: Devotional) -> ParsedDevotional {
        let sections = isMemoryVerse(devotional) ? [] : parse(content: devotional.content)
        return ParsedDevotional(
            date: devotional.date,
            type: devotional.type,
            verses: devotional.verses,
            sections: sections,
            rawContent: devotional.content
        )
    }

    static func parse(content: String) -> [ContentSection] {
        let validLines = extractValidLines(from: content)
        return buildSections(from: validLines)
    }

    // MARK: - Parsing steps

    private static func extractValidLines(from content: String) -> [String] {
        return content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func buildSections(from lines: [String]) -> [ContentSection] {
        var sections: [ContentSection] = []
        var currentSubheading: String? = nil
        var currentBullets: [String] = []

        for line in lines {
            if isBullet(line) {
                currentBullets.append(bulletText(from: line))
            } else if isValidSubheading(line) {
                let pendingSectionIsNonEmpty = currentSubheading != nil || !currentBullets.isEmpty
                if pendingSectionIsNonEmpty {
                    sections.append(ContentSection(subheading: currentSubheading, bulletPoints: currentBullets))
                }
                currentSubheading = line
                currentBullets = []
            }
            // Lines that are neither bullets nor valid subheadings are artifacts — silently dropped
        }

        let remainderIsNonEmpty = currentSubheading != nil || !currentBullets.isEmpty
        if remainderIsNonEmpty {
            sections.append(ContentSection(subheading: currentSubheading, bulletPoints: currentBullets))
        }

        return sections
    }

    // MARK: - Line classification

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("•")
    }

    private static func bulletText(from line: String) -> String {
        String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    /// A valid subheading must match a book name followed by a chapter/verse number,
    /// e.g. "John 1:1" or "Romans 8". Lines that don't match are treated as artifacts.
    private static func isValidSubheading(_ line: String) -> Bool {
        let bookNameFollowedByChapterPattern = #"^[A-Za-z]+ \d+"#
        return line.range(of: bookNameFollowedByChapterPattern, options: .regularExpression) != nil
    }

    private static func isMemoryVerse(_ devotional: Devotional) -> Bool {
        devotional.type == "memory_verse"
    }
}
