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

        let monthFmt = DateFormatter()
        monthFmt.locale = Locale(identifier: "fr_FR")
        monthFmt.dateFormat = "MMM"

        let startMonthStr = monthFmt.string(from: start)
        let endMonthStr   = monthFmt.string(from: end)

        if startMonth == endMonth, startYear == endYear {
            return "\(startDay)–\(endDay) \(startMonthStr) \(startYear)"
        } else if startYear == endYear {
            return "\(startDay) \(startMonthStr) – \(endDay) \(endMonthStr) \(endYear)"
        } else {
            return "\(startDay) \(startMonthStr) \(startYear) – \(endDay) \(endMonthStr) \(endYear)"
        }
    }
}

