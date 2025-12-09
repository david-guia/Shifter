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
}

import os

// Petit wrapper AppLogger inclus dans la cible principale
struct AppLogger {
    static let shared = AppLogger()

    private let logger: Logger

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.davidguia.shifter"
        logger = Logger(subsystem: subsystem, category: "App")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

