//
//  WidgetDataProvider.swift
//  ShifterWidget
//
//  Helper pour récupérer les données depuis SwiftData
//

import Foundation
import SwiftData

class WidgetDataProvider {
    static let shared = WidgetDataProvider()
    
    private let appGroupIdentifier = "group.com.davidguia.shifter"
    
    private var modelContainer: ModelContainer?
    
    init() {
        setupModelContainer()
    }
    
    private func setupModelContainer() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            return
        }
        
        let storeURL = containerURL.appendingPathComponent("shifter.sqlite")
        
        do {
            let schema = Schema([WorkSchedule.self, Shift.self])
            let modelConfiguration = ModelConfiguration(url: storeURL)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Silencieux en production
        }
    }
    
    /// Récupère les 3 SEGMENTS avec le plus d'heures cumulées du QUARTER en cours avec % et delta
    /// (Exactement comme la vue Trimestre de l'app)
    func getTop3ShiftsWithStats() -> [(segment: String, totalHours: String, percentage: Int, delta: String)] {
        guard let container = modelContainer else {
            return []
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Shift>()
        
        do {
            let allShifts = try context.fetch(descriptor)
            
            let currentDate = Date()
            
            // Shifts du quarter actuel
            let currentQuarterShifts = allShifts.filter { shift in
                FiscalCalendarHelper.isInSameQuarter(shift.date, currentDate)
            }
            
            // Grouper par segment et calculer total heures par segment (EXCLURE "Général")
            let segmentGroups = Dictionary(grouping: currentQuarterShifts.filter { $0.segment != "Général" }) { $0.segment }
            let segmentHours = segmentGroups.mapValues { shifts in
                shifts.reduce(0.0) { $0 + $1.duration / 3600 }
            }
            
            let totalHours = segmentHours.values.reduce(0, +)
            
            // Quarter précédent pour delta
            let currentQuarter = FiscalCalendarHelper.fiscalQuarter(for: currentDate)
            let currentYear = FiscalCalendarHelper.fiscalYear(for: currentDate)
            
            let previousQuarterShifts = allShifts.filter { shift in
                let shiftQuarter = FiscalCalendarHelper.fiscalQuarter(for: shift.date)
                let shiftYear = FiscalCalendarHelper.fiscalYear(for: shift.date)
                
                if currentQuarter == 1 {
                    return shiftQuarter == 4 && shiftYear == currentYear - 1
                } else {
                    return shiftQuarter == currentQuarter - 1 && shiftYear == currentYear
                }
            }
            
            let previousSegmentGroups = Dictionary(grouping: previousQuarterShifts) { $0.segment }
            let previousSegmentHours = previousSegmentGroups.mapValues { shifts in
                shifts.reduce(0.0) { $0 + $1.duration / 3600 }
            }
            
            // Top 3 segments par heures totales
            let top3Segments = segmentHours.sorted { $0.value > $1.value }.prefix(3)
            
            return top3Segments.map { segment, hours in
                let percentage = totalHours > 0 ? Int((hours / totalHours) * 100) : 0
                
                // Delta avec quarter précédent
                let previousHours = previousSegmentHours[segment] ?? 0
                let delta: String
                if previousHours == 0 {
                    delta = "–"
                } else {
                    let diff = hours - previousHours
                    if abs(diff) < 0.5 {
                        delta = "–"
                    } else if diff > 0 {
                        delta = "+\(Int(diff))h"
                    } else {
                        delta = "-\(Int(abs(diff)))h"
                    }
                }
                
                // Formater les heures (ex: "7h30" ou "2h")
                let hoursInt = Int(hours)
                let minutes = Int((hours - Double(hoursInt)) * 60)
                let hoursFormatted = minutes > 0 ? "\(hoursInt)h\(String(format: "%02d", minutes))" : "\(hoursInt)h"
                
                return (segment: segment, totalHours: hoursFormatted, percentage: percentage, delta: delta)
            }
        } catch {
            return []
        }
    }
    
    /// Calcule les statistiques du trimestre fiscal en cours
    func getQuarterStats() -> QuarterStats {
        guard let container = modelContainer else {
            return QuarterStats(totalHours: 0, progress: 0, currentQuarter: 1)
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Shift>()
        
        do {
            let allShifts = try context.fetch(descriptor)
            let currentDate = Date()
            
            // Shifts du quarter actuel
            let currentQuarterShifts = allShifts.filter { shift in
                FiscalCalendarHelper.isInSameQuarter(shift.date, currentDate)
            }
            
            let totalHours = currentQuarterShifts.reduce(0.0) { $0 + $1.duration / 3600 }
            
            // Calculer progression du quarter (0-100%)
            let calendar = Calendar.current
            let currentQuarter = FiscalCalendarHelper.fiscalQuarter(for: currentDate)
            let quarterStartMonth = ((currentQuarter - 1) * 3) + 10 // Oct = 10
            let yearComponent = FiscalCalendarHelper.fiscalYear(for: currentDate)
            
            var startComponents = DateComponents()
            startComponents.year = quarterStartMonth >= 10 ? yearComponent - 1 : yearComponent
            startComponents.month = quarterStartMonth > 12 ? quarterStartMonth - 12 : quarterStartMonth
            startComponents.day = 1
            
            var endComponents = DateComponents()
            let endMonth = quarterStartMonth + 3
            endComponents.year = endMonth > 12 ? yearComponent : yearComponent - 1
            endComponents.month = endMonth > 12 ? endMonth - 12 : endMonth
            endComponents.day = 1
            
            guard let quarterStart = calendar.date(from: startComponents),
                  let quarterEnd = calendar.date(from: endComponents) else {
                return QuarterStats(totalHours: totalHours, progress: 0, currentQuarter: currentQuarter)
            }
            
            let totalDays = calendar.dateComponents([.day], from: quarterStart, to: quarterEnd).day ?? 90
            let elapsedDays = calendar.dateComponents([.day], from: quarterStart, to: currentDate).day ?? 0
            
            let progress = min(100, max(0, Double(elapsedDays) / Double(totalDays) * 100))
            
            return QuarterStats(
                totalHours: totalHours,
                progress: progress,
                currentQuarter: currentQuarter
            )
        } catch {
            return QuarterStats(totalHours: 0, progress: 0, currentQuarter: 1)
        }
    }
}

struct QuarterStats {
    let totalHours: Double
    let progress: Double // 0-100
    let currentQuarter: Int // 1-4
}
