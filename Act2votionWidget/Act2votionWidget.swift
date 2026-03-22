//
//  Act2votionWidget.swift
//  Act2votionWidget
//
//  Created by Jun Min Kim on 3/17/26.
//

import WidgetKit
import SwiftUI

struct DevotionalEntry: TimelineEntry {
    let date: Date
    let bookName: String
    let reference: String
    let isEmpty: Bool
}

struct DevotionalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DevotionalEntry {
        DevotionalEntry(date: Date(), bookName: "John", reference: "8:1-11", isEmpty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DevotionalEntry) -> Void) {
        completion(makeEntry(forDate: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DevotionalEntry>) -> Void) {
        let entries = buildDailyEntries(forNextDays: 7)
        let refreshDate = nextFourAMEST()
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    /// Creates one entry per calendar day for the next `numberOfDays` days.
    /// Each entry's `date` is anchored to midnight of that day so WidgetKit advances
    /// the displayed date at midnight rather than waiting for the next 4 AM refresh.
    private func buildDailyEntries(forNextDays numberOfDays: Int) -> [DevotionalEntry] {
        let calendar = Calendar.current
        let todayMidnight = calendar.startOfDay(for: Date())

        return (0..<numberOfDays).compactMap { dayOffset in
            guard let dayMidnight = calendar.date(byAdding: .day, value: dayOffset, to: todayMidnight) else { return nil }
            return makeEntry(forDate: dayMidnight)
        }
    }

    private func makeEntry(forDate date: Date) -> DevotionalEntry {
        if let devotional = DevotionalStore.shared.devotional(for: date) {
            let components = devotional.verseComponents
            return DevotionalEntry(date: date, bookName: components.bookName, reference: components.reference, isEmpty: false)
        }
        return DevotionalEntry(date: date, bookName: "", reference: "", isEmpty: true)
    }

    private func nextFourAMEST() -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 4
        components.minute = 0
        components.second = 0
        guard var candidate = calendar.date(from: components) else { return now }
        if candidate <= now {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}

struct Act2votionWidgetEntryView: View {
    var entry: DevotionalEntry

    var body: some View {
        if entry.isEmpty {
            Text("Open app to load")
                .font(.custom("Georgia", size: 13))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.date, style: .date)
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(.secondary)
                Spacer().frame(maxHeight: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.bookName)
                        .font(.custom("Georgia", size: 17))
                        .foregroundStyle(.primary)
                    Text(entry.reference)
                        .font(.custom("Georgia-Bold", size: 60))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}

struct Act2votionWidget: Widget {
    let kind: String = "Act2votionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevotionalTimelineProvider()) { entry in
            Act2votionWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's Devotional")
        .description("Shows today's devotional book and passage.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    Act2votionWidget()
} timeline: {
    DevotionalEntry(date: .now, bookName: "John", reference: "8:1-11", isEmpty: false)
}
