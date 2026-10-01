//
//  WatchTamerApp.swift
//  WatchTamer Watch App
//
//  Created by Senalbert Rodriguez on 4/23/26.
//

import SwiftUI

@main
struct WatchTamerApp: App {
    @StateObject private var state = DinoState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // Swipe between the pet and the settings page
            TabView {
                ContentView(state: state)
                SettingsView(state: state)
            }
            .tabViewStyle(.page)
            .onChange(of: scenePhase) { _, phase in
                state.handleScenePhase(phase)
            }
        }
    }
}
