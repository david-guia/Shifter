//
//  CalendarSyncService.swift
//  WorkScheduleApp
//

import Foundation
import EventKit

@Observable
@MainActor
class CalendarSyncService {

    // MARK: - Singleton store (must stay alive)
    private let store = EKEventStore()

    // MARK: - UserDefaults keys
    private static let selectedCalendarIDKey = "shifter.calendarSyncID"
    private static let eventIDsKey           = "shifter.calendarEventIDs"
    private static let lastSyncDateKey       = "shifter.calendarLastSync"
    private static let syncFromTodayKey      = "shifter.calendarSyncFromToday"

    // MARK: - Observable state
    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var isSyncing  = false
    var syncError: String?
    var lastSyncCount = 0

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date
    }

    // MARK: - Selected calendar

    var selectedCalendarID: String? {
        get { UserDefaults.standard.string(forKey: Self.selectedCalendarIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.selectedCalendarIDKey) }
    }

    var selectedCalendar: EKCalendar? {
        guard let id = selectedCalendarID else { return nil }
        return store.calendar(withIdentifier: id)
    }

    var isConfigured: Bool { selectedCalendar != nil }

    // MARK: - Sync preferences

    var syncFromToday: Bool {
        get { UserDefaults.standard.bool(forKey: Self.syncFromTodayKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.syncFromTodayKey) }
    }

    // MARK: - Writable calendars list

    var writableCalendars: [EKCalendar] {
        store.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    // MARK: - Event IDs [shiftUUID: eventIdentifier]

    private var eventIDs: [String: String] {
        get { (UserDefaults.standard.dictionary(forKey: Self.eventIDsKey) as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.eventIDsKey) }
    }

    // MARK: - Authorization

    func checkStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        if #available(iOS 17, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Sync

    func syncShifts(_ shifts: [Shift]) async {
        guard let calendar = selectedCalendar, isAuthorized, !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            // Always wipe tracked events then recreate — prevents any accumulation
            for (_, eventID) in eventIDs {
                if let event = store.event(withIdentifier: eventID) {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
            }
            try store.commit()
            eventIDs = [:]

            // Filter by date if requested
            let today = Calendar.current.startOfDay(for: Date())
            let filtered = syncFromToday ? shifts.filter { $0.startTime >= today } : shifts

            var ids: [String: String] = [:]
            var count = 0

            for shift in filtered {
                guard shift.segment != "Général" else { continue }
                let key = shift.id.uuidString

                let event = EKEvent(eventStore: store)
                configure(event, from: shift, calendar: calendar)
                try store.save(event, span: .thisEvent, commit: false)
                ids[key] = event.eventIdentifier
                count += 1
            }

            try store.commit()
            eventIDs = ids
            isSyncing     = false
            lastSyncCount = count
            UserDefaults.standard.set(Date(), forKey: Self.lastSyncDateKey)
        } catch {
            isSyncing = false
            syncError = error.localizedDescription
        }
    }

    // MARK: - Remove synced events

    func removeSyncedEvents() async {
        guard isAuthorized else { return }
        do {
            for (_, eventID) in eventIDs {
                if let event = store.event(withIdentifier: eventID) {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
            }
            try store.commit()
            eventIDs = [:]
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Reset

    func resetSync() async {
        await removeSyncedEvents()
        selectedCalendarID = nil
        lastSyncCount = 0
        syncError     = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncDateKey)
    }

    // MARK: - Private

    private func configure(_ event: EKEvent, from shift: Shift, calendar: EKCalendar) {
        event.title     = shift.segment
        event.startDate = shift.startTime
        event.endDate   = shift.endTime
        event.calendar  = calendar
        event.notes     = shift.location.isEmpty ? nil : shift.location
    }
}
