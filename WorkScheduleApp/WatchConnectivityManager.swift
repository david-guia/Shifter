//
//  WatchConnectivityManager.swift
//  WorkScheduleApp
//
//  Gestionnaire de communication iPhone ↔ Apple Watch
//
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🚧 CODE DORMANT - APPLE WATCH SUPPORT (Temporairement désactivé)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// ⚠️ STATUT: Ce fichier contient du code 100% fonctionnel et testé,
//            mais temporairement non utilisé car l'app watchOS
//            ne sera pas déployée dans l'immédiat.
//
// 📋 CONTENU:
//    - WatchConnectivity Framework (communication bidirectionnelle)
//    - Calcul automatique Top 3 shifts trimestre
//    - Synchronisation temps réel iPhone → Watch
//    - Gestion erreurs et logs debug
//
// 🔄 RÉACTIVATION:
//    1. Décommenter init() dans WorkScheduleAppApp.swift
//    2. Décommenter appels syncToWatch() dans ScheduleViewModel.swift
//    3. Build et test sur appareils réels (simulateurs incompatibles)
//
// 📅 Dernière modification: Décembre 2024
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import Foundation
import WatchConnectivity
import SwiftData

/// Gestionnaire de synchronisation des données avec l'Apple Watch
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Setup
    
    /// Initialise la session WatchConnectivity
    private func setupSession() {
        guard WCSession.isSupported() else {
            #if DEBUG
            print("⚠️ WatchConnectivity non supporté sur cet appareil")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 Initialisation WatchConnectivity...")
        #endif
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #if DEBUG
        print("✅ WatchConnectivity activée")
        #endif
    }
    
    // MARK: - Sync vers Watch
    
    /// Envoie les statistiques trimestrielles à la Watch
    /// - Parameters:
    ///   - top3: Top 3 des shifts [(segment, heures, pourcentage)]
    ///   - quarterLabel: Label du trimestre (ex: "Q2 2025")
    ///   - totalHours: Total d'heures du trimestre
    func sendTop3ToWatch(top3: [(segment: String, hours: Double, percentage: Double)], quarterLabel: String, totalHours: Double) {
        #if DEBUG
        print("📤 Tentative envoi Watch: \(top3.count) items, \(quarterLabel), \(totalHours)h")
        print("   Paired: \(WCSession.default.isPaired), Installed: \(WCSession.default.isWatchAppInstalled)")
        print("   Activation: \(WCSession.default.activationState.rawValue)")
        #endif
        
        guard WCSession.default.activationState == .activated else {
            #if DEBUG
            print("⚠️ Session WatchConnectivity non activée")
            #endif
            return
        }
        
        // Convertir en dictionnaire
        let top3Data = top3.map { shift in
            [
                "segment": shift.segment,
                "hours": shift.hours,
                "percentage": shift.percentage
            ] as [String: Any]
        }
        
        let context: [String: Any] = [
            "top3": top3Data,
            "quarterLabel": quarterLabel,
            "totalHours": totalHours,
            "lastUpdate": Date().timeIntervalSince1970
        ]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            #if DEBUG
            print("✅ Top 3 envoyé à la Watch: \(quarterLabel)")
            print("   Data: \(context)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Erreur envoi Watch: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Calcule et envoie le Top 3 depuis les shifts
    /// - Parameter shifts: Tous les shifts de l'app
    func syncTop3FromShifts(_ shifts: [Shift]) {
        // Filtrer shifts du trimestre fiscal en cours
        let currentQuarterShifts = shifts.filter { shift in
            FiscalCalendarHelper.isInSameQuarter(shift.date, Date())
        }
        
        // Exclure "Général"
        let validShifts = currentQuarterShifts.filter { $0.segment != "Général" }
        
        // Calculer heures par segment
        var segmentHours: [String: Double] = [:]
        for shift in validShifts {
            let hours = shift.duration / 3600
            segmentHours[shift.segment, default: 0] += hours
        }
        
        // Total d'heures
        let totalHours = segmentHours.values.reduce(0, +)
        
        guard totalHours > 0 else {
            #if DEBUG
            print("⚠️ Aucune donnée à envoyer (trimestre vide)")
            #endif
            return
        }
        
        // Top 3 par heures
        let top3 = segmentHours
            .map { (segment: $0.key, hours: $0.value, percentage: ($0.value / totalHours) * 100) }
            .sorted { $0.hours > $1.hours }
            .prefix(3)
            .map { $0 }
        
        // Label du trimestre
        let quarterLabel = FiscalCalendarHelper.quarterLabel(for: Date())
        
        // Envoyer à la Watch
        sendTop3ToWatch(top3: top3, quarterLabel: quarterLabel, totalHours: totalHours)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
        if let error = error {
            print("❌ Erreur activation WatchConnectivity: \(error.localizedDescription)")
        } else {
            print("✅ WatchConnectivity activé: \(activationState.rawValue)")
        }
        #endif
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("⚠️ Session WatchConnectivity inactive")
        #endif
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        print("⚠️ Session WatchConnectivity désactivée")
        #endif
        // Réactiver pour la nouvelle session
        WCSession.default.activate()
    }
    
    // Réception de messages depuis la Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if message["request"] as? String == "refreshData" {
            #if DEBUG
            print("📲 Watch demande refresh des données")
            #endif
            // Notification pour déclencher sync dans ScheduleViewModel si besoin
        }
    }
}
