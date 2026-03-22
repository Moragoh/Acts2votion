//
//  DevotionalView.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

struct DevotionalView: View {
    @State private var viewModel = DevotionalViewModel()

    var body: some View {
        content
            .task {
                await viewModel.loadDevotionals()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            Text("No devotional today")
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let devotionals):
            TabView(selection: $viewModel.selectedDateID) {
                ForEach(devotionals) { devotional in
                    devotionalPage(devotional)
                        .tag(devotional.date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func devotionalPage(_ devotional: ParsedDevotional) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                dateLabel(for: devotional.date)
                    .padding(.bottom, 16)

                Text(devotional.displayVerses)
                    .font(.custom("Georgia", size: 20))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.bottom, 10)

                if isMemoryVerse(devotional) {
                    memoryVerseBody(devotional.rawContent)
                } else {
                    discussionSections(devotional.sections)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private func dateLabel(for dateString: String) -> some View {
        Text(formattedDate(dateString))
            .font(.custom("Georgia", size: 12))
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func formattedDate(_ isoDateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: isoDateString) else { return isoDateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy"
        displayFormatter.timeZone = TimeZone(identifier: "UTC")
        return displayFormatter.string(from: date)
    }

    private func memoryVerseBody(_ rawContent: String) -> some View {
        Text(rawContent)
            .font(.custom("Georgia", size: 16))
            .italic()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func discussionSections(_ sections: [ContentSection]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(sections.indices, id: \.self) { sectionIndex in
                sectionView(sections[sectionIndex])
            }
        }
    }

    private func sectionView(_ section: ContentSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subheading = section.subheading {
                Text(subheading)
                    .font(.custom("Georgia", size: 15))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            ForEach(section.bulletPoints.indices, id: \.self) { bulletIndex in
                bulletPointRow(section.bulletPoints[bulletIndex])
            }
        }
    }

    private func bulletPointRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.tertiary)
                .frame(width: 10, alignment: .leading)
            Text(text)
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func isMemoryVerse(_ devotional: ParsedDevotional) -> Bool {
        devotional.type == "memory_verse"
    }
}
