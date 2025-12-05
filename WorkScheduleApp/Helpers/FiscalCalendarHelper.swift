//
//  FiscalCalendarHelper.swift
//  WorkScheduleApp
//
//  Helper centralisé pour la logique de trimestres fiscaux
//  Q1: Oct-Dec (dernier trimestre année civile), Q2: Jan-Mar, Q3: Apr-Jun, Q4: Jul-Sep
//

import Foundation

enum FiscalCalendarHelper {
    
    /// Détermine le trimestre fiscal
    /// Q1: Oct-Dec, Q2: Jan-Mar, Q3: Apr-Jun, Q4: Jul-Sep
    static func fiscalQuarter(for date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 1...3: return 2
        case 4...6: return 3
        case 7...9: return 4
        default: return 1  // 10-12
        }
    }
    
    /// Retourne l'année fiscale (identique à l'année civile)
    static func fiscalYear(for date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }
    
    /// Vérifie si deux dates sont dans le même trimestre fiscal
    static func isInSameQuarter(_ date1: Date, _ date2: Date) -> Bool {
        fiscalQuarter(for: date1) == fiscalQuarter(for: date2) &&
        fiscalYear(for: date1) == fiscalYear(for: date2)
    }
    
    /// Retourne le label formaté pour un trimestre fiscal (ex: "Q1 2025")
    static func quarterLabel(for date: Date) -> String {
        "Q\(fiscalQuarter(for: date)) \(fiscalYear(for: date))"
    }
}
