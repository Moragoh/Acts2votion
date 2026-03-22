//
//  DevotionalView.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

struct DevotionalView: View {
    @State private var viewModel = DevotionalViewModel()

    private var verseTitleFontSize: CGFloat {
        #if os(macOS)
        return 52
        #else
        return 20
        #endif
    }

    private var bodyTextFontSize: CGFloat {
        #if os(macOS)
        return 32
        #else
        return 15
        #endif
    }

    private var memoryVerseFontSize: CGFloat {
        #if os(macOS)
        return 36
        #else
        return 16
        #endif
    }

    private var todayButtonFontSize: CGFloat {
        #if os(macOS)
        return 22
        #else
        return 12
        #endif
    }

    private var todayButtonArrowSize: CGFloat {
        #if os(macOS)
        return 18
        #else
        return 10
        #endif
    }

    private var contentHorizontalPadding: CGFloat {
        #if os(macOS)
        return 100
        #else
        return 24
        #endif
    }

    private var contentVerticalPadding: CGFloat {
        #if os(macOS)
        return 80
        #else
        return 32
        #endif
    }

    private var verseTitleBottomPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return 10
        #endif
    }

    private var dividerBottomPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return 10
        #endif
    }

    private var sectionSpacing: CGFloat {
        #if os(macOS)
        return 48
        #else
        return 24
        #endif
    }

    private var bulletGroupSpacing: CGFloat {
        #if os(macOS)
        return 20
        #else
        return 10
        #endif
    }

    private var bulletHorizontalSpacing: CGFloat {
        #if os(macOS)
        return 18
        #else
        return 10
        #endif
    }

    private var bulletFrameWidth: CGFloat {
        #if os(macOS)
        return 20
        #else
        return 10
        #endif
    }

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
            #if os(iOS)
            VStack(spacing: 0) {
                navigationHeader(currentDate: viewModel.selectedDateID)
                ZStack(alignment: .leading) {
                    TabView(selection: $viewModel.selectedDateID) {
                        ForEach(devotionals) { devotional in
                            devotionalPage(devotional)
                                .tag(devotional.date)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    SideMenuOverlay(
                        isMenuOpen: $viewModel.isMenuOpen,
                        devotionals: devotionals,
                        selectedDateID: $viewModel.selectedDateID
                    )
                }
            }
            #elseif os(macOS)
            macOSLayout(devotionals: devotionals)
            #endif
        }
    }

    private func navigationHeader(currentDate: String) -> some View {
        ZStack {
            Text(formattedDate(currentDate))
                .font(.custom("Georgia", size: 12))
                .fontWeight(.regular)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.8)

            HStack {
                hamburgerButton
                Spacer()
                if !viewModel.isOnToday {
                    todayButton
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func devotionalPage(_ devotional: ParsedDevotional) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text(devotional.displayVerses)
                    .font(.custom("Georgia", size: verseTitleFontSize))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.bottom, verseTitleBottomPadding)

                Divider()
                    .padding(.bottom, dividerBottomPadding)

                if isMemoryVerse(devotional) {
                    memoryVerseBody(devotional.rawContent)
                } else {
                    discussionSections(devotional.sections)
                }
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.vertical, contentVerticalPadding)
        }
    }

    private var todayButton: some View {
        Button {
            viewModel.goToToday()
        } label: {
            HStack(spacing: 3) {
                if !viewModel.todayIsAhead {
                    Image(systemName: "arrow.left")
                        .font(.system(size: todayButtonArrowSize))
                        .foregroundStyle(.secondary)
                }
                Text("Today")
                    .font(.custom("Georgia", size: todayButtonFontSize))
                    .foregroundStyle(.secondary)
                    .kerning(0.8)
                if viewModel.todayIsAhead {
                    Image(systemName: "arrow.right")
                        .font(.system(size: todayButtonArrowSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var hamburgerButton: some View {
        Button {
            viewModel.isMenuOpen.toggle()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    #if os(macOS)
    private func macOSLayout(devotionals: [ParsedDevotional]) -> some View {
        NavigationSplitView {
            MacSidebarView(
                devotionals: devotionals,
                selectedDateID: $viewModel.selectedDateID
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            VStack(spacing: 0) {
                macNavigationHeader(currentDate: viewModel.selectedDateID)
                if let devotional = viewModel.selectedDevotional {
                    devotionalPage(devotional)
                }
            }
        }
    }

    private func macNavigationHeader(currentDate: String) -> some View {
        HStack {
            Button {
                viewModel.goToPreviousDevotional()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canGoToPreviousDevotional)

            Spacer()

            Text(formattedDate(currentDate))
                .font(.custom("Georgia", size: 28))
                .fontWeight(.regular)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.8)

            Spacer()

            if !viewModel.isOnToday {
                todayButton
            }

            Button {
                viewModel.goToNextDevotional()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 28))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canGoToNextDevotional)
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 28)
    }
    #endif

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
            .font(.custom("Georgia", size: memoryVerseFontSize))
            .italic()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func discussionSections(_ sections: [ContentSection]) -> some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(sections.indices, id: \.self) { sectionIndex in
                sectionView(sections[sectionIndex])
            }
        }
    }

    private func sectionView(_ section: ContentSection) -> some View {
        VStack(alignment: .leading, spacing: bulletGroupSpacing) {
            if let subheading = section.subheading {
                Text(subheading)
                    .font(.custom("Georgia", size: bodyTextFontSize))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            ForEach(section.bulletPoints.indices, id: \.self) { bulletIndex in
                bulletPointRow(section.bulletPoints[bulletIndex])
            }
        }
    }

    private func bulletPointRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: bulletHorizontalSpacing) {
            Text("•")
                .font(.custom("Georgia", size: bodyTextFontSize))
                .foregroundStyle(.tertiary)
                .frame(width: bulletFrameWidth, alignment: .leading)
            Text(text)
                .font(.custom("Georgia", size: bodyTextFontSize))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func isMemoryVerse(_ devotional: ParsedDevotional) -> Bool {
        devotional.type == "memory_verse"
    }
}
