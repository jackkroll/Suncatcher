//
//  SuncatcherApp.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import SwiftData

@main
struct SuncatcherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SavedLocation.self)
    }
}
