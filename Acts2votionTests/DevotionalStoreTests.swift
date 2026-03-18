//
//  DevotionalStoreTests.swift
//  Acts2votionTests
//
//  Created by Jun Min Kim on 3/17/26.
//

import Testing
import Foundation
@testable import Acts2votion

// MARK: - Mock URLProtocol

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Tests

struct DevotionalStoreTests {

    // MARK: - JSON Decoding

    @Test func decodesValidJSON() throws {
        let json = """
        [{"date":"2026-03-17","type":"bible_text","verses":"John 8:1","content":"John 8:1\\n• He went."}]
        """.data(using: .utf8)!

        let devotionals = try JSONDecoder().decode([Devotional].self, from: json)

        #expect(devotionals.count == 1)
        #expect(devotionals[0].date == "2026-03-17")
        #expect(devotionals[0].type == "bible_text")
        #expect(devotionals[0].verses == "John 8:1")
        #expect(devotionals[0].content == "John 8:1\n• He went.")
    }

    @Test func decodesMemoryVerseType() throws {
        let json = """
        [{"date":"2026-03-17","type":"memory_verse","verses":"Psalm 23:1","content":"The Lord is my shepherd."}]
        """.data(using: .utf8)!

        let devotionals = try JSONDecoder().decode([Devotional].self, from: json)

        #expect(devotionals[0].type == "memory_verse")
        #expect(devotionals[0].content == "The Lord is my shepherd.")
    }

    // MARK: - Fetch + Cache

    @Test func fetchIfNeededWritesCacheWhenEmpty() async throws {
        let cacheURL = makeTempCacheURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let session = makeMockSession(returning: makeDevotionalJSON(date: todayString))
        let store = DevotionalStore(cacheFileURL: cacheURL, urlSession: session)

        await store.fetchIfNeeded()

        let cached = try Data(contentsOf: cacheURL)
        let devotionals = try JSONDecoder().decode([Devotional].self, from: cached)
        #expect(devotionals.first?.date == todayString)
    }

    @Test func fetchIfNeededSkipsNetworkWhenTodayIsCached() async throws {
        let cacheURL = makeTempCacheURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        try makeDevotionalJSON(date: todayString).write(to: cacheURL)

        var fetchCalled = false
        MockURLProtocol.handler = { _ in
            fetchCalled = true
            throw URLError(.unknown)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let store = DevotionalStore(cacheFileURL: cacheURL, urlSession: URLSession(configuration: config))

        await store.fetchIfNeeded()

        #expect(!fetchCalled)
    }

    @Test func fetchIfNeededOverwritesCacheWithFreshData() async throws {
        let cacheURL = makeTempCacheURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        // Cache has a stale entry from yesterday
        let yesterday = dateString(daysOffset: -1)
        try makeDevotionalJSON(date: yesterday).write(to: cacheURL)

        // Server returns today's entry
        let session = makeMockSession(returning: makeDevotionalJSON(date: todayString))
        let store = DevotionalStore(cacheFileURL: cacheURL, urlSession: session)

        await store.fetchIfNeeded()

        let cached = try Data(contentsOf: cacheURL)
        let devotionals = try JSONDecoder().decode([Devotional].self, from: cached)
        #expect(devotionals.first?.date == todayString)
    }

    // MARK: - todaysDevotional()

    @Test func todaysDevotionalReturnsMatchFromCache() throws {
        let cacheURL = makeTempCacheURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        try makeDevotionalJSON(date: todayString).write(to: cacheURL)

        let result = DevotionalStore(cacheFileURL: cacheURL).todaysDevotional()

        #expect(result?.date == todayString)
        #expect(result?.verses == "John 1:1")
    }

    @Test func todaysDevotionalLooksBackWhenTodayIsMissing() throws {
        let cacheURL = makeTempCacheURL()
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let yesterday = dateString(daysOffset: -1)
        try makeDevotionalJSON(date: yesterday).write(to: cacheURL)

        let result = DevotionalStore(cacheFileURL: cacheURL).todaysDevotional()

        #expect(result?.date == yesterday)
    }

    @Test func todaysDevotionalReturnsNilWhenCacheIsEmpty() throws {
        let result = DevotionalStore(cacheFileURL: nil).todaysDevotional()
        #expect(result == nil)
    }

    // MARK: - Date lookback logic

    @Test func findMostRecentReturnsNilWhenAllDatesAreOlderThanLookbackWindow() {
        let store = DevotionalStore(cacheFileURL: nil)
        let tooOld = Devotional(date: "2020-01-01", type: "bible_text", verses: "X", content: "")
        #expect(store.findMostRecentDevotionalOnOrBeforeToday(in: [tooOld]) == nil)
    }

    @Test func findMostRecentPrefersTodayOverYesterday() {
        let store = DevotionalStore(cacheFileURL: nil)
        let yesterday = Devotional(date: dateString(daysOffset: -1), type: "bible_text", verses: "Old", content: "")
        let today = Devotional(date: todayString, type: "bible_text", verses: "New", content: "")

        let result = store.findMostRecentDevotionalOnOrBeforeToday(in: [yesterday, today])

        #expect(result?.verses == "New")
    }
}

// MARK: - Helpers

private extension DevotionalStoreTests {
    var todayString: String { dateString(daysOffset: 0) }

    func dateString(daysOffset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }

    func makeTempCacheURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    func makeMockSession(returning data: Data) -> URLSession {
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func makeDevotionalJSON(date: String, type: String = "bible_text") -> Data {
        """
        [{"date":"\(date)","type":"\(type)","verses":"John 1:1","content":"John 1:1\\n• In the beginning was the Word."}]
        """.data(using: .utf8)!
    }
}
