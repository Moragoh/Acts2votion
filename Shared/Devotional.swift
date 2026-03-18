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

struct ParsedDevotional {
    let date: String
    let type: String
    let verses: String
    let sections: [ContentSection]  // empty for memory_verse
    let rawContent: String          // kept for memory_verse plain display
}
