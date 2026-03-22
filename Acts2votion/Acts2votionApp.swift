//
//  Acts2votionApp.swift
//  Acts2votion
//
//  Created by Jun Min Kim on 3/17/26.
//

import SwiftUI

@main
struct Acts2votionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 900)
        #endif
    }
}
