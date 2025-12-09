//
//  ContentView.swift
//  WorkScheduleApp
//
//  Vue principale - Affichage direct des statistiques
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif
import SwiftData
import PhotosUI

struct ContentView: View {
    // MARK: - Propriétés
    
    /// Chemin de l'image partagée depuis l'extension (optionnel)
    @Binding var sharedImagePath: String?
    
    /// Contexte SwiftData pour la persistance des données
    @Environment(\.modelContext) private var modelContext
    
    /// ViewModel qui gère la logique métier (import OCR, export, backup auto)
    @StateObject private var viewModel = ScheduleViewModel()
    
    /// Images sélectionnées via PhotosPicker pour import OCR
    @State private var selectedItems: [PhotosPickerItem] = []
    
    /// Document PDF sélectionné pour import
    @State private var showingPDFPicker = false
    
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
    
    /// Alertes pour l'expiration du certificat développeur
    @State private var showingExpiryWarning = false
    @State private var showingExpiryUrgent = false
    
    /// Types de période disponibles pour le filtrage
    enum TimePeriod: String, CaseIterable {
        case month = "Mois"
        case quarter = "Trimestre"
        case year = "Année"
    }
    
    // MARK: - Calcul du temps restant avant expiration
    
    /// Calcule les jours restants avant expiration du certificat développeur (7 jours)
    private var daysRemaining: Int {
        // Récupérer ou initialiser la date d'installation
        if UserDefaults.standard.object(forKey: "firstInstallDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "firstInstallDate")
        }
        
        guard let installDate = UserDefaults.standard.object(forKey: "firstInstallDate") as? Date else {
            return 7
        }
        
        // Expiration complète : 7 jours
        let expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: installDate)!
        let components = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate)
        return max(0, components.day ?? 0)
    }
    
    /// Calcule les heures restantes (pour affichage détaillé)
    private var hoursRemaining: Int {
        guard let installDate = UserDefaults.standard.object(forKey: "firstInstallDate") as? Date else {
            return 0
        }
        
        let expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: installDate)!
        let components = Calendar.current.dateComponents([.hour], from: Date(), to: expiryDate)
        return max(0, components.hour ?? 0)
    }
    
    /// Couleur du badge selon l'urgence
    private var expiryBadgeColor: Color {
        switch daysRemaining {
        case 0...1: return .red
        case 2...3: return .orange
        case 4...5: return .green
        default: return .green // 6-7 jours
        }
    }
    
    // Logo Shifter avec fallback
    private var logoView: some View {
        Image("ShifterLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 45)
    }
    
    var body: some View {
        ZStack {
            // Couleur de fond beige style macOS classique
            Color.systemBeige
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header avec titre et bouton menu (FIXE)
                HStack(alignment: .center, spacing: 0) {
                    // Groupe logo + infos à gauche
                    HStack(spacing: 6) {
                        logoView
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(version)")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.systemBlack.opacity(0.6))
                                
                                // Badge du timer de certificat développeur
                                HStack(spacing: 3) {
                                    Text(daysRemaining == 0 ? "⏱️" : "🕐")
                                        .font(.system(size: 10))
                                    Text("\(daysRemaining)j")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(expiryBadgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(expiryBadgeColor.opacity(0.2))
                                .cornerRadius(3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(expiryBadgeColor, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    Spacer() // Pousse le menu vers la droite
                    
                    // Bouton menu aligné à droite
                    Button {
                        showingMenu.toggle()
                    } label: {
                        Text("⋮")
                            .font(.system(size: 28, weight: .bold))
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
                .background(Color.systemBeige) // Fond fixe
                
                // MARK: - Sélecteur de période et navigation temporelle (FIXE)
                
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
                    .background(Color.systemBeige) // Fond fixe
                }
                
                // MARK: - Zone d'affichage des statistiques (SCROLLABLE)
                
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
                            .font(.system(size: 72))
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
                            .font(.system(size: 24))
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

            // Toast d'ajout de shift
            if let msg = viewModel.addedShiftMessage {
                VStack {
                    Spacer()

                    HStack(spacing: 12) {
                        Text("✅")
                            .font(.system(size: 20))
                        Text(msg)
                            .font(.chicago12)
                            .foregroundStyle(Color.systemWhite)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.systemBlack, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeOut(duration: 0.25), value: viewModel.addedShiftMessage)
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
                            PhotosPicker(selection: $selectedItems, matching: .images) {
                                HStack {
                                    Text("📸")
                                        .font(.system(size: 20))
                                    Text("Images")
                                        .font(.chicago12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.systemBlack)
                            .background(Color.systemWhite)
                            
                            Divider()
                                .background(Color.systemBlack)
                            
                            Button {
                                showingMenu = false
                                showingPDFPicker = true
                            } label: {
                                HStack {
                                    Text("📄")
                                        .font(.system(size: 20))
                                    Text("PDF")
                                        .font(.chicago12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
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
                                    .contentShape(Rectangle())
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
                                .contentShape(Rectangle())
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
                                    .contentShape(Rectangle())
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
                                .contentShape(Rectangle())
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
        .onAppear {
            // Vérifier l'expiration du certificat et afficher les alertes appropriées
            checkCertificateExpiry()
        }
        // MARK: - Gestion des imports d'images
        
        // Détection de nouvelles images sélectionnées via PhotosPicker
        .onChange(of: selectedItems) { _, newItems in
            // Fermer le menu automatiquement après sélection
            showingMenu = false
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
        .onReceive(viewModel.$schedules) { _ in
            // Publisher plus fiable: quand le ViewModel publie des schedules, recalculer
            updateFilteredShifts()
        }
        .onChange(of: showingManageSheet) { _, newValue in
            // Quand la feuille de gestion se ferme, forcer un refresh (utile après ajout manuel)
            if !newValue {
                updateFilteredShifts()
            }
        }
        .onChange(of: selectedDate) { _, _ in
            // Recalculer quand l'utilisateur change de date / mois
            updateFilteredShifts()
        }
        .onChange(of: selectedPeriod) { _, _ in
            // Recalculer quand l'utilisateur change la période (Mois/Trimestre/Année)
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
        .fileImporter(
            isPresented: $showingPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handlePDFSelection(result)
        }
        .alert("⚠️ Expiration Proche", isPresented: $showingExpiryWarning) {
            Button("OK", role: .cancel) { }
            Button("💾 Sauvegarder", role: .none) {
                if let zipURL = viewModel.exportToZIP() {
                    exportFileURL = zipURL
                    showingExportSheet = true
                }
            }
        } message: {
            Text("Votre certificat développeur expire dans \(daysRemaining) jour\(daysRemaining > 1 ? "s" : "").\n\nPensez à exporter vos données. La sauvegarde automatique est active dans Documents/shifter_auto_backup.json")
                .font(.geneva10)
        }
        .alert("🚨 Expiration Imminente", isPresented: $showingExpiryUrgent) {
            Button("Plus tard", role: .cancel) { }
            Button("💾 Exporter Maintenant", role: .none) {
                if let zipURL = viewModel.exportToZIP() {
                    exportFileURL = zipURL
                    showingExportSheet = true
                }
            }
        } message: {
            Text("Votre certificat développeur expire dans moins de 2 jours !\n\n⏱️ Temps restant : \(daysRemaining)j \(hoursRemaining % 24)h\n\nExportez vos données MAINTENANT pour éviter toute perte. Le backup automatique est actif mais un export manuel est recommandé.")
                .font(.geneva10)
        }
        .onChange(of: sharedImagePath) { _, imagePath in
            handleSharedImage(imagePath)
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
    
    /// Vérifie l'expiration du certificat développeur et affiche les alertes appropriées
    private func checkCertificateExpiry() {
        let days = daysRemaining
        
        // Alerte urgente (J0-1)
        if days <= 1 {
            // Afficher l'alerte urgente seulement une fois par jour
            let lastUrgentAlertKey = "lastUrgentAlertDate"
            let lastAlert = UserDefaults.standard.object(forKey: lastUrgentAlertKey) as? Date
            let calendar = Calendar.current
            
            if lastAlert == nil || !calendar.isDateInToday(lastAlert!) {
                UserDefaults.standard.set(Date(), forKey: lastUrgentAlertKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingExpiryUrgent = true
                }
            }
        }
        // Alerte avertissement (J2-3)
        else if days <= 3 {
            let lastWarningAlertKey = "lastWarningAlertDate"
            let lastAlert = UserDefaults.standard.object(forKey: lastWarningAlertKey) as? Date
            let calendar = Calendar.current
            
            if lastAlert == nil || !calendar.isDateInToday(lastAlert!) {
                UserDefaults.standard.set(Date(), forKey: lastWarningAlertKey)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingExpiryWarning = true
                }
            }
        }
    }
    
    /// Traite une image reçue depuis l'extension de partage
    private func handleSharedImage(_ imagePath: String?) {
        guard let imagePath = imagePath else { return }
        
        Task {
            let fileURL = URL(fileURLWithPath: imagePath)
            
            // Vérifier que le fichier existe
            guard FileManager.default.fileExists(atPath: imagePath),
                  let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                return
            }
            
            // Lancer l'import OCR
            await viewModel.importScheduleFromImage(image)
            
            // Nettoyer le fichier temporaire
            try? FileManager.default.removeItem(at: fileURL)
            
            // Réinitialiser le chemin
            sharedImagePath = nil
        }
    }
    
    /// Traite la sélection d'un fichier PDF pour import
    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Annuler tout import en cours
            importTask?.cancel()
            
            // Lancer l'import PDF
            importTask = Task {
                await viewModel.importScheduleFromPDF(url)
            }
            
        case .failure(let error):
            AppLogger.shared.error("❌ Erreur sélection PDF: \(error.localizedDescription)")
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

// MARK: - ZIP import handling
extension ImportView {
    /// Décompresse l'archive ZIP vers le dossier Documents/Shifter
    /// Si l'archive contient un fichier JSON, tente d'appeler `viewModel.importFromJSON`
    func handleImportedZip(_ zipURL: URL) async {
#if canImport(ZIPFoundation)
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let shifterDir = docs.appendingPathComponent("Shifter", isDirectory: true)

        do {
            // Créer le dossier Shifter s'il n'existe pas
            if !fileManager.fileExists(atPath: shifterDir.path) {
                try fileManager.createDirectory(at: shifterDir, withIntermediateDirectories: true)
            }

            // Destination temporaire pour l'extraction (utiliser tmp pour éviter de créer des sous-dossiers Shifter)
            let tempDir = fileManager.temporaryDirectory
            let dest = tempDir.appendingPathComponent("shifter_unzipped_\(UUID().uuidString)")
            try fileManager.createDirectory(at: dest, withIntermediateDirectories: true)

            // Décompresser avec ZIPFoundation
            try fileManager.unzipItem(at: zipURL, to: dest)

            // Parcourir récursivement les fichiers extraits pour trouver des JSON
            var extractedURLs: [URL] = []
            if let enumerator = fileManager.enumerator(at: dest, includingPropertiesForKeys: nil) {
                // Use `nextObject()` loop instead of `for in` to avoid `makeIterator` usage in async context
                while let next = enumerator.nextObject() as? URL {
                    extractedURLs.append(next)
                }
            }

            let jsonFiles = extractedURLs.filter { $0.pathExtension.lowercased() == "json" }

            guard !jsonFiles.isEmpty else {
                // Aucun JSON trouvé dans l'archive
                await MainActor.run {
                    zipImportError = "Aucun fichier JSON trouvé dans l'archive."
                }
                try? fileManager.removeItem(at: dest)
                return
            }

            // Préférer un fichier nommé shifts_export_... si présent
            let preferred = jsonFiles.first(where: { $0.lastPathComponent.hasPrefix("shifts_export_") }) ?? jsonFiles.first!

            // Déplacer / renommer le fichier JSON extrait vers Documents/shifter_auto_backup.json (racine Documents)
            let backupURL = docs.appendingPathComponent("shifter_auto_backup.json")
            do {
                // Supprimer l'ancien backup si présent
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }

                // Tenter un move pour renommer le fichier (préserve métadonnées)
                do {
                    try fileManager.moveItem(at: preferred, to: backupURL)
                } catch {
                    // Si move échoue (cross-device), copier le contenu puis supprimer l'original
                    let jsonContent = try String(contentsOf: preferred, encoding: .utf8)
                    try jsonContent.write(to: backupURL, atomically: true, encoding: .utf8)
                    try? fileManager.removeItem(at: preferred)
                }

                // Importer immédiatement depuis le backup écrit
                let importedJSON = try String(contentsOf: backupURL, encoding: .utf8)
                await viewModel.importFromJSON(importedJSON)

                // Si le dossier `Shifter` existe mais est vide, le supprimer pour éviter un dossier vide dans Fichiers
                if fileManager.fileExists(atPath: shifterDir.path) {
                    if let children = try? fileManager.contentsOfDirectory(atPath: shifterDir.path), children.isEmpty {
                        #if DEBUG
                        print("🔧 Supprimer dossier vide: \(shifterDir.path)")
                        #endif
                        try? fileManager.removeItem(at: shifterDir)
                    }
                }

                // Nettoyer le dossier temporaire d'extraction
                try? fileManager.removeItem(at: dest)

                // Signaler succès
                await MainActor.run {
                    zipImportError = nil
                    zipImportSuccess = true
                }
                #if DEBUG
                print("✅ ZIP import réussi, backup écrit à: \(backupURL.path)")
                #endif
            } catch {
                await MainActor.run {
                    zipImportError = "Impossible de lire/déplacer le JSON: \(error.localizedDescription)"
                }
                    try? fileManager.removeItem(at: dest)
                return
            }

            // Nettoyer le dossier temporaire
            try? fileManager.removeItem(at: dest)

            // Signaler succès
            await MainActor.run {
                zipImportSuccess = true
            }
        } catch {
            await MainActor.run {
                zipImportError = "Erreur décompression: \(error.localizedDescription)"
            }
        }
#else
        // ZIPFoundation non disponible -> afficher erreur guidant l'utilisateur
        await MainActor.run {
            zipImportError = "ZIPFoundation manquant. Ajoutez le package SPM https://github.com/weichsel/ZIPFoundation puis reconstruisez."
        }
#endif
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
    @State private var showingZipImporter = false
    @State private var zipImportError: String?
    @State private var zipImportSuccess: Bool = false
    
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
                    // Importer un fichier ZIP (contenant un export JSON ou des ressources)
                    Button {
                        showingZipImporter = true
                    } label: {
                        HStack(spacing: 12) {
                            Text("📦")
                                .font(.system(size: 20))
                            Text("Importer un .zip")
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
                    }
                    .fileImporter(isPresented: $showingZipImporter, allowedContentTypes: [UTType.zip], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            Task {
                                await handleImportedZip(url)
                            }
                        case .failure(let error):
                            zipImportError = "Erreur sélection fichier: \(error.localizedDescription)"
                        }
                    }

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

            // Alert messages for ZIP import
            .alert("Erreur", isPresented: Binding(get: { zipImportError != nil }, set: { if !$0 { zipImportError = nil } })) {
                Button("OK", role: .cancel) { zipImportError = nil }
            } message: {
                Text(zipImportError ?? "Erreur inconnue")
            }
            .alert("Import terminé", isPresented: $zipImportSuccess) {
                Button("OK", role: .cancel) { zipImportSuccess = false }
            } message: {
                Text("L'archive a été décompressée dans le dossier \"Shifter\" de Fichiers.")
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
    ContentView(sharedImagePath: .constant(nil))
        .modelContainer(for: WorkSchedule.self, inMemory: true)
}
