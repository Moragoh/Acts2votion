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

    func loadDevotionals() async {
        viewState = .loading
        await DevotionalStore.shared.fetchIfNeeded()

        let allDevotionals = DevotionalStore.shared.allCachedDevotionals()
        guard !allDevotionals.isEmpty else {
            viewState = .empty
            return
        }

        let todaysDateID = DevotionalStore.shared.todaysDevotional()?.date ?? allDevotionals.last!.date
        selectedDateID = todaysDateID
        viewState = .loaded(allDevotionals)
    }
}
