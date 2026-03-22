//
//  SideMenuOverlay.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

#if os(iOS)
struct SideMenuOverlay: View {
    @Binding var isMenuOpen: Bool
    let devotionals: [ParsedDevotional]
    @Binding var selectedDateID: String

    private var menuWidth: CGFloat { 90 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tapToDismissArea
            slidingMenuPanel
        }
        .allowsHitTesting(isMenuOpen)
    }

    private var tapToDismissArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                isMenuOpen = false
            }
    }

    private var slidingMenuPanel: some View {
        SideMenuView(
            devotionals: devotionals,
            selectedDateID: $selectedDateID,
            onDateSelected: navigateToDate
        )
        .frame(width: menuWidth)
        .background(Color(.systemBackground).opacity(0.98))
        .offset(x: isMenuOpen ? 0 : -menuWidth)
        .animation(.easeInOut(duration: 0.25), value: isMenuOpen)
    }

    private func navigateToDate(_ dateID: String) {
        selectedDateID = dateID
        isMenuOpen = false
    }
}
#endif
