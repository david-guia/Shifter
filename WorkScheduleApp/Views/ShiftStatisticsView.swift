//
//  ShiftStatisticsView.swift
//  WorkScheduleApp
//
//  Vue simplifiée pour afficher les statistiques par shift avec évolution
//

import SwiftUI

/// Vue affichant les statistiques des shifts par segment (catégorie)
/// Affiche: heures par segment, pourcentage, évolution par rapport à la période précédente
struct ShiftStatisticsView: View {
    /// Shifts filtrés pour la période sélectionnée
    let shifts: [Shift]
    
    /// Tous les shifts (pour calculer l'évolution)
    let allShifts: [Shift]
    
    /// Période sélectionnée (mois/trimestre/année)
    let selectedPeriod: ContentView.TimePeriod
    
    /// Date sélectionnée
    let selectedDate: Date
    
    // MARK: - Cache pour optimisation performance
    
    /// Statistiques mémorisées (recalculées uniquement si les shifts changent)
    @State private var memoizedSegmentStats: [String: (hours: Double, percentage: Double)] = [:]
    @State private var memoizedTotalHours: Double = 0
    
    /// Hash des IDs des shifts pour détecter les changements
    @State private var lastShiftsHash: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête FIXE en haut
            HStack(spacing: 0) {
                Text("Shift")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                
                Text("Heures")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(width: 70, alignment: .trailing)
                
                Text("%")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(width: 50, alignment: .trailing)
                
                Text("Δ")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(width: 70, alignment: .trailing)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 12)
            .background(Color.systemBlack)
            
            // Contenu SCROLLABLE au milieu
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(segmentStats.keys.sorted(by: { key1, key2 in
                        guard let stats1 = segmentStats[key1], let stats2 = segmentStats[key2] else { return false }
                        return stats1.percentage > stats2.percentage
                    })), id: \.self) { segment in
                        if segment != "Général", let stats = segmentStats[segment] {
                            let evolution = calculateEvolution(for: segment)
                            
                            HStack(spacing: 0) {
                                Text(segment)
                                    .font(.chicago12)
                                    .foregroundStyle(Color.systemBlack)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 16)
                                
                                Text(formatHours(stats.hours))
                                    .font(.chicago12)
                                    .foregroundStyle(Color.systemBlack)
                                    .frame(width: 70, alignment: .trailing)
                                
                                Text(String(format: "%.0f%%", stats.percentage))
                                    .font(.chicago12)
                                    .foregroundStyle(Color.systemBlack)
                                    .frame(width: 50, alignment: .trailing)
                                
                                Text(formatEvolution(evolution))
                                    .font(.chicago12)
                                    .foregroundStyle(evolutionColor(evolution))
                                    .frame(width: 70, alignment: .trailing)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 12)
                            .background(Color.systemWhite)
                        }
                    }
                }
                .padding(.horizontal, 0)
            }
            
            // Total FIXE en bas
            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                
                Text(formatHours(totalHours))
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(width: 70, alignment: .trailing)
                
                Text("100%")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemWhite)
                    .frame(width: 50, alignment: .trailing)
                
                Text("")
                    .font(.chicago14)
                    .frame(width: 70, alignment: .trailing)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 14)
            .background(Color.systemBlack)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.systemBlack, lineWidth: 3)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onAppear {
            updateStatsIfNeeded()
        }
        .onChange(of: shifts.map(\.id)) { _, _ in
            updateStatsIfNeeded()
        }
    }
    
    // MARK: - Mémorisation (optimisation)
    
    /// Met à jour les statistiques uniquement si les shifts ont changé
    /// Évite les recalculs inutiles à chaque rendu de la vue
    private func updateStatsIfNeeded() {
        let newHash = shifts.map(\.id).hashValue
        guard newHash != lastShiftsHash else { return }
        
        lastShiftsHash = newHash
        memoizedTotalHours = calculateTotalHours()
        memoizedSegmentStats = calculateSegmentStats()
    }
    
    // MARK: - Statistiques calculées
    
    /// Total d'heures (utilise le cache mémorisé)
    private var totalHours: Double {
        memoizedTotalHours
    }
    
    /// Statistiques par segment (utilise le cache mémorisé)
    private var segmentStats: [String: (hours: Double, percentage: Double)] {
        memoizedSegmentStats
    }
    
    /// Calcule le total d'heures (hors shifts "Général")
    private func calculateTotalHours() -> Double {
        // Total uniquement des shifts spécifiques (hors "Général")
        shifts.filter { $0.segment != "Général" }.reduce(0) { $0 + $1.duration / 3600 }
    }
    
    /// Calcule les heures et pourcentages pour chaque segment
    /// Retourne: [segment: (heures, pourcentage du total)]
    private func calculateSegmentStats() -> [String: (hours: Double, percentage: Double)] {
        var stats: [String: Double] = [:]
        
        // Calculer les heures par segment (uniquement les shifts spécifiques)
        for shift in shifts where shift.segment != "Général" {
            let hours = shift.duration / 3600
            stats[shift.segment, default: 0] += hours
        }
        
        // Calculer le total des shifts spécifiques
        let total = stats.values.reduce(0, +)
        
        // Ajouter les pourcentages
        return stats.mapValues { hours in
            if total > 0 {
                let percentage = (hours / total) * 100
                return (hours: hours, percentage: percentage)
            }
            return (hours: hours, percentage: 0)
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
    
    // MARK: - Évolution
    
    private func calculateEvolution(for segment: String) -> Double? {
        let currentHours = shifts.filter { $0.segment == segment }.reduce(0.0) { $0 + $1.duration / 3600 }
        let currentTotal = totalHours
        
        guard let previousShifts = getPreviousPeriodShifts() else { return nil }
        let previousHours = previousShifts.filter { $0.segment == segment }.reduce(0.0) { $0 + $1.duration / 3600 }
        let previousTotal = previousShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        
        guard previousTotal > 0, currentTotal > 0 else { return nil }
        
        // Calculer les pourcentages
        let currentPercentage = (currentHours / currentTotal) * 100
        let previousPercentage = (previousHours / previousTotal) * 100
        
        return currentPercentage - previousPercentage
    }
    
    private func calculateTotalEvolution() -> Double? {
        let currentTotal = totalHours
        
        guard let previousShifts = getPreviousPeriodShifts() else { return nil }
        let previousTotal = previousShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        
        guard previousTotal > 0, currentTotal > 0 else { return nil }
        
        // Variation en heures absolues converties en pourcentage du total
        let variation = currentTotal - previousTotal
        let variationPercentage = (variation / previousTotal) * 100
        
        return variationPercentage
    }
    
    private func getPreviousPeriodShifts() -> [Shift]? {
        let calendar = Calendar.current
        
        var previousDate: Date?
        
        switch selectedPeriod {
        case .month:
            previousDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)
        case .quarter:
            previousDate = calendar.date(byAdding: .month, value: -3, to: selectedDate)
        case .year:
            previousDate = calendar.date(byAdding: .year, value: -1, to: selectedDate)
        }
        
        guard let prevDate = previousDate else { return nil }
        
        return allShifts.filter { shift in
            switch selectedPeriod {
            case .month:
                return calendar.isDate(shift.date, equalTo: prevDate, toGranularity: .month)
            case .quarter:
                return FiscalCalendarHelper.isInSameQuarter(shift.date, prevDate)
            case .year:
                return calendar.isDate(shift.date, equalTo: prevDate, toGranularity: .year)
            }
        }
    }
    
    // Helpers fiscaux déplacés vers FiscalCalendarHelper
    
    private func formatEvolution(_ evolution: Double?) -> String {
        guard let evolution = evolution else { return "—" }
        
        if abs(evolution) < 0.5 {
            return "="
        } else if evolution > 0 {
            return String(format: "+%.0f pts", evolution)
        } else {
            return String(format: "%.0f pts", evolution)
        }
    }
    
    private func evolutionColor(_ evolution: Double?) -> Color {
        guard let evolution = evolution else { return Color.systemGray }
        
        if evolution > 0 {
            return Color.green.opacity(0.8)
        } else if evolution < 0 {
            return Color.red.opacity(0.8)
        } else {
            return Color.systemGray
        }
    }
}

#Preview {
    let shifts = [
        Shift(date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(5400), location: "Test", segment: "Shift 1"),
        Shift(date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(5400), location: "Test", segment: "Shift 2"),
        Shift(date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(3600), location: "Test", segment: "Pause")
    ]
    
    return ShiftStatisticsView(
        shifts: shifts,
        allShifts: shifts,
        selectedPeriod: .month,
        selectedDate: Date()
    )
}
