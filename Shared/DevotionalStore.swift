//
//  DevotionalStore.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import Foundation
import WidgetKit

final class DevotionalStore {

    static let shared = DevotionalStore()

    private static let appGroupIdentifier = "group.com.moragoh.act2votion"
    private static let remoteDevotionalURL = URL(string: "https://moragoh.github.io/Act2votion-server/devotional.json")!
    private static let cacheFileName = "devotionals.json"
    private static let maximumDaysToLookBack = 7

    private let cacheFileURL: URL?
    private let urlSession: URLSession

    private init() {
        self.cacheFileURL = DevotionalStore.buildAppGroupCacheFileURL()
        self.urlSession = .shared
    }

    /// Internal init used by tests to supply a custom cache file location and URLSession.
    init(cacheFileURL: URL?, urlSession: URLSession = .shared) {
        self.cacheFileURL = cacheFileURL
        self.urlSession = urlSession
    }

    // MARK: - Public interface

    /// Fetches fresh devotional data from the remote endpoint if today's entry is not already cached.
    /// Calls `WidgetCenter.shared.reloadAllTimelines()` after a successful write.
    func fetchIfNeeded() async {
        guard !todayIsAlreadyCached() else { return }
        await fetchAndWriteCache()
    }

    /// Synchronous read used by the widget. Returns the most recent devotional on or before today.
    func todaysDevotional() -> ParsedDevotional? {
        devotional(for: Date())
    }

    /// Returns the most recent devotional on or before the given reference date.
    /// Used by the widget to populate one entry per calendar day.
    func devotional(for referenceDate: Date) -> ParsedDevotional? {
        guard let devotionals = loadCachedDevotionals() else { return nil }
        guard let bestMatch = findMostRecentDevotionalOnOrBeforeToday(in: devotionals, referenceDate: referenceDate) else { return nil }
        return DevotionalParser.buildParsedDevotional(from: bestMatch)
    }

    /// Returns all cached devotionals, parsed and sorted by date ascending.
    func allCachedDevotionals() -> [ParsedDevotional] {
        guard let devotionals = loadCachedDevotionals() else { return [] }
        return devotionals
            .sorted { $0.date < $1.date }
            .map { DevotionalParser.buildParsedDevotional(from: $0) }
    }

    // MARK: - Cache management

    private func todayIsAlreadyCached() -> Bool {
        guard let devotionals = loadCachedDevotionals() else { return false }
        return devotionals.contains { $0.date == todayDateString() }
    }

    private func fetchAndWriteCache() async {
        do {
            let (data, _) = try await urlSession.data(from: DevotionalStore.remoteDevotionalURL)
            let devotionals = try JSONDecoder().decode([Devotional].self, from: data)
            try writeCache(devotionals: devotionals)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silent degradation — last known data remains in cache
        }
    }

    private func loadCachedDevotionals() -> [Devotional]? {
        guard let url = cacheFileURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Devotional].self, from: data)
    }

    private func writeCache(devotionals: [Devotional]) throws {
        guard let url = cacheFileURL else {
            throw DevotionalStoreError.cacheURLUnavailable
        }
        let encodedData = try JSONEncoder().encode(devotionals)
        try encodedData.write(to: url, options: .atomic)
    }

    // MARK: - Date resolution

    /// Walks backwards up to 7 days from `referenceDate` to find the most recent available entry.
    /// Ensures that weekends or missing dates fall back to the last known entry (e.g. Friday on Monday).
    /// Defaults to today when no `referenceDate` is supplied (preserves existing call sites and tests).
    func findMostRecentDevotionalOnOrBeforeToday(in devotionals: [Devotional], referenceDate: Date = Date()) -> Devotional? {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        for daysBack in 0...DevotionalStore.maximumDaysToLookBack {
            guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: startOfReferenceDay) else { continue }
            let targetDateString = dateString(for: targetDate)
            if let match = devotionals.first(where: { $0.date == targetDateString }) {
                return match
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func buildAppGroupCacheFileURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return nil }
        let cachesDirectory = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
        try? FileManager.default.createDirectory(at: cachesDirectory, withIntermediateDirectories: true)
        return cachesDirectory.appendingPathComponent(cacheFileName)
    }

    private func todayDateString() -> String {
        dateString(for: Date())
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    private func dateString(for date: Date) -> String {
        DevotionalStore.isoDateFormatter.string(from: date)
    }
}

enum DevotionalStoreError: Error {
    case cacheURLUnavailable
}
