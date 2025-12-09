//
//  WatchDataManager.swift
//  ShifterWatch Watch App
//
//  Gestionnaire de réception et stockage des données sur Apple Watch
//

import Foundation
import WatchConnectivity
import Combine

/// Gestionnaire de données pour l'Apple Watch
class WatchDataManager: NSObject, ObservableObject {
    static let shared = WatchDataManager()
    
    // MARK: - Published Properties
    
    @Published var top3Shifts: [(segment: String, hours: Double, percentage: Double)] = []
    @Published var quarterLabel: String = "Q1 2025"
    @Published var totalHours: Double = 0
    @Published var lastUpdate: Date?
    @Published var isConnected: Bool = false
    
    private override init() {
        super.init()
        setupSession()
        loadCachedData()
        
        // 🧪 DONNÉES DE TEST pour simulateur (retirer en production)
        #if targetEnvironment(simulator)
        if top3Shifts.isEmpty {
            print("🧪 Chargement données de test simulateur...")
            top3Shifts = [
                (segment: "Shift 1", hours: 156.5, percentage: 42.3),
                (segment: "Shift 2", hours: 120.0, percentage: 32.4),
                (segment: "Shift 3", hours: 93.5, percentage: 25.3)
            ]
            quarterLabel = "Q1 2025"
            totalHours = 370.0
            lastUpdate = Date()
        }
        #endif
    }
    
    // MARK: - Setup
    
    /// Initialise la session WatchConnectivity
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity non supporté")
            return
        }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    // MARK: - Cache Local
    
    /// Sauvegarde les données dans UserDefaults
    private func cacheData() {
        let defaults = UserDefaults.standard
        
        // Convertir top3 en dictionnaire
        let top3Array = top3Shifts.map { shift in
            [
                "segment": shift.segment,
                "hours": shift.hours,
                "percentage": shift.percentage
            ] as [String: Any]
        }
        
        defaults.set(top3Array, forKey: "cachedTop3")
        defaults.set(quarterLabel, forKey: "cachedQuarterLabel")
        defaults.set(totalHours, forKey: "cachedTotalHours")
        
        if let lastUpdate = lastUpdate {
            defaults.set(lastUpdate.timeIntervalSince1970, forKey: "cachedLastUpdate")
        }
        
        print("💾 Données cachées localement")
    }
    
    /// Charge les données depuis UserDefaults
    private func loadCachedData() {
        let defaults = UserDefaults.standard
        
        if let cachedTop3 = defaults.array(forKey: "cachedTop3") as? [[String: Any]] {
            top3Shifts = cachedTop3.compactMap { dict in
                guard let segment = dict["segment"] as? String,
                      let hours = dict["hours"] as? Double,
                      let percentage = dict["percentage"] as? Double else {
                    return nil
                }
                return (segment: segment, hours: hours, percentage: percentage)
            }
        }
        
        quarterLabel = defaults.string(forKey: "cachedQuarterLabel") ?? "Q1 2025"
        totalHours = defaults.double(forKey: "cachedTotalHours")
        
        if let timestamp = defaults.object(forKey: "cachedLastUpdate") as? TimeInterval {
            lastUpdate = Date(timeIntervalSince1970: timestamp)
        }
        
        if !top3Shifts.isEmpty {
            print("📂 \(top3Shifts.count) shifts chargés depuis cache")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchDataManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
        
        if let error = error {
            print("❌ Erreur activation: \(error.localizedDescription)")
        } else {
            print("✅ WatchConnectivity activé sur Watch")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ Session WatchConnectivity inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ Session WatchConnectivity désactivée")
        session.activate()
    }
    #endif
    
    /// Réception du contexte applicatif depuis iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📲 Réception données iPhone...")
        print("   Context: \(applicationContext)")
        
        DispatchQueue.main.async {
            // Parser top3
            if let top3Data = applicationContext["top3"] as? [[String: Any]] {
                self.top3Shifts = top3Data.compactMap { dict in
                    guard let segment = dict["segment"] as? String,
                          let hours = dict["hours"] as? Double,
                          let percentage = dict["percentage"] as? Double else {
                        return nil
                    }
                    return (segment: segment, hours: hours, percentage: percentage)
                }
            }
            
            // Parser métadonnées
            if let label = applicationContext["quarterLabel"] as? String {
                self.quarterLabel = label
            }
            
            if let total = applicationContext["totalHours"] as? Double {
                self.totalHours = total
            }
            
            if let timestamp = applicationContext["lastUpdate"] as? TimeInterval {
                self.lastUpdate = Date(timeIntervalSince1970: timestamp)
            }
            
            // Cacher les données
            self.cacheData()
            
            print("✅ Top 3 reçu: \(self.top3Shifts.count) shifts")
        }
    }
}
