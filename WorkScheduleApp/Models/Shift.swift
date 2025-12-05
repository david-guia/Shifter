//
//  Shift.swift
//  WorkScheduleApp
//
//  Modèle représentant un shift de travail
//

import Foundation
import SwiftData

/// Modèle représentant un shift (poste de travail)
/// Contient toutes les informations d'un horaire: date, heures, lieu, catégorie
@Model
final class Shift: Identifiable {
    /// Index SwiftData pour optimiser les requêtes de filtrage
    /// - Par date seule
    /// - Par segment seul
    /// - Par combinaison date + segment
    #Index<Shift>([\.date], [\.segment], [\.date, \.segment])
    
    var id: UUID
    
    /// Date du shift (jour de travail)
    var date: Date
    
    /// Heure de début (stocke date+heure, seule l'heure est utilisée)
    var startTime: Date
    
    /// Heure de fin (stocke date+heure, seule l'heure est utilisée)
    var endTime: Date
    
    /// Lieu de travail (ex: "Apple Store Opéra")
    var location: String
    
    /// Catégorie/type de shift (ex: "Sales 1", "PZ On Point", "Pause repas")
    var segment: String
    
    var notes: String
    var isConfirmed: Bool
    
    /// Relation inverse avec WorkSchedule (un shift appartient à un schedule)
    @Relationship(deleteRule: .nullify, inverse: \WorkSchedule.shifts)
    var schedule: WorkSchedule?
    
    init(date: Date, startTime: Date, endTime: Date, location: String, segment: String = "Général", notes: String = "", isConfirmed: Bool = true) {
        self.id = UUID()
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.segment = segment
        self.notes = notes
        self.isConfirmed = isConfirmed
    }
    
    /// Durée du shift en secondes
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Durée formatée en heures et minutes (ex: "8h30")
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h\(minutes > 0 ? String(format: "%02d", minutes) : "")"
    }
}
