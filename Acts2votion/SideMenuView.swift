//
//  SideMenuView.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

#if os(iOS)
struct SideMenuView: View {
    let devotionals: [ParsedDevotional]
    @Binding var selectedDateID: String
    let onDateSelected: (String) -> Void

    private var groupedByMonth: [MonthGroup] {
        let grouped = Dictionary(grouping: devotionals) { devotional in
            String(devotional.date.prefix(7))
        }
        return grouped
            .map { yearMonthKey, entries in
                MonthGroup(
                    id: yearMonthKey,
                    title: formattedMonthTitle(yearMonthKey),
                    devotionals: entries.sorted { $0.date < $1.date }
                )
            }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(groupedByMonth) { monthGroup in
                        Section {
                            ForEach(monthGroup.devotionals) { devotional in
                                dateRow(devotional)
                            }
                        } header: {
                            monthHeader(monthGroup.title)
                        }
                    }
                }
            }
            .background(.clear)
            .onAppear {
                scrollProxy.scrollTo(selectedDateID, anchor: .center)
            }
        }
    }

    private func monthHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("Georgia", size: 11))
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.clear)
    }

    private func dateRow(_ devotional: ParsedDevotional) -> some View {
        let isSelected = devotional.date == selectedDateID
        return HStack(spacing: 0) {
            Rectangle()
                .fill(isSelected ? Color.primary : Color.clear)
                .frame(width: 3)
            Text(dayNumber(from: devotional.date))
                .font(.custom("Georgia", size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.primary.opacity(0.1) : Color.clear)
        }
        .id(devotional.date)
        .contentShape(Rectangle())
        .onTapGesture {
            onDateSelected(devotional.date)
        }
    }

    private func dayNumber(from isoDateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: isoDateString) else { return isoDateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d"
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

private struct MonthGroup: Identifiable {
    let id: String
    let title: String
    let devotionals: [ParsedDevotional]
}
#endif
