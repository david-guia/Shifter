//
//  ShifterWatchApp.swift
//  ShifterWatch Watch App
//
//  Point d'entrée de l'app Apple Watch
//

import SwiftUI

@main
struct ShifterWatch_Watch_AppApp: App {
    @StateObject private var dataManager = WatchDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            Top3View()
                .environmentObject(dataManager)
        }
    }
}
