//
//  MacSidebarView.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

#if os(macOS)
struct MacSidebarView: View {
    let devotionals: [ParsedDevotional]
    @Binding var selectedDateID: String

    @State private var listSelection: String?

    private var groupedByMonth: [MacMonthGroup] {
        let grouped = Dictionary(grouping: devotionals) { devotional in
            String(devotional.date.prefix(7))
        }
        return grouped
            .map { yearMonthKey, entries in
                MacMonthGroup(
                    id: yearMonthKey,
                    title: formattedMonthTitle(yearMonthKey),
                    devotionals: entries.sorted { $0.date < $1.date }
                )
            }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            sidebarList
                .onAppear {
                    listSelection = selectedDateID
                    scrollProxy.scrollTo(selectedDateID, anchor: .center)
                }
                .onChange(of: listSelection) { _, newValue in
                    if let dateID = newValue {
                        selectedDateID = dateID
                    }
                }
                .onChange(of: selectedDateID) { _, newValue in
                    listSelection = newValue
                    scrollProxy.scrollTo(newValue, anchor: .center)
                }
        }
    }

    private var sidebarList: some View {
        List(selection: $listSelection) {
            ForEach(groupedByMonth) { monthGroup in
                Section(monthGroup.title) {
                    ForEach(monthGroup.devotionals) { devotional in
                        Text(dayAndWeekday(from: devotional.date))
                            .font(.custom("Georgia", size: 20))
                            .padding(.vertical, 8)
                            .tag(devotional.date)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func dayAndWeekday(from isoDateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        guard let date = isoFormatter.date(from: isoDateString) else { return isoDateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d EEE"
        displayFormatter.timeZone = TimeZone(identifier: "UTC")
        return displayFormatter.string(from: date)
    }

    private func formattedMonthTitle(_ yearMonthKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: yearMonthKey) else { return yearMonthKey }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yyyy"
        displayFormatter.timeZone = TimeZone(identifier: "UTC")
        return displayFormatter.string(from: date)
    }
}

private struct MacMonthGroup: Identifiable {
    let id: String
    let title: String
    let devotionals: [ParsedDevotional]
}
#endif
