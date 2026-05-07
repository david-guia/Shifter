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

    /// Convertit une liste d'événements WorkJam en objets Shift.
    /// Pour les SHIFT avec segments de zones distincts, crée un Shift **par segment** (hors pauses).
    /// `detailMap` : dictionnaire [eventID: WJShiftDetail] issu des appels de détail.
    static func convertEvents(_ events: [WJEvent], detailMap: [String: WJShiftDetail] = [:]) -> [Shift] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFallback = ISO8601DateFormatter()
        isoFallback.formatOptions = [.withInternetDateTime]

        var result: [Shift] = []

        for event in events {
            // SHIFT avec détail contenant des segments de zone
            if event.type == "SHIFT", let detail = detailMap[event.id] {
                let workSegments = detail.segments.filter { !$0.isBreak }
                if !workSegments.isEmpty {
                    for seg in workSegments {
                        guard let start = parseDate(seg.startDateTime, primary: iso, fallback: isoFallback),
                              let end   = parseDate(seg.endDateTime,   primary: iso, fallback: isoFallback) else { continue }
                        result.append(Shift(
                            date: Calendar.current.startOfDay(for: start),
                            startTime: start,
                            endTime: end,
                            location: event.location?.name ?? "WorkJam",
                            segment: seg.position?.name ?? detail.primaryZone ?? event.title ?? "Shift",
                            notes: event.note ?? "",
                            isConfirmed: true
                        ))
                    }
                    continue
                }
                // Détail présent mais aucun segment → zone principale
                if let s = buildShift(event: event, primary: iso, fallback: isoFallback,
                                      zoneOverride: detail.primaryZone) { result.append(s) }
                continue
            }

            // Congé ou absence de détail
            if let s = buildShift(event: event, primary: iso, fallback: isoFallback) { result.append(s) }
        }
        return result
    }

    // MARK: - Helpers privés

    private static func parseDate(_ string: String,
                                  primary: ISO8601DateFormatter,
                                  fallback: ISO8601DateFormatter) -> Date? {
        primary.date(from: string) ?? fallback.date(from: string)
    }

    private static func buildShift(event: WJEvent,
                                   primary: ISO8601DateFormatter,
                                   fallback: ISO8601DateFormatter,
                                   zoneOverride: String? = nil) -> Shift? {
        guard let startDate = parseDate(event.startDateTime, primary: primary, fallback: fallback),
              let endDate   = parseDate(event.endDateTime,   primary: primary, fallback: fallback) else { return nil }

        let locationName = event.location?.name ?? "WorkJam"
        let segmentName: String
        if let zone = zoneOverride, !zone.isEmpty {
            segmentName = zone
        } else if event.type == "AVAILABILITY_TIME_OFF" {
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

    /// Remplace les shifts des jours couverts par la synchronisation WorkJam.
    /// Pour chaque jour présent dans `shifts`, tous les shifts existants pour ce jour
    /// sont supprimés avant d'insérer les nouveaux — évite l'accumulation de zones
    /// obsolètes quand les zoning changent d'une synchro à l'autre.
    /// Retourne le nombre de shifts insérés.
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
            schedule = WorkSchedule(title: "WorkJam")
            context.insert(schedule)
        }

        // Collecter tous les jours couverts par la nouvelle synchro
        let cal = Calendar.current
        let incomingDays = Set(shifts.map { cal.startOfDay(for: $0.date) })

        // Supprimer tous les shifts existants pour ces jours
        let toDelete = schedule.shifts.filter { incomingDays.contains(cal.startOfDay(for: $0.date)) }
        for shift in toDelete {
            context.delete(shift)
        }

        // Insérer les nouveaux shifts
        for shift in shifts {
            shift.schedule = schedule
            context.insert(shift)
        }

        try? context.save()
        return shifts.count
    }
}
