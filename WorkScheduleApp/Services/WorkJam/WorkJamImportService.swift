//
//  WorkJamImportService.swift
//  WorkScheduleApp
//
//  Convertit les événements WorkJam en objets Shift SwiftData
//  et les insère dans le schedule principal
//

import Foundation
import SwiftData

class WorkJamImportService {

    // MARK: - Conversion WJEvent → Shift

    /// Convertit une liste d'événements WorkJam en objets Shift compatibles avec Shifter
    static func convertEvents(_ events: [WJEvent]) -> [Shift] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return events.compactMap { event in
            guard let startDate = iso.date(from: event.startDateTime),
                  let endDate = iso.date(from: event.endDateTime) else {
                // Tentative sans millisecondes
                let isoFallback = ISO8601DateFormatter()
                isoFallback.formatOptions = [.withInternetDateTime]
                guard let startDate = isoFallback.date(from: event.startDateTime),
                      let endDate = isoFallback.date(from: event.endDateTime) else {
                    return nil
                }
                return buildShift(event: event, startDate: startDate, endDate: endDate)
            }
            return buildShift(event: event, startDate: startDate, endDate: endDate)
        }
    }

    private static func buildShift(event: WJEvent, startDate: Date, endDate: Date) -> Shift {
        let locationName = event.location?.name ?? "WorkJam"
        let segmentName: String
        if event.type == "AVAILABILITY_TIME_OFF" {
            segmentName = event.title?.isEmpty == false ? event.title! : "Congé"
        } else {
            segmentName = event.title?.isEmpty == false ? event.title! : "Shift"
        }

        return Shift(
            date: Calendar.current.startOfDay(for: startDate),
            startTime: startDate,
            endTime: endDate,
            location: locationName,
            segment: segmentName,
            notes: event.note ?? "",
            isConfirmed: true
        )
    }

    // MARK: - Insertion dans SwiftData

    /// Insère les shifts importés dans le schedule principal (crée le schedule si absent).
    /// Retourne le nombre de nouveaux shifts insérés (les doublons sont ignorés).
    @MainActor
    static func insertShifts(_ shifts: [Shift], into context: ModelContext) -> Int {
        // Récupérer ou créer le schedule principal
        let descriptor = FetchDescriptor<WorkSchedule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let schedules = (try? context.fetch(descriptor)) ?? []
        let schedule: WorkSchedule
        if let existing = schedules.first {
            schedule = existing
        } else {
            schedule = WorkSchedule()
            context.insert(schedule)
        }

        // Construire un ensemble de clés d'unicité (date + heure début + lieu)
        let existingKeys = Set(schedule.shifts.map { dedupeKey(for: $0) })

        var insertedCount = 0
        for shift in shifts {
            let key = dedupeKey(for: shift)
            guard !existingKeys.contains(key) else { continue }
            shift.schedule = schedule
            context.insert(shift)
            insertedCount += 1
        }

        try? context.save()
        return insertedCount
    }

    /// Clé de déduplication basée sur la date du jour + heure de début arrondie à la minute
    private static func dedupeKey(for shift: Shift) -> String {
        let cal = Calendar.current
        let day = cal.startOfDay(for: shift.date)
        let startMinutes = cal.component(.hour, from: shift.startTime) * 60
                         + cal.component(.minute, from: shift.startTime)
        return "\(day.timeIntervalSince1970)-\(startMinutes)-\(shift.location)"
    }
}
