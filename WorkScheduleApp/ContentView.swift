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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var showingManageSheet = false
    @State private var showingMenu = false
    @State private var exportFileURL: URL?
    @State private var importText = ""
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    @State private var cachedFilteredShifts: [Shift] = []
    @State private var lastFilteredDate: Date?
    @State private var lastFilteredPeriod: TimePeriod?
    
    enum TimePeriod: String, CaseIterable {
        case month = "Mois"
        case quarter = "Trimestre"
        case year = "Année"
    }
    
    var body: some View {
        ZStack {
            Color.systemBeige
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header avec titre et bouton menu
                HStack {
                    Text("Shifts Visual")
                        .font(.custom("Chicago", size: 28))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.systemBlack)
                    
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
                
                // Sélecteur de période et navigation temporelle
                if viewModel.schedules.first != nil {
                    VStack(spacing: 10) {
                        // Sélecteur Mois/Trimestre/Année
                        HStack(spacing: 8) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Button {
                                    selectedPeriod = period
                                } label: {
                                    Text(period.rawValue)
                                        .font(.chicago12)
                                        .foregroundStyle(selectedPeriod == period ? Color.systemWhite : Color.systemBlack)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(selectedPeriod == period ? Color.systemBlack : Color.systemWhite)
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
                
                // Statistiques directement affichées
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
            
            if viewModel.isLoading {
                loadingOverlay
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
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.importScheduleFromImage(image)
                    }
                }
                selectedItems.removeAll()
            }
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
    }
    
    // MARK: - Helpers
    
    private var filteredShifts: [Shift] {
        // Cache invalidation: recalculer seulement si période ou date ont changé
        let needsUpdate = lastFilteredDate != selectedDate || lastFilteredPeriod != selectedPeriod
        
        if needsUpdate {
            guard let schedule = viewModel.schedules.first else { return [] }
            
            let calendar = Calendar.current
            let filtered = schedule.shifts.filter { shift in
                switch selectedPeriod {
                case .month:
                    return calendar.isDate(shift.date, equalTo: selectedDate, toGranularity: .month)
                case .quarter:
                    return FiscalCalendarHelper.isInSameQuarter(shift.date, selectedDate)
                case .year:
                    return calendar.isDate(shift.date, equalTo: selectedDate, toGranularity: .year)
                }
            }
            
            // Mettre à jour le cache (nécessite DispatchQueue car @State immutable dans computed property)
            DispatchQueue.main.async {
                self.cachedFilteredShifts = filtered
                self.lastFilteredDate = self.selectedDate
                self.lastFilteredPeriod = self.selectedPeriod
            }
            return filtered
        }
        
        return cachedFilteredShifts
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
