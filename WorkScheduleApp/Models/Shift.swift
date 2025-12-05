//
//  Shift.swift
//  WorkScheduleApp
//
//  Modèle représentant un shift de travail
//

import Foundation
import SwiftData

@Model
final class Shift: Identifiable {
    var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var location: String
    var segment: String  // Catégorie de travail (Sales, PZ On Point, etc.)
    var notes: String
    var isConfirmed: Bool
    
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
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return "\(hours)h\(minutes > 0 ? String(format: "%02d", minutes) : "")"
    }
}
