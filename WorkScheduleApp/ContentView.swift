//
//  ContentView.swift
//  WorkScheduleApp
//
//  Vue principale - Affichage direct des statistiques
//

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
    // MARK: - Propriétés
    
    /// Contexte SwiftData pour la persistance des données
    @Environment(\.modelContext) private var modelContext
    
    /// ViewModel qui gère la logique métier (import OCR, export, backup auto)
    @StateObject private var viewModel = ScheduleViewModel()
    
    /// Images sélectionnées via PhotosPicker pour import OCR
    @State private var selectedItems: [PhotosPickerItem] = []
    
    /// Indicateurs d'affichage des différentes feuilles modales
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingManageSheet = false
    @State private var showingMenu = false
    @State private var showingAboutSheet = false
    
    @State private var exportFileURL: URL?
    @State private var importText = ""
    
    /// Période de temps sélectionnée pour le filtrage (Mois/Trimestre/Année)
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    
    /// Cache des shifts filtrés (optimisation performance)
    @State private var filteredShifts: [Shift] = []
    
    /// Task pour gérer l'annulation des imports concurrents
    @State private var importTask: Task<Void, Never>?
    
    /// Types de période disponibles pour le filtrage
    enum TimePeriod: String, CaseIterable {
        case month = "Mois"
        case quarter = "Trimestre"
        case year = "Année"
    }
    
    var body: some View {
        ZStack {
            // Couleur de fond beige style macOS classique
            Color.systemBeige
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header avec titre et bouton menu
                HStack {
                    HStack(spacing: 4) {
                        Text("Shifter")
                            .font(.custom("Chicago", size: 28))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.systemBlack)
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("v\(version)")
                                .font(.chicago12)
                                .foregroundStyle(Color.systemBlack.opacity(0.6))
                                .padding(.top, 8)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showingMenu.toggle()
                    } label: {
                        Text("⋮")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.systemBlack)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(Color.systemWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.systemBlack, lineWidth: 2)
                    )
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // MARK: - Sélecteur de période et navigation temporelle
                
                // Afficher uniquement si des données existent
                if viewModel.schedules.first != nil {
                    VStack(spacing: 10) {
                        // Boutons Mois/Trimestre/Année
                        HStack(spacing: 8) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Button {
                                    selectedPeriod = period
                                } label: {
                                    let isSelected = selectedPeriod == period
                                    let textColor = isSelected ? Color.systemWhite : Color.systemBlack
                                    let bgColor = isSelected ? Color.systemBlack : Color.systemWhite
                                    
                                    Text(period.rawValue)
                                        .font(.chicago12)
                                        .foregroundStyle(textColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(bgColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.systemBlack, lineWidth: 2)
                                        )
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Navigation temporelle
                        HStack(spacing: 10) {
                            Button {
                                changeDate(by: -1)
                            } label: {
                                Text("◀")
                                    .font(.chicago14)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .cornerRadius(6)
                            
                            Text(periodLabel)
                                .font(.chicago14)
                                .foregroundStyle(Color.systemBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.systemBeige)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.systemBlack, lineWidth: 2)
                                )
                                .cornerRadius(6)
                            
                            Button {
                                changeDate(by: 1)
                            } label: {
                                Text("▶")
                                    .font(.chicago14)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                
                // MARK: - Zone d'affichage des statistiques
                
                // Si des données existent, afficher les statistiques filtrées
                if let schedule = viewModel.schedules.first {
                    ShiftStatisticsView(
                        shifts: filteredShifts,
                        allShifts: schedule.shifts,
                        selectedPeriod: selectedPeriod,
                        selectedDate: selectedDate
                    )
                        .padding(.top, 8)
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("📊")
                            .font(.system(size: 64))
                        Text("Aucune donnée")
                            .font(.chicago14)
                            .foregroundStyle(Color.systemBlack)
                        Text("Importez une capture d'écran\npour voir vos statistiques")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
            }
            
            // MARK: - Overlays
            
            // Overlay de chargement pendant l'OCR
            if viewModel.isLoading {
                loadingOverlay
            }
            
            // Toast vert affiché après restauration automatique du backup
            if viewModel.showRestoredMessage {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("✅")
                            .font(.system(size: 20))
                        Text("Données restaurées automatiquement")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemWhite)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.systemBlack, lineWidth: 2)
                    )
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: viewModel.showRestoredMessage)
            }
            
            // Menu contextuel
            if showingMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingMenu = false
                    }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                                HStack {
                                    Text("📸")
                                        .font(.system(size: 16))
                                    Text("Importer")
                                        .font(.chicago12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                            
                            if viewModel.schedules.first != nil {
                                Divider()
                                    .background(Color.systemBlack)
                                
                                Button {
                                    showingMenu = false
                                    if let zipURL = viewModel.exportToZIP() {
                                        exportFileURL = zipURL
                                        showingExportSheet = true
                                    }
                                } label: {
                                    HStack {
                                        Text("💾")
                                            .font(.system(size: 16))
                                        Text("Exporter")
                                            .font(.chicago12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.systemBlack)
                                .background(Color.systemWhite)
                            }
                            
                            Divider()
                                .background(Color.systemBlack)
                            
                            Button {
                                showingMenu = false
                                showingImportSheet = true
                            } label: {
                                HStack {
                                    Text("📥")
                                        .font(.system(size: 16))
                                    Text("Restaurer")
                                        .font(.chicago12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                            
                            if viewModel.schedules.first != nil {
                                Divider()
                                    .background(Color.systemBlack)
                                
                                Button {
                                    showingMenu = false
                                    showingManageSheet = true
                                } label: {
                                    HStack {
                                        Text("⚙️")
                                            .font(.system(size: 16))
                                        Text("Gérer")
                                            .font(.chicago12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.systemBlack)
                                .background(Color.systemWhite)
                            }
                            
                            Divider()
                                .background(Color.systemBlack)
                            
                            Button {
                                showingMenu = false
                                showingAboutSheet = true
                            } label: {
                                HStack {
                                    Text("ℹ️")
                                        .font(.system(size: 16))
                                    Text("À Propos")
                                        .font(.chicago12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                        }
                        .frame(width: 200)
                        .background(Color.systemWhite)
                        .overlay(
                            Rectangle()
                                .stroke(Color.systemBlack, lineWidth: 2)
                        )
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 4)
                        .padding(.trailing, 16)
                        .padding(.top, 70)
                    }
                    
                    Spacer()
                }
            }
        }
        .persistentSystemOverlays(.hidden)
        // MARK: - Gestion des imports d'images
        
        // Détection de nouvelles images sélectionnées via PhotosPicker
        .onChange(of: selectedItems) { _, newItems in
            // Annuler l'import précédent si en cours (optimisation)
            importTask?.cancel()
            importTask = Task {
                for item in newItems {
                    // Vérifier si la task a été annulée
                    if Task.isCancelled { break }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // Lancer l'OCR et le parsing via le ViewModel
                        await viewModel.importScheduleFromImage(image)
                    }
                }
                selectedItems.removeAll()
            }
        }
        // MARK: - Mise à jour du cache de filtrage
        
        // Recalculer les shifts filtrés quand la date change
        .onChange(of: selectedDate) { _, _ in
            updateFilteredShifts()
        }
        // Recalculer les shifts filtrés quand la période change (mois/trimestre/année)
        .onChange(of: selectedPeriod) { _, _ in
            updateFilteredShifts()
        }
        // Recalculer les shifts filtrés quand les données changent (import, suppression, etc.)
        .onChange(of: viewModel.schedules) { _, _ in
            updateFilteredShifts()
        }
        .alert("Erreur", isPresented: $viewModel.showError) {
            SystemButton("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "Une erreur est survenue")
                .font(.geneva10)
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            updateFilteredShifts()
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportFileURL {
                ExportShareView(fileURL: url, isPresented: $showingExportSheet)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportView(viewModel: viewModel, isPresented: $showingImportSheet)
        }
        .sheet(isPresented: $showingManageSheet) {
            ManageDataView(viewModel: viewModel, isPresented: $showingManageSheet)
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutView(isPresented: $showingAboutSheet)
        }
    }
    
    // MARK: - Helpers
    
    /// Met à jour le cache des shifts filtrés selon la période et la date sélectionnées
    /// Optimisation : évite les recalculs inutiles grâce au cache @State
    private func updateFilteredShifts() {
        guard let schedule = viewModel.schedules.first else {
            filteredShifts = []
            return
        }
        
        let calendar = Calendar.current
        // Filtrer les shifts selon la période sélectionnée
        filteredShifts = schedule.shifts.filter { shift in
            switch selectedPeriod {
            case .month:
                // Même mois et même année
                return calendar.isDate(shift.date, equalTo: selectedDate, toGranularity: .month)
            case .quarter:
                // Même trimestre fiscal (Q1: Oct-Dec, Q2: Jan-Mar, Q3: Apr-Jun, Q4: Jul-Sep)
                return FiscalCalendarHelper.isInSameQuarter(shift.date, selectedDate)
            case .year:
                // Même année
                return calendar.isDate(shift.date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }
    
    private func formatTotalHours() -> String {
        let total = filteredShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        let h = Int(total)
        let m = Int((total - Double(h)) * 60)
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
    
    private var periodLabel: String {
        switch selectedPeriod {
        case .month:
            return selectedDate.monthYear
        case .quarter:
            return FiscalCalendarHelper.quarterLabel(for: selectedDate)
        case .year:
            return selectedDate.yearOnly
        }
    }
    
    private func changeDate(by offset: Int) {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .month:
            if let newDate = calendar.date(byAdding: .month, value: offset, to: selectedDate) {
                selectedDate = newDate
            }
        case .quarter:
            if let newDate = calendar.date(byAdding: .month, value: offset * 3, to: selectedDate) {
                selectedDate = newDate
            }
        case .year:
            if let newDate = calendar.date(byAdding: .year, value: offset, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
    
    // MARK: - Quarter Helpers (déplacés vers FiscalCalendarHelper)
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            SystemDialog(title: "⏳ Analyse OCR") {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.systemBlack)
                    
                    Text("Reconnaissance du texte\nen cours...")
                        .font(.geneva10)
                        .foregroundStyle(Color.systemBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 200, height: 80)
            }
        }
    }
}

// MARK: - Export Share View

struct ExportShareView: View {
    @Environment(\.dismiss) private var dismiss
    let fileURL: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header personnalisé pleine largeur
                HStack {
                    Spacer()
                    Text("Exporter les données")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.systemWhite)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                
                Spacer()
                
                // Zone centrale avec icône et informations
                VStack(spacing: 24) {
                    // Grande icône de package
                    ZStack {
                        Circle()
                            .fill(Color.systemWhite)
                            .frame(width: 140, height: 140)
                            .overlay(
                                Circle()
                                    .stroke(Color.systemBlack, lineWidth: 3)
                            )
                        
                        Text("📦")
                            .font(.system(size: 80))
                    }
                    
                    VStack(spacing: 12) {
                        Text("Fichier ZIP créé !")
                            .font(.custom("Chicago", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.systemBlack)
                        
                        Text("Partagez ou sauvegardez vos données\navec vos applications préférées")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Nom du fichier avec style retro
                    VStack(spacing: 8) {
                        Text("Nom du fichier")
                            .font(.geneva9)
                            .foregroundStyle(Color.systemGray)
                        
                        Text(fileURL.lastPathComponent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.systemBlack)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: 320)
                            .background(Color.systemWhite)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .overlay(
                                // Effet "inset" classique
                                Rectangle()
                                    .strokeBorder(Color.systemGray.opacity(0.3), lineWidth: 1)
                                    .padding(1)
                            )
                    }
                }
                
                Spacer()
                
                // Boutons en bas
                VStack(spacing: 16) {
                    ShareLink(item: fileURL) {
                        HStack(spacing: 12) {
                            Text("📤")
                                .font(.system(size: 20))
                            Text("Partager")
                                .font(.chicago14)
                        }
                        .foregroundStyle(Color.systemBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.systemWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.systemBlack, lineWidth: 3)
                        )
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.15), radius: 0, x: 3, y: 3)
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Fermer")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.systemBeige)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.systemGray, lineWidth: 2)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Import View

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isPresented: Bool
    @State private var jsonText = ""
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header personnalisé pleine largeur
                HStack {
                    Spacer()
                    Text("Restaurer les données")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.systemWhite)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                
                Spacer()
                
                // Zone centrale avec icône et zone de texte
                VStack(spacing: 24) {
                    // Grande icône d'importation
                    ZStack {
                        Circle()
                            .fill(Color.systemWhite)
                            .frame(width: 140, height: 140)
                            .overlay(
                                Circle()
                                    .stroke(Color.systemBlack, lineWidth: 3)
                            )
                        
                        Text("📥")
                            .font(.system(size: 80))
                    }
                    
                    VStack(spacing: 12) {
                        Text("Restaurer vos données")
                            .font(.custom("Chicago", size: 22))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.systemBlack)
                        
                        Text("Collez le contenu JSON de votre\nfichier d'export précédent")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Zone de texte pour le JSON
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Données JSON")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            Spacer()
                            if !jsonText.isEmpty {
                                Text("✓ Données détectées")
                                    .font(.geneva9)
                                    .foregroundStyle(Color.green.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        TextEditor(text: $jsonText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 180)
                            .padding(8)
                            .background(Color.systemWhite)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .overlay(
                                // Effet "inset" classique
                                Rectangle()
                                    .strokeBorder(Color.systemGray.opacity(0.3), lineWidth: 1)
                                    .padding(1)
                            )
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Boutons en bas
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await viewModel.importFromJSON(jsonText)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("💾")
                                .font(.system(size: 20))
                            Text("Restaurer")
                                .font(.chicago14)
                        }
                        .foregroundStyle(jsonText.isEmpty ? Color.systemGray : Color.systemBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(jsonText.isEmpty ? Color.systemWhite.opacity(0.5) : Color.systemWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(jsonText.isEmpty ? Color.systemGray : Color.systemBlack, lineWidth: 3)
                        )
                        .cornerRadius(8)
                        .shadow(color: jsonText.isEmpty ? .clear : .black.opacity(0.15), radius: 0, x: 3, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(jsonText.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Annuler")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.systemBeige)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.systemGray, lineWidth: 2)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            
            // Loading overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.systemWhite)
                        
                        Text("Restauration en cours...")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemWhite)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkSchedule.self, inMemory: true)
}
