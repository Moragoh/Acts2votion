//
//  DevotionalViewModel.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

enum ViewState {
    case loading
    case loaded([ParsedDevotional])
    case empty
}

@Observable @MainActor
final class DevotionalViewModel {
    var viewState: ViewState = .loading
    var selectedDateID: String = ""
    var todayDateID: String = ""
    var isMenuOpen: Bool = false

    var isOnToday: Bool { selectedDateID == todayDateID }
    var todayIsAhead: Bool { selectedDateID < todayDateID }

    var selectedDevotional: ParsedDevotional? {
        guard case .loaded(let devotionals) = viewState else { return nil }
        return devotionals.first(where: { $0.date == selectedDateID })
    }

    var canGoToPreviousDevotional: Bool {
        guard case .loaded(let devotionals) = viewState else { return false }
        guard let currentIndex = devotionals.firstIndex(where: { $0.date == selectedDateID }) else { return false }
        return currentIndex > 0
    }

    var canGoToNextDevotional: Bool {
        guard case .loaded(let devotionals) = viewState else { return false }
        guard let currentIndex = devotionals.firstIndex(where: { $0.date == selectedDateID }) else { return false }
        return currentIndex < devotionals.count - 1
    }

    func goToToday() { selectedDateID = todayDateID }

    func goToPreviousDevotional() {
        guard case .loaded(let devotionals) = viewState else { return }
        guard let currentIndex = devotionals.firstIndex(where: { $0.date == selectedDateID }),
              currentIndex > 0 else { return }
        selectedDateID = devotionals[currentIndex - 1].date
    }

    func goToNextDevotional() {
        guard case .loaded(let devotionals) = viewState else { return }
        guard let currentIndex = devotionals.firstIndex(where: { $0.date == selectedDateID }),
              currentIndex < devotionals.count - 1 else { return }
        selectedDateID = devotionals[currentIndex + 1].date
    }

    func loadDevotionals() async {
        viewState = .loading
        await DevotionalStore.shared.fetchIfNeeded()

        let allDevotionals = DevotionalStore.shared.allCachedDevotionals()
        guard !allDevotionals.isEmpty else {
            viewState = .empty
            return
        }

        todayDateID = DevotionalStore.shared.todaysDevotional()?.date ?? allDevotionals.last!.date
        selectedDateID = todayDateID
        viewState = .loaded(allDevotionals)
    }
}
