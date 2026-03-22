//
//  Devotional.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

// What json files are stored as 
import Foundation

struct Devotional: Codable {
    let date: String      // "2026-01-19"
    let type: String      // "bible_text" | "memory_verse"
    let verses: String    // "John 8:1-11 (ESV)"
    let content: String   // raw string with \n delimiters
}

struct ContentSection {
    let subheading: String?
    let bulletPoints: [String]
}

struct ParsedDevotional: Identifiable {
    var id: String { date }
    let date: String
    let type: String
    let verses: String
    let sections: [ContentSection]  // empty for memory_verse
    let rawContent: String          // kept for memory_verse plain display
}

struct VerseComponents {
    let bookName: String
    let reference: String
}

extension ParsedDevotional {
    /// Returns the verse reference with any translation suffix like "(ESV)" removed.
    var displayVerses: String {
        strippingTranslationSuffix(from: verses)
    }

    /// Splits e.g. "John 8:1-11 (ESV)" into bookName="John", reference="8:1-11"
    var verseComponents: VerseComponents {
        let stripped = strippingTranslationSuffix(from: verses)
        let (book, reference) = splittingBookFromReference(in: stripped)
        return VerseComponents(bookName: book, reference: reference)
    }

    private func strippingTranslationSuffix(from string: String) -> String {
        if let parenRange = string.range(of: " (", options: .backwards) {
            return String(string[..<parenRange.lowerBound])
        }
        return string
    }

    private func splittingBookFromReference(in string: String) -> (book: String, reference: String) {
        if let lastSpace = string.lastIndex(of: " ") {
            let book = String(string[..<lastSpace])
            let reference = String(string[string.index(after: lastSpace)...])
            return (book, reference)
        }
        return (string, "")
    }
}
