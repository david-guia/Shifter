//
//  DateFormatterCache.swift
//  WorkScheduleApp
//
//  Cache de DateFormatters pour éviter création répétée (optimisation performance)
//

import Foundation

enum DateFormatterCache {
    
    /// Formatter pour dates complètes françaises (ex: "25 novembre 2024")
    static let mediumFrench: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
    /// Formatter pour dates courtes (ex: "25 Nov 2024")
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()
    
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
    /// Format date en français moyen (25 novembre 2024)
    var mediumFrench: String {
        DateFormatterCache.mediumFrench.string(from: self)
    }
    
    /// Format date courte (25 Nov 2024)
    var shortDate: String {
        DateFormatterCache.shortDate.string(from: self)
    }
    
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
}
