//
//  DateFormatterCache.swift
//  WorkScheduleApp
//
//  Cache de DateFormatters pour éviter création répétée (optimisation performance)
//

import Foundation

enum DateFormatterCache {
    
    /// Formatter pour mois complet avec année (ex: "Novembre 2024")
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    /// Formatter pour année seule (ex: "2024")
    static let yearOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    /// Formatter pour heures (ex: "14:30")
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Formatter pour entête de jour dans ManageDataView (ex: "Lundi 3 Juin")
    static let dayHeader: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    /// Formatter pour le mois court utilisé dans weekLabel (ex: "mai")
    static let weekMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMM"
        return f
    }()

    /// Formatter pour la vue journalière (ex: "Lundi 3 juin 2026")
    static let dayFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f
    }()
}

extension Date {
    /// Format mois + année (Novembre 2024)
    var monthYear: String {
        DateFormatterCache.monthYear.string(from: self).capitalized
    }
    
    /// Format année seule (2024)
    var yearOnly: String {
        DateFormatterCache.yearOnly.string(from: self)
    }
    
    /// Format heure (14:30)
    var time: String {
        DateFormatterCache.time.string(from: self)
    }

    /// Format journalier (ex: "Lundi 3 juin 2026")
    var dayLabel: String {
        let s = DateFormatterCache.dayFull.string(from: self)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// Format semaine — plage de dates (ex: "5–11 mai 2025")
    var weekLabel: String {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: self) else { return "" }
        let start = interval.start
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        let startDay = calendar.component(.day, from: start)
        let endDay   = calendar.component(.day, from: end)
        let startMonth = calendar.component(.month, from: start)
        let endMonth   = calendar.component(.month, from: end)
        let startYear  = calendar.component(.year,  from: start)
        let endYear    = calendar.component(.year,  from: end)

        let startMonthStr = DateFormatterCache.weekMonth.string(from: start)
        let endMonthStr   = DateFormatterCache.weekMonth.string(from: end)

        if startMonth == endMonth, startYear == endYear {
            return "\(startDay)–\(endDay) \(startMonthStr) \(startYear)"
        } else if startYear == endYear {
            return "\(startDay) \(startMonthStr) – \(endDay) \(endMonthStr) \(endYear)"
        } else {
            return "\(startDay) \(startMonthStr) \(startYear) – \(endDay) \(endMonthStr) \(endYear)"
        }
    }
}

