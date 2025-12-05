//
//  WorkSchedule.swift
//  WorkScheduleApp
//
//  Modèle représentant un ensemble d'horaires de travail
//

import Foundation
import SwiftData

/// Modèle représentant un ensemble d'horaires de travail
/// Contient une collection de shifts et des méthodes pour les statistiques
@Model
final class WorkSchedule: Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    
    /// Données de l'image importée (optionnel)
    var imageData: Data?
    
    /// Texte brut extrait par OCR (optionnel, pour debug)
    var rawOCRText: String?
    
    /// Collection de tous les shifts de ce schedule
    /// Relation cascade: si le schedule est supprimé, tous ses shifts le sont aussi
    @Relationship(deleteRule: .cascade)
    var shifts: [Shift]
    
    init(title: String, imageData: Data? = nil, rawOCRText: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.imageData = imageData
        self.rawOCRText = rawOCRText
        self.shifts = []
    }
    
    /// Total d'heures de tous les shifts en heures décimales
    var totalHours: Double {
        shifts.reduce(0) { $0 + $1.duration / 3600 }
    }
    
    /// Total d'heures formaté (ex: "42.5h")
    var totalHoursFormatted: String {
        String(format: "%.1fh", totalHours)
    }
    
    /// Liste unique des lieux de travail (triée alphabétiquement)
    var locations: [String] {
        Array(Set(shifts.map { $0.location })).sorted()
    }
    
    /// Retourne les shifts pour un lieu spécifique, triés par date
    func shiftsForLocation(_ location: String) -> [Shift] {
        shifts.filter { $0.location == location }.sorted { $0.date < $1.date }
    }
    
    /// Retourne les shifts d'une semaine spécifique
    /// - Parameter date: N'importe quelle date dans la semaine souhaitée
    /// - Returns: Shifts de la semaine, triés par date
    func shiftsForWeek(startingFrom date: Date) -> [Shift] {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        return shifts.filter { shift in
            shift.date >= weekStart && shift.date < weekEnd
        }.sorted { $0.date < $1.date }
    }
}
