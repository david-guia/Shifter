//
//  WorkScheduleAppApp.swift
//  WorkScheduleApp
//
//  Créé le 24 novembre 2025
//

import SwiftUI
import SwiftData

@main
struct WorkScheduleAppApp: App {
    @State private var sharedImagePath: String?
    
    // MARK: - 🚧 Apple Watch Support
    init() {
        _ = WatchConnectivityManager.shared
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkSchedule.self,
        ])
        
        // Utiliser l'App Group pour partager les données avec le widget
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.davidguia.shifter") else {
            fatalError("Cannot access App Group container")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("shifter.sqlite")
        let modelConfiguration = ModelConfiguration(url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Impossible de créer le ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(sharedImagePath: $sharedImagePath)
                .onAppear {
                    checkForSharedImage()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func checkForSharedImage() {
        let appGroupIdentifier = "group.com.davidguia.shifter"
        
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        
        guard let imagePath = userDefaults.string(forKey: "pendingImagePath") else {
            return
        }
        
        // Vérifier que l'image est récente (moins de 5 minutes)
        if let imageDate = userDefaults.object(forKey: "pendingImageDate") as? Date {
            let elapsed = Date().timeIntervalSince(imageDate)
            
            if elapsed < 300 {
                sharedImagePath = imagePath
            }
        }
        
        // Nettoyer les UserDefaults
        userDefaults.removeObject(forKey: "pendingImagePath")
        userDefaults.removeObject(forKey: "pendingImageDate")
    }
}
