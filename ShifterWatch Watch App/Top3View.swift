//
//  Top3View.swift
//  ShifterWatch Watch App
//
//  Vue principale affichant le Top 3 des shifts
//  Style system.css - Classic macOS
//

import SwiftUI

struct Top3View: View {
    @EnvironmentObject var dataManager: WatchDataManager
    
    /// État d'affichage : true = heures, false = pourcentages
    @State private var showHours: Bool = false
    
    var body: some View {
        ZStack {
            // 🖥️ Background beige authentique system.css
            Color(red: 0.933, green: 0.933, blue: 0.933) // #EEEEEE
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 6) {
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
                
                // 🖱️ Indicateur tactile style system.css
                HStack(spacing: 3) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 7))
                    Text("tap = % ↔ h")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.black)
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .onTapGesture {
            // Toggle heures ↔ pourcentages
            withAnimation(.easeInOut(duration: 0.15)) {
                showHours.toggle()
            }
        }
        } // Fermeture ZStack
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            // 🖥️ Fenêtre dialogue system.css
            VStack(spacing: 6) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 20))
                    .foregroundStyle(.black)
                
                Text("Aucune donnée")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                
                Text("Importez des shifts\nsur iPhone")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .background(Color.white)
            .overlay(
                // Bordure noire épaisse system.css
                Rectangle()
                    .strokeBorder(.black, lineWidth: 3)
            )
            .overlay(
                // Inset blanc interne
                Rectangle()
                    .strokeBorder(.white, lineWidth: 1)
                    .padding(1)
            )
        }
        .padding(.vertical, 16)
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
        VStack(spacing: 6) {
            // 🎖️ En-tête centré
            HStack {
                Spacer()
                Text(medalEmoji)
                    .font(.system(size: 22))
                Text(segment)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
            }
            
            // Séparateur noir
            Rectangle()
                .fill(.black)
                .frame(height: 1)
            
            // Valeur unique centrée (TRÈS grande)
            VStack(spacing: 0) {
                if showHours {
                    Text(formatHours(hours))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                } else {
                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            // 🪟 Effet inset 3D system.css avec coins arrondis
            ZStack {
                // Bordure extérieure noire arrondie
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.black, lineWidth: 2)
                
                // Ombre intérieure (top-left)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal, 2)
                    Spacer()
                }
                .padding(2)
                
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 1)
                        .padding(.vertical, 2)
                    Spacer()
                }
                .padding(2)
                
                // Highlight blanc (bottom-right)
                VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(height: 1)
                        .padding(.horizontal, 2)
                }
                .padding(2)
                
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 1)
                        .padding(.vertical, 2)
                }
                .padding(2)
            }
        )
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
    
    private var medalBackgroundColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.95, blue: 0.6) // Or pâle
        case 2: return Color(red: 0.85, green: 0.85, blue: 0.85) // Argent
        case 3: return Color(red: 1.0, green: 0.8, blue: 0.6) // Bronze
        default: return Color(red: 0.7, green: 0.85, blue: 1.0) // Bleu clair
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.8, green: 0.6, blue: 0.0) // Or foncé
        case 2: return Color(red: 0.5, green: 0.5, blue: 0.5) // Gris
        case 3: return Color(red: 0.8, green: 0.4, blue: 0.0) // Orange
        default: return Color(red: 0.0, green: 0.4, blue: 0.8) // Bleu
        }
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
