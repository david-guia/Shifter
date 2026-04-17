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
    @State private var viewModel = ScheduleViewModel()
    
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
    @State private var showingWorkJamSheet = false
    
    @State private var exportFileURL: URL?
    
    /// Période de temps sélectionnée pour le filtrage (Mois/Trimestre/Année)
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    
    /// Cache des shifts filtrés (optimisation performance)
    @State private var filteredShifts: [Shift] = []
    
    /// Sens de la navigation pour l'animation de transition
    @State private var isNavigatingForward: Bool = true
    
    /// Task pour gérer l'annulation des imports concurrents
    @State private var importTask: Task<Void, Never>?
    
    /// ViewModel dédié à la sync automatique WorkJam au lancement
    @State private var workJamAutoSync = WorkJamAuthViewModel()

    /// Alertes pour l'expiration du certificat développeur
    @State private var showingExpiryWarning = false
    @State private var showingExpiryUrgent = false
    
    /// État pour le résumé Apple Intelligence
    @State private var showingSummarySheet = false
    
    /// Types de période disponibles pour le filtrage
    enum TimePeriod: String, CaseIterable {
        case month = "Mois"
        case quarter = "Trimestre"
        case year = "Année"
    }
    
    // MARK: - Calcul du temps restant avant expiration
    
    /// Calcule les jours restants avant expiration du certificat développeur (7 jours)
    private var daysRemaining: Int {
        // Vérifier si c'est une nouvelle installation en comparant le build
        detectAndResetIfNewInstallation()
        
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
    
    /// Détecte une nouvelle installation et réinitialise le timer si nécessaire
    private func detectAndResetIfNewInstallation() {
        // Méthode 1: Vérifier le chemin d'installation (change à chaque Cmd+R)
        let currentAppPath = Bundle.main.bundlePath
        let storedAppPathKey = "lastKnownAppPath"
        let storedAppPath = UserDefaults.standard.string(forKey: storedAppPathKey)
        
        #if DEBUG
        print("🔍 Détection installation:")
        print("   Chemin actuel: \(currentAppPath)")
        if let stored = storedAppPath {
            print("   Chemin stocké: \(stored)")
        } else {
            print("   Chemin stocké: AUCUN (première installation)")
        }
        #endif
        
        // Si le chemin a changé, c'est une nouvelle installation
        if let stored = storedAppPath, stored != currentAppPath {
            #if DEBUG
            print("🔄 ✅ NOUVELLE INSTALLATION DÉTECTÉE - Réinitialisation du timer")
            #endif
            
            // Réinitialiser la date d'installation et les alertes
            UserDefaults.standard.removeObject(forKey: "firstInstallDate")
            UserDefaults.standard.removeObject(forKey: "lastWarningAlertDate")
            UserDefaults.standard.removeObject(forKey: "lastUrgentAlertDate")
        }
        
        // Sauvegarder le chemin actuel
        if storedAppPath != currentAppPath {
            UserDefaults.standard.set(currentAppPath, forKey: storedAppPathKey)
            #if DEBUG
            print("💾 Chemin d'installation sauvegardé")
            #endif
        }
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
    
    // Badge du timer de certificat développeur
    private var certificateBadge: some View {
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
    
    // Vue du logo avec version et badge
    private var logoWithVersion: some View {
        HStack(spacing: 6) {
            logoView
            
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(version)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.systemBlack.opacity(0.6))
                    
                    certificateBadge
                }
            }
        }
    }
    
    // Bouton résumé AI
    private var summaryButton: some View {
        Button {
            generateSummary()
        } label: {
            Text("✨")
                .font(.system(size: 22))
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
    
    // Bouton menu
    private var menuButton: some View {
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
    
    // Bouton de sélection de période
    private func periodButton(_ period: TimePeriod) -> some View {
        let isSelected = selectedPeriod == period
        let textColor = isSelected ? Color.systemWhite : Color.systemBlack
        let bgColor = isSelected ? Color.systemBlack : Color.systemWhite
        
        return Button {
            selectedPeriod = period
        } label: {
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
    
    // Header avec logo et boutons
    private var headerView: some View {
        HStack(alignment: .center, spacing: 0) {
            logoWithVersion
            Spacer()
            if viewModel.schedules.first != nil {
                summaryButton
                    .padding(.trailing, 12)
            }
            menuButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color.systemBeige)
    }
    
    // Sélecteur de période
    private var periodSelector: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    periodButton(period)
                }
            }
            navigationControls
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Color.systemBeige)
    }
    
    // Contrôles de navigation (flèches + label)
    private var navigationControls: some View {
        HStack(spacing: 10) {
            navigationButton(direction: .previous)
            periodLabelView
            navigationButton(direction: .next)
        }
    }
    
    private enum NavigationDirection {
        case previous, next
    }
    
    private func navigationButton(direction: NavigationDirection) -> some View {
        let forward = direction == .next
        let canNavigate = forward ? canGoForward : canGoBack

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                navigatePeriod(forward: forward)
            }
        } label: {
            Text(direction == .previous ? "◀" : "▶")
                .font(.chicago14)
                .frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(canNavigate ? Color.systemBlack : Color.systemGray.opacity(0.4))
        .background(Color.systemWhite)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(canNavigate ? Color.systemBlack : Color.systemGray.opacity(0.4), lineWidth: 2)
        )
        .cornerRadius(6)
        .disabled(!canNavigate)
    }
    
    private var periodLabelView: some View {
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
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: periodLabel)
    }
    
    var statisticsContent: some View {
        Group {
            if let schedule = viewModel.schedules.first {
                ShiftStatisticsView(
                    shifts: filteredShifts,
                    allShifts: schedule.shifts,
                    selectedPeriod: selectedPeriod,
                    selectedDate: selectedDate
                )
                .padding(.top, 8)
                .id("\(selectedPeriod.rawValue)-\(selectedDate.timeIntervalSince1970)")
                .transition(.asymmetric(
                    insertion: .move(edge: isNavigatingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: isNavigatingForward ? .leading : .trailing).combined(with: .opacity)
                ))
                .gesture(swipeGesture)
            } else {
                emptyStateView
            }
        }
    }
    
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontalMovement = value.translation.width
                
                if horizontalMovement < -50 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        navigatePeriod(forward: true)
                    }
                } else if horizontalMovement > 50 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        navigatePeriod(forward: false)
                    }
                }
            }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 0) {
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
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                if viewModel.schedules.first != nil {
                    periodSelector
                }
                
                statisticsContent
            }
            
            // MARK: - Overlays
            
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
                                showingWorkJamSheet = true
                            } label: {
                                HStack {
                                    Text("⬇️")
                                        .font(.system(size: 16))
                                    Text("WorkJam Auto")
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
            snapToNearestNonEmpty()
            updateFilteredShifts()
        }
        // Recalculer les shifts filtrés quand les données changent (import, suppression, etc.)
        .onChange(of: viewModel.schedules) { _, _ in
            updateFilteredShifts()
        }
        // Trigger explicite pour forcer le rafraîchissement après toute modification
        .onChange(of: viewModel.dataRefreshTrigger) { _, _ in
            updateFilteredShifts()
        }
        .onChange(of: showingManageSheet) { _, newValue in
            // Quand la feuille de gestion se ferme, forcer un refresh (utile après ajout manuel)
            if !newValue {
                updateFilteredShifts()
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
            updateFilteredShifts()
            snapToNearestNonEmpty()
        }
        .task {
            // Sync automatique WorkJam au lancement (si connecté et sync > 6h)
            await workJamAutoSync.autoSyncIfNeeded(context: modelContext)
        }
        .onChange(of: workJamAutoSync.showImportSuccess) { _, success in
            guard success, workJamAutoSync.importedCount > 0 else { return }
            let count = workJamAutoSync.importedCount
            viewModel.fetchSchedules()
            updateFilteredShifts()
            let countLabel = count > 1 ? "\(count) shifts mis à jour" : "1 shift mis à jour"
            viewModel.addedShiftMessage = "↻ WorkJam synchronisé — \(countLabel)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                viewModel.addedShiftMessage = nil
                workJamAutoSync.showImportSuccess = false
            }
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
            ManageDataView(viewModel: viewModel, isPresented: $showingManageSheet, initialDate: selectedDate)
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutView(isPresented: $showingAboutSheet)
        }
        .sheet(isPresented: $showingWorkJamSheet) {
            WorkJamLoginView(isPresented: $showingWorkJamSheet) { count in
                viewModel.fetchSchedules()
                updateFilteredShifts()
                if count > 0 {
                    viewModel.addedShiftMessage = "\(count) shift\(count > 1 ? "s" : "") importé\(count > 1 ? "s" : "") depuis WorkJam"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        viewModel.addedShiftMessage = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showingSummarySheet) {
            SimpleSummarySheet(
                viewModel: viewModel,
                selectedPeriod: selectedPeriod,
                selectedDate: selectedDate,
                filteredShifts: filteredShifts,
                periodLabel: periodLabel,
                isPresented: $showingSummarySheet
            )
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
    
    /// Navigation par swipe sur le tableau des statistiques — saute les périodes vides
    private func navigatePeriod(forward: Bool) {
        guard let newDate = nextNonEmptyDate(from: selectedDate, forward: forward) else { return }
        isNavigatingForward = forward
        selectedDate = newDate
    }

    /// Renvoie true si la période contient au moins un shift
    private func hasShifts(for date: Date, period: TimePeriod) -> Bool {
        guard let schedule = viewModel.schedules.first else { return false }
        let calendar = Calendar.current
        return schedule.shifts.contains { shift in
            switch period {
            case .month:   return calendar.isDate(shift.date, equalTo: date, toGranularity: .month)
            case .quarter: return FiscalCalendarHelper.isInSameQuarter(shift.date, date)
            case .year:    return calendar.isDate(shift.date, equalTo: date, toGranularity: .year)
            }
        }
    }

    /// Trouve la prochaine période non vide dans la direction donnée (max 120 itérations)
    private func nextNonEmptyDate(from date: Date, forward: Bool) -> Date? {
        guard let schedule = viewModel.schedules.first, !schedule.shifts.isEmpty else { return nil }
        let calendar = Calendar.current
        var candidate = date
        for _ in 0..<120 {
            switch selectedPeriod {
            case .month:   candidate = calendar.date(byAdding: .month, value: forward ? 1 : -1, to: candidate) ?? candidate
            case .quarter: candidate = calendar.date(byAdding: .month, value: forward ? 3 : -3, to: candidate) ?? candidate
            case .year:    candidate = calendar.date(byAdding: .year, value: forward ? 1 : -1, to: candidate) ?? candidate
            }
            if hasShifts(for: candidate, period: selectedPeriod) { return candidate }
        }
        return nil
    }

    /// True s'il existe au moins une période avec des données en avant
    private var canGoForward: Bool { nextNonEmptyDate(from: selectedDate, forward: true) != nil }
    /// True s'il existe au moins une période avec des données en arrière
    private var canGoBack: Bool { nextNonEmptyDate(from: selectedDate, forward: false) != nil }

    /// Recale selectedDate sur la période non vide la plus proche (utile au changement de granularité)
    private func snapToNearestNonEmpty() {
        guard let schedule = viewModel.schedules.first, !schedule.shifts.isEmpty else { return }
        if hasShifts(for: selectedDate, period: selectedPeriod) { return }
        if let next = nextNonEmptyDate(from: selectedDate, forward: false) { selectedDate = next; return }
        if let next = nextNonEmptyDate(from: selectedDate, forward: true)  { selectedDate = next }
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
    
    /// Génère un résumé intelligent des statistiques
    private func generateSummary() {
        showingSummarySheet = true
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
    @Bindable var viewModel: ScheduleViewModel
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

// MARK: - Simple Summary Sheet

struct SimpleSummarySheet: View {
    let viewModel: ScheduleViewModel
    let selectedPeriod: ContentView.TimePeriod
    let selectedDate: Date
    let filteredShifts: [Shift]
    let periodLabel: String
    @Binding var isPresented: Bool
    
    @State private var comparisonType: ComparisonType = .none
    @State private var summaryText: String = ""
    
    enum ComparisonType: String, CaseIterable {
        case none = "Sans comparaison"
        case previousPeriod = "Période précédente"
        case previousYear = "Année précédente"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                comparisonPicker
                
                ScrollView {
                    Text(summaryText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.systemBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
            }
            .background(Color.systemBeige)
            .navigationTitle("✨ Résumé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
                ToolbarItem(placement: .primaryAction) {
                    toolbarButtons
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            generateText()
        }
        .onChange(of: comparisonType) { _, _ in
            generateText()
        }
    }
    
    private var closeButton: some View {
        Button("Fermer") {
            isPresented = false
        }
    }
    
    private var comparisonPicker: some View {
        Picker("Comparaison", selection: $comparisonType) {
            ForEach(ComparisonType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemWhite)
    }
    
    private var toolbarButtons: some View {
        HStack(spacing: 8) {
            copyButton
            shareButton
        }
    }
    
    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = summaryText
        } label: {
            Image(systemName: "doc.on.doc")
        }
    }
    
    private var shareButton: some View {
        ShareLink(item: summaryText) {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    private func generateText() {
        summaryText = buildSummaryText(comparisonType: comparisonType)
    }
    
    private func buildSummaryText(comparisonType: ComparisonType) -> String {
        let stats = calculateStatistics()
        
        var text = ""
        text += "📊 Analyse de la période \(periodLabel)\n\n"
        
        if stats.total == 0 {
            text += "Aucune activité n'a été enregistrée durant cette période.\n\n"
            text += "💡 Astuce : Importez vos plannings WorkJam pour commencer à suivre vos heures de travail."
            return text
        }
        
        if comparisonType != .none {
            if let comparison = getComparisonData(type: comparisonType) {
                text += comparison
            }
        }
        
        text += buildOverviewSection(stats: stats)
        text += buildActivitiesSection(stats: stats)
        text += buildKeyPointsSection(stats: stats)
        
        return text
    }
    
    private func calculateStatistics() -> (total: Double, count: Int, segments: [(key: String, value: Double)]) {
        let total = filteredShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        let count = filteredShifts.filter { $0.segment != "Général" }.count
        
        var segmentStats: [String: Double] = [:]
        for shift in filteredShifts where shift.segment != "Général" {
            segmentStats[shift.segment, default: 0] += shift.duration / 3600
        }
        
        let sorted = segmentStats.sorted { $0.value > $1.value }
        return (total, count, sorted)
    }
    
    private func buildOverviewSection(stats: (total: Double, count: Int, segments: [(key: String, value: Double)])) -> String {
        var text = "🎯 Vue d'ensemble\n\n"
        text += "Au cours de cette période, vous avez effectué \(stats.count) shift\(stats.count > 1 ? "s" : "") "
        text += "pour un total de \(formatHours(stats.total)) de travail. "
        
        let avgHoursPerShift = stats.total / Double(stats.count)
        text += "En moyenne, chaque shift représente \(formatHours(avgHoursPerShift)) de travail.\n\n"
        
        return text
    }
    
    private func buildActivitiesSection(stats: (total: Double, count: Int, segments: [(key: String, value: Double)])) -> String {
        guard !stats.segments.isEmpty else { return "" }
        
        var text = "📈 Répartition détaillée des activités\n\n"
        
        let topSegment = stats.segments[0]
        let topPercentage = (topSegment.value / stats.total) * 100
        
        text += "Votre activité principale est \"\(topSegment.key)\" avec \(formatHours(topSegment.value)) travaillées, "
        text += "ce qui représente \(String(format: "%.0f", topPercentage))% de votre temps total. "
        
        if topPercentage > 50 {
            text += "Cette activité domine largement votre emploi du temps.\n\n"
        } else if topPercentage > 30 {
            text += "Cette activité occupe une part significative de votre temps.\n\n"
        } else {
            text += "Votre temps est réparti de manière équilibrée entre plusieurs activités.\n\n"
        }
        
        if stats.segments.count > 1 {
            text += "Vos autres activités principales incluent :\n\n"
            
            for (segment, hours) in stats.segments.dropFirst().prefix(4) {
                let percentage = (hours / stats.total) * 100
                text += "• \(segment) : \(formatHours(hours)) (\(String(format: "%.0f", percentage))%)\n"
            }
            text += "\n"
        }
        
        if stats.segments.count > 5 {
            text += "Vous avez effectué \(stats.segments.count) types d'activités différentes, "
            text += "ce qui démontre une grande polyvalence dans vos tâches.\n\n"
        }
        
        return text
    }
    
    private func buildKeyPointsSection(stats: (total: Double, count: Int, segments: [(key: String, value: Double)])) -> String {
        var text = "💡 Points clés à retenir\n\n"
        
        if let maxSegment = stats.segments.first, let minSegment = stats.segments.last, stats.segments.count > 2 {
            let ratio = maxSegment.value / minSegment.value
            if ratio > 5 {
                text += "• Votre temps est fortement concentré sur quelques activités principales.\n"
            } else {
                text += "• Votre temps est bien équilibré entre vos différentes activités.\n"
            }
        }
        
        let avgHoursPerShift = stats.total / Double(stats.count)
        if avgHoursPerShift > 7 {
            text += "• Vos shifts sont généralement longs, dépassant une journée de travail standard.\n"
        } else if avgHoursPerShift < 4 {
            text += "• Vos shifts sont plutôt courts, vous permettant une flexibilité accrue.\n"
        }
        
        text += "• Cette période représente \(formatHours(stats.total)) de travail documenté et analysé.\n\n"
        text += "✨ Ce résumé a été généré automatiquement. Vous pouvez le copier ou le partager."
        
        return text
    }
    
    private func getComparisonData(type: ComparisonType) -> String? {
        guard let schedule = viewModel.schedules.first else { return nil }
        
        let comparisonShifts = getComparisonShifts(type: type, allShifts: schedule.shifts)
        guard !comparisonShifts.isEmpty else { return nil }
        
        let currentTotal = filteredShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        let currentCount = filteredShifts.filter { $0.segment != "Général" }.count
        
        let comparisonTotal = comparisonShifts.filter { $0.segment != "Général" }.reduce(0.0) { $0 + $1.duration / 3600 }
        let comparisonCount = comparisonShifts.filter { $0.segment != "Général" }.count
        
        return buildComparisonText(
            type: type,
            currentTotal: currentTotal,
            currentCount: currentCount,
            comparisonTotal: comparisonTotal,
            comparisonCount: comparisonCount,
            comparisonShifts: comparisonShifts
        )
    }
    
    private func buildComparisonText(
        type: ComparisonType,
        currentTotal: Double,
        currentCount: Int,
        comparisonTotal: Double,
        comparisonCount: Int,
        comparisonShifts: [Shift]
    ) -> String {
        let comparisonPeriodLabel = getComparisonPeriodLabel(type: type)
        var compText = "📊 Comparaison : \(periodLabel) vs \(comparisonPeriodLabel)\n\n"
        
        let hoursDiff = currentTotal - comparisonTotal
        let shiftsDiff = currentCount - comparisonCount
        let percentChange = comparisonTotal > 0 ? ((currentTotal - comparisonTotal) / comparisonTotal * 100) : 0
        let avgCurrent = currentCount > 0 ? currentTotal / Double(currentCount) : 0
        let avgComparison = comparisonCount > 0 ? comparisonTotal / Double(comparisonCount) : 0
        let avgDiff = avgCurrent - avgComparison
        
        // Analyse du volume global
        if abs(percentChange) > 5 {
            let arrow = hoursDiff > 0 ? "📈" : "📉"
            let sign = hoursDiff > 0 ? "+" : ""
            let trend = hoursDiff > 0 ? "augmentation" : "diminution"
            compText += "\(arrow) Volume de travail : \(sign)\(formatHours(abs(hoursDiff))) (\(sign)\(String(format: "%.0f", percentChange))%)\n"
            compText += "   Cette \(trend) significative reflète "
            
            if abs(percentChange) > 20 {
                compText += "un changement majeur dans votre charge de travail.\n\n"
            } else {
                compText += "une évolution notable de votre activité.\n\n"
            }
        } else {
            compText += "➡️ Volume de travail stable (\(String(format: "%.0f", abs(percentChange)))% de variation)\n"
            compText += "   Votre charge de travail reste cohérente entre les deux périodes.\n\n"
        }
        
        // Analyse de la fréquence des shifts
        if shiftsDiff != 0 {
            let sign = shiftsDiff > 0 ? "+" : ""
            let absShiftsDiff = abs(shiftsDiff)
            compText += "📅 Fréquence des shifts : \(sign)\(absShiftsDiff) shift\(absShiftsDiff > 1 ? "s" : "") (\(currentCount) vs \(comparisonCount))\n"
            
            // Analyse de la durée moyenne
            if abs(avgDiff) > 0.5 {
                let avgSign = avgDiff > 0 ? "+" : ""
                compText += "   Durée moyenne par shift : \(avgSign)\(formatHours(abs(avgDiff)))\n"
                
                if avgDiff > 0 {
                    compText += "   Vous travaillez des shifts plus longs mais moins fréquents.\n\n"
                } else {
                    compText += "   Vous travaillez des shifts plus courts mais plus fréquents.\n\n"
                }
            } else {
                compText += "   La durée moyenne des shifts reste similaire.\n\n"
            }
        } else if abs(avgDiff) > 0.5 {
            let avgSign = avgDiff > 0 ? "+" : ""
            compText += "⏱️  Durée moyenne par shift : \(avgSign)\(formatHours(abs(avgDiff)))\n"
            compText += "   Même nombre de shifts, mais durée \(avgDiff > 0 ? "allongée" : "réduite").\n\n"
        }
        
        // Analyse des activités
        compText += analyzeActivityChanges(comparisonShifts: comparisonShifts, currentTotal: currentTotal, comparisonTotal: comparisonTotal)
        
        return compText
    }
    
    private func analyzeActivityChanges(comparisonShifts: [Shift], currentTotal: Double, comparisonTotal: Double) -> String {
        var currentSegmentStats: [String: Double] = [:]
        var comparisonSegmentStats: [String: Double] = [:]
        
        for shift in filteredShifts where shift.segment != "Général" {
            currentSegmentStats[shift.segment, default: 0] += shift.duration / 3600
        }
        
        for shift in comparisonShifts where shift.segment != "Général" {
            comparisonSegmentStats[shift.segment, default: 0] += shift.duration / 3600
        }
        
        var analysisText = "🔄 Évolution des activités\n\n"
        
        let currentTop = currentSegmentStats.sorted { $0.value > $1.value }
        let comparisonTop = comparisonSegmentStats.sorted { $0.value > $1.value }
        
        // Changement d'activité principale
        if let current = currentTop.first, let previous = comparisonTop.first {
            if current.key != previous.key {
                analysisText += "• Activité principale : \(current.key) remplace \(previous.key)\n"
                let currentPct = (current.value / currentTotal * 100)
                let previousPct = (previous.value / comparisonTotal * 100)
                analysisText += "  \(current.key) représente maintenant \(String(format: "%.0f", currentPct))% de votre temps "
                analysisText += "(vs \(String(format: "%.0f", previousPct))% pour \(previous.key) précédemment).\n\n"
            }
        }
        
        // Activités en croissance et en baisse
        var growingActivities: [(name: String, growth: Double)] = []
        var decliningActivities: [(name: String, decline: Double)] = []
        
        for (segment, currentHours) in currentSegmentStats {
            let previousHours = comparisonSegmentStats[segment] ?? 0
            if previousHours > 0 {
                let change = ((currentHours - previousHours) / previousHours) * 100
                if change > 15 {
                    growingActivities.append((segment, change))
                } else if change < -15 {
                    decliningActivities.append((segment, change))
                }
            } else if currentHours > 2 {
                growingActivities.append((segment, 100))
            }
        }
        
        if !growingActivities.isEmpty {
            analysisText += "📈 Activités en forte hausse :\n"
            for activity in growingActivities.sorted(by: { $0.growth > $1.growth }).prefix(3) {
                if activity.growth >= 100 {
                    analysisText += "• \(activity.name) (nouvelle activité)\n"
                } else {
                    analysisText += "• \(activity.name) (+\(String(format: "%.0f", activity.growth))%)\n"
                }
            }
            analysisText += "\n"
        }
        
        if !decliningActivities.isEmpty {
            analysisText += "📉 Activités en baisse :\n"
            for activity in decliningActivities.sorted(by: { $0.decline < $1.decline }).prefix(3) {
                analysisText += "• \(activity.name) (\(String(format: "%.0f", activity.decline))%)\n"
            }
            analysisText += "\n"
        }
        
        if growingActivities.isEmpty && decliningActivities.isEmpty {
            analysisText += "• Distribution des activités globalement stable.\n"
            analysisText += "  Votre répartition du temps reste cohérente entre les périodes.\n\n"
        }
        
        return analysisText
    }
    
    private func getComparisonPeriodLabel(type: ComparisonType) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        
        let dates = calculateComparisonDates(calendar: calendar, type: type)
        
        switch selectedPeriod {
        case .month:
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: dates.start).capitalized
            
        case .quarter:
            let month = calendar.component(.month, from: dates.start)
            let quarter = ((month - 1) / 3) + 1
            let year = calendar.component(.year, from: dates.start)
            return "Q\(quarter) \(year)"
            
        case .year:
            dateFormatter.dateFormat = "yyyy"
            return dateFormatter.string(from: dates.start)
        }
    }
    
    private func getComparisonShifts(type: ComparisonType, allShifts: [Shift]) -> [Shift] {
        let calendar = Calendar.current
        let dates = calculateComparisonDates(calendar: calendar, type: type)
        
        return allShifts.filter { shift in
            shift.date >= dates.start && shift.date <= dates.end
        }
    }
    
    private func calculateComparisonDates(calendar: Calendar, type: ComparisonType) -> (start: Date, end: Date) {
        switch selectedPeriod {
        case .month:
            return calculateMonthComparison(calendar: calendar, type: type)
        case .quarter:
            return calculateQuarterComparison(calendar: calendar, type: type)
        case .year:
            return calculateYearComparison(calendar: calendar, type: type)
        }
    }
    
    private func calculateMonthComparison(calendar: Calendar, type: ComparisonType) -> (start: Date, end: Date) {
        // Obtenir le début et la fin du mois actuel
        let currentMonthStart = calendar.startOfMonth(for: selectedDate)
        let currentMonthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentMonthStart)!
        
        if type == .previousPeriod {
            // Mois précédent : décembre si on est en janvier, etc.
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
            let previousMonthEnd = calendar.date(byAdding: .day, value: -1, to: currentMonthStart)!
            return (previousMonthStart, previousMonthEnd)
        } else {
            // Même mois l'année précédente : janvier 2024 si on regarde janvier 2025
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentMonthStart)!
            let previousYearEnd = calendar.date(byAdding: .year, value: -1, to: currentMonthEnd)!
            return (previousYearStart, previousYearEnd)
        }
    }
    
    private func calculateQuarterComparison(calendar: Calendar, type: ComparisonType) -> (start: Date, end: Date) {
        // Obtenir le début et la fin du trimestre actuel
        let currentQuarterStart = calendar.startOfQuarter(for: selectedDate)
        let currentQuarterEnd = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: currentQuarterStart)!
        
        if type == .previousPeriod {
            // Trimestre précédent : T4 si on est en T1, etc.
            let previousQuarterStart = calendar.date(byAdding: .month, value: -3, to: currentQuarterStart)!
            let previousQuarterEnd = calendar.date(byAdding: .day, value: -1, to: currentQuarterStart)!
            return (previousQuarterStart, previousQuarterEnd)
        } else {
            // Même trimestre l'année précédente : T1 2024 si on regarde T1 2025
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentQuarterStart)!
            let previousYearEnd = calendar.date(byAdding: .year, value: -1, to: currentQuarterEnd)!
            return (previousYearStart, previousYearEnd)
        }
    }
    
    private func calculateYearComparison(calendar: Calendar, type: ComparisonType) -> (start: Date, end: Date) {
        // Obtenir le début et la fin de l'année actuelle
        let currentYearStart = calendar.startOfYear(for: selectedDate)
        let currentYearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: currentYearStart)!
        
        // Pour l'année, periode précédente = année précédente (même chose)
        let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentYearStart)!
        let previousYearEnd = calendar.date(byAdding: .year, value: -1, to: currentYearEnd)!
        
        return (previousYearStart, previousYearEnd)
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
    
    func startOfQuarter(for date: Date) -> Date {
        let month = component(.month, from: date)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1
        var components = dateComponents([.year], from: date)
        components.month = quarterStartMonth
        return self.date(from: components)!
    }
    
    func startOfYear(for date: Date) -> Date {
        let components = dateComponents([.year], from: date)
        return self.date(from: components)!
    }
}

#Preview {
    ContentView(sharedImagePath: .constant(nil))
        .modelContainer(for: WorkSchedule.self, inMemory: true)
}

