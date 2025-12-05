//
//  WorkSchedule.swift
//  WorkScheduleApp
//
//  Modèle représentant un ensemble d'horaires de travail
//

import Foundation
import SwiftData

@Model
final class WorkSchedule: Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var imageData: Data?
    var rawOCRText: String?
    
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
    
    var totalHours: Double {
        shifts.reduce(0) { $0 + $1.duration / 3600 }
    }
    
    var totalHoursFormatted: String {
        String(format: "%.1fh", totalHours)
    }
    
    var locations: [String] {
        Array(Set(shifts.map { $0.location })).sorted()
    }
    
    func shiftsForLocation(_ location: String) -> [Shift] {
        shifts.filter { $0.location == location }.sorted { $0.date < $1.date }
    }
    
    func shiftsForWeek(startingFrom date: Date) -> [Shift] {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        return shifts.filter { shift in
            shift.date >= weekStart && shift.date < weekEnd
        }.sorted { $0.date < $1.date }
    }
}
