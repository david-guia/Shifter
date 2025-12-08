//
//  Top3View.swift
//  ShifterWatch Watch App
//
//  Vue principale affichant le Top 3 des shifts
//

import SwiftUI

struct Top3View: View {
    @EnvironmentObject var dataManager: WatchDataManager
    
    /// État d'affichage : true = heures, false = pourcentages
    @State private var showHours: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // En-tête trimestre
                Text(dataManager.quarterLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                
                // Total d'heures
                Text(formatTotalHours(dataManager.totalHours))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 4)
                
                // Top 3 shifts
                if dataManager.top3Shifts.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(dataManager.top3Shifts.enumerated()), id: \.offset) { index, shift in
                        Top3CardView(
                            rank: index + 1,
                            segment: shift.segment,
                            hours: shift.hours,
                            percentage: shift.percentage,
                            showHours: showHours
                        )
                    }
                }
                
                // Indicateur mise à jour
                if let lastUpdate = dataManager.lastUpdate {
                    Text("Mis à jour \(lastUpdate, style: .relative)")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Top 3")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            // Toggle heures ↔ pourcentages
            withAnimation(.spring(response: 0.3)) {
                showHours.toggle()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.gray)
            
            Text("Aucune donnée")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            
            Text("Importez des shifts sur iPhone")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    
    private func formatTotalHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
}

// MARK: - Top 3 Card Component

struct Top3CardView: View {
    let rank: Int
    let segment: String
    let hours: Double
    let percentage: Double
    let showHours: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Badge de classement
            HStack {
                Text(medalEmoji)
                    .font(.system(size: 24))
                
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Spacer()
            }
            
            // Nom du segment
            Text(segment)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Heures OU Pourcentage (toggle)
            HStack {
                if showHours {
                    // Affichage heures
                    Text(formatHours(hours))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(rankColor)
                } else {
                    // Affichage pourcentage
                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(rankColor)
                }
                
                Spacer()
                
                // Indicateur opposé (petit)
                if showHours {
                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                } else {
                    Text(formatHours(hours))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rankColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties
    
    private var medalEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "🏅"
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var cardBackground: Color {
        Color.black.opacity(0.3)
    }
    
    // MARK: - Helpers
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
}

// MARK: - Preview

#Preview {
    let manager = WatchDataManager.shared
    manager.top3Shifts = [
        (segment: "Shift 1", hours: 42.5, percentage: 38.2),
        (segment: "Shift 2", hours: 28.0, percentage: 25.1),
        (segment: "Shift 3", hours: 15.5, percentage: 13.9)
    ]
    manager.quarterLabel = "Q2 2025"
    manager.totalHours = 111.5
    manager.lastUpdate = Date()
    
    return Top3View()
        .environmentObject(manager)
}
