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
        print("🔍 Checking for shared image...")
        
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Cannot access App Group UserDefaults")
            return
        }
        
        guard let imagePath = userDefaults.string(forKey: "pendingImagePath") else {
            print("ℹ️ No pending image")
            return
        }
        
        print("📷 Found image at: \(imagePath)")
        
        // Vérifier que l'image est récente (moins de 5 minutes)
        if let imageDate = userDefaults.object(forKey: "pendingImageDate") as? Date {
            let elapsed = Date().timeIntervalSince(imageDate)
            print("⏱️ Image age: \(Int(elapsed)) seconds")
            
            if elapsed < 300 {
                print("✅ Image is recent, processing...")
                sharedImagePath = imagePath
            } else {
                print("⚠️ Image too old, ignoring")
            }
        }
        
        // Nettoyer les UserDefaults
        userDefaults.removeObject(forKey: "pendingImagePath")
        userDefaults.removeObject(forKey: "pendingImageDate")
        print("🧹 Cleaned up UserDefaults")
    }
}
