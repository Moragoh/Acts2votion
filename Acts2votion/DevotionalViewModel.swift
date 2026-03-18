//
//  DevotionalViewModel.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

enum ViewState {
    case loading
    case loaded(ParsedDevotional)
    case empty
}

@Observable @MainActor
final class DevotionalViewModel {
    var viewState: ViewState = .loading

    func loadTodaysDevotional() async {
        viewState = .loading
        await DevotionalStore.shared.fetchIfNeeded()
        if let devotional = DevotionalStore.shared.todaysDevotional() {
            viewState = .loaded(devotional)
        } else {
            viewState = .empty
        }
    }
}
