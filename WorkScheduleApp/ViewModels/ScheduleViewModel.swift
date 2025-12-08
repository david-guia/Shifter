//
//  ScheduleViewModel.swift
//  WorkScheduleApp
//
//  ViewModel pour gérer la logique métier des horaires
//

import Foundation
import SwiftUI
import SwiftData
import WidgetKit

@MainActor
class ScheduleViewModel: ObservableObject {
    // MARK: - Propriétés publiées
    
    /// Liste de tous les schedules (en pratique, un seul schedule principal)
    @Published var schedules: [WorkSchedule] = []
    @Published var selectedSchedule: WorkSchedule?
    
    /// Indicateur de chargement pendant l'OCR
    @Published var isLoading = false
    
    /// Message d'erreur à afficher
    @Published var errorMessage: String?
    @Published var showError = false
    
    /// Indicateur pour afficher le toast de restauration automatique
    @Published var showRestoredMessage = false
    
    // MARK: - Propriétés privées
    
    /// Service OCR pour extraire le texte des images
    private let ocrService = OCRService()
    
    /// Contexte SwiftData pour les opérations de persistance
    private var modelContext: ModelContext?
    
    // MARK: - Backup automatique
    
    /// URL du fichier de backup JSON automatique dans Documents/
    /// Survit aux réinstallations via "Build & Run" Xcode (certificat dev)
    private var backupURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("shifter_auto_backup.json")
    }
    
    /// Initialise le contexte SwiftData et tente une restauration automatique si nécessaire
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchSchedules()
        
        // Si aucune donnée SwiftData trouvée, vérifier si un backup existe
        if schedules.isEmpty {
            Task {
                await attemptAutoRestore()
            }
        }
    }
    
    func fetchSchedules() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<WorkSchedule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            schedules = try context.fetch(descriptor)
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Import depuis image OCR
    
    /// Importe les horaires depuis une capture d'écran via OCR
    /// Processus: OCR → Parsing → Ajout à SwiftData → Backup automatique
    func importScheduleFromImage(_ image: UIImage) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Étape 1: OCR - Extraction du texte de l'image
            let recognizedText = try await ocrService.recognizeText(from: image)
            print("📄 Texte OCR détecté:\n\(recognizedText)\n")
            
            // Étape 2: Parsing - Analyse du texte pour extraire dates, horaires, segments
            let parsedShifts = ocrService.parseScheduleText(recognizedText)
            print("📊 Shifts parsés: \(parsedShifts.count)")
            
            // Validation: au moins un shift détecté
            if parsedShifts.isEmpty {
                throw NSError(domain: "ViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Aucun horaire détecté. Vérifiez que l'image contient des dates et horaires au format WorkJam."])
            }
            
            // Étape 3: Sauvegarde dans SwiftData
            guard let context = modelContext else {
                throw NSError(domain: "ViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Context non disponible"])
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            // Récupérer le schedule principal ou en créer un nouveau
            var schedule: WorkSchedule
            if let existingSchedule = schedules.first {
                schedule = existingSchedule
            } else {
                schedule = WorkSchedule(
                    title: "Mes horaires",
                    imageData: nil,
                    rawOCRText: nil
                )
                context.insert(schedule)
            }
            
            // Ajouter tous les shifts parsés au schedule (avec détection des doublons)
            var addedCount = 0
            var duplicateCount = 0
            
            for parsed in parsedShifts {
                // Vérifier si un shift identique existe déjà
                let isDuplicate = schedule.shifts.contains { existing in
                    Calendar.current.isDate(existing.date, inSameDayAs: parsed.date) &&
                    Calendar.current.isDate(existing.startTime, equalTo: parsed.startTime, toGranularity: .minute) &&
                    Calendar.current.isDate(existing.endTime, equalTo: parsed.endTime, toGranularity: .minute) &&
                    existing.location == parsed.location &&
                    existing.segment == parsed.segment
                }
                
                if !isDuplicate {
                    let shift = Shift(
                        date: parsed.date,
                        startTime: parsed.startTime,
                        endTime: parsed.endTime,
                        location: parsed.location,
                        segment: parsed.segment
                    )
                    shift.schedule = schedule
                    schedule.shifts.append(shift)
                    context.insert(shift)
                    addedCount += 1
                } else {
                    duplicateCount += 1
                }
            }
            
            // Log pour débug
            if duplicateCount > 0 {
                print("⚠️ \(duplicateCount) shift(s) en doublon ignoré(s)")
            }
            print("✅ \(addedCount) shift(s) ajouté(s)")
            
            try context.save()
            
            fetchSchedules()
            selectedSchedule = schedule
            
            // Afficher message d'alerte si doublons détectés
            if duplicateCount > 0 {
                errorMessage = "\(addedCount) shift(s) ajouté(s)\n⚠️ \(duplicateCount) doublon(s) ignoré(s)"
                showError = true
            }
            
            // Backup automatique après import
            Task {
                await saveAutoBackup()
            }
            
            // Rafraîchir les widgets
            WidgetCenter.shared.reloadAllTimelines()
            
            // 🆕 Synchroniser avec Apple Watch
            syncToWatch()
            
            isLoading = false
        } catch {
            isLoading = false
            handleError(error)
        }
    }
    
    // MARK: - Import depuis PDF
    
    /// Importe les horaires depuis un fichier PDF
    /// Processus: PDF → Image → OCR → Parsing → SwiftData → Backup
    func importScheduleFromPDF(_ url: URL) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Étape 1: Conversion PDF → Image
            guard let image = ocrService.convertPDFToImage(from: url) else {
                throw NSError(domain: "ViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Impossible de convertir le PDF en image. Vérifiez que le fichier est valide."])
            }
            
            // Étape 2-4: Utiliser le même processus que pour les images
            await importScheduleFromImage(image)
            
        } catch {
            isLoading = false
            handleError(error)
        }
    }
    
    func deleteSchedule(_ schedule: WorkSchedule) {
        guard let context = modelContext else { return }
        
        context.delete(schedule)
        
        do {
            try context.save()
            fetchSchedules()
        } catch {
            handleError(error)
        }
    }
    
    func addManualShift(to schedule: WorkSchedule, date: Date, startTime: Date, endTime: Date, location: String, segment: String = "Général", notes: String = "") {
        guard let context = modelContext else { return }
        
        let shift = Shift(
            date: date,
            startTime: startTime,
            endTime: endTime,
            location: location,
            segment: segment,
            notes: notes
        )
        shift.schedule = schedule
        schedule.shifts.append(shift)
        
        context.insert(shift)
        
        do {
            try context.save()
            fetchSchedules()
            Task {
                await saveAutoBackup()
            }
        } catch {
            handleError(error)
        }
    }
    
    func updateShift(_ shift: Shift, date: Date, startTime: Date, endTime: Date, location: String, segment: String, notes: String) {
        guard let context = modelContext else { return }
        
        shift.date = date
        shift.startTime = startTime
        shift.endTime = endTime
        shift.location = location
        shift.segment = segment
        shift.notes = notes
        
        do {
            try context.save()
            fetchSchedules()
            Task {
                await saveAutoBackup()
            }
        } catch {
            handleError(error)
        }
    }
    
    func deleteShift(_ shift: Shift) {
        guard let context = modelContext else { return }
        
        context.delete(shift)
        
        do {
            try context.save()
            fetchSchedules()
            Task {
                await saveAutoBackup()
            }
            
            // Rafraîchir les widgets
            WidgetCenter.shared.reloadAllTimelines()
            
            // 🆕 Synchroniser avec Apple Watch
            syncToWatch()
        } catch {
            handleError(error)
        }
    }
    
    func deleteAllShifts() {
        guard let context = modelContext else { return }
        guard let schedule = schedules.first else { return }
        
        // Supprimer tous les shifts
        for shift in schedule.shifts {
            context.delete(shift)
        }
        
        do {
            try context.save()
            fetchSchedules()
            Task {
                await saveAutoBackup()
            }
            
            // Rafraîchir les widgets
            WidgetCenter.shared.reloadAllTimelines()
            
            // 🆕 Synchroniser avec Apple Watch
            syncToWatch()
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        // Mapping des erreurs OCR vers messages français spécifiques
        if let ocrError = error as? OCRService.OCRError {
            switch ocrError {
            case .imageProcessingFailed:
                errorMessage = "Impossible de traiter l'image. Essayez avec une capture d'écran plus claire."
            case .noTextFound(let imageSize):
                errorMessage = "Aucun texte détecté dans l'image (\(Int(imageSize.width))×\(Int(imageSize.height)) px). Vérifiez que la capture contient des horaires."
            case .invalidImage:
                errorMessage = "L'image est invalide ou corrompue. Sélectionnez une autre image."
            case .parsingFailed(let lineCount, let sampleText):
                let preview = sampleText.prefix(50)
                errorMessage = "Échec du parsing (\(lineCount) lignes détectées). Aperçu: \(preview)..."
            }
        } else {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        
        showError = true
    }
    
    // Statistiques
    var shiftsGroupedByDate: [Date: [Shift]] {
        guard let schedule = selectedSchedule else { return [:] }
        return Dictionary(grouping: schedule.shifts) { shift in
            Calendar.current.startOfDay(for: shift.date)
        }
    }
    
    // MARK: - Export/Import JSON
    
    // MARK: - Backup & Restore automatiques
    
    /// Sauvegarde automatique des données en JSON dans Documents/
    /// Appelé après chaque modification (import, ajout, suppression, etc.)
    private func saveAutoBackup() async {
        guard let jsonString = exportToJSON() else {
            print("⚠️ Impossible de créer le backup")
            return
        }
        
        do {
            try jsonString.write(to: backupURL, atomically: true, encoding: .utf8)
            print("✅ Backup automatique sauvegardé: \(backupURL.path)")
        } catch {
            print("❌ Erreur sauvegarde backup: \(error.localizedDescription)")
        }
    }
    
    /// Tente de restaurer les données depuis le backup automatique
    /// Appelé au lancement si aucune donnée SwiftData n'existe
    private func attemptAutoRestore() async {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            print("📁 Aucun backup trouvé")
            return
        }
        
        do {
            let jsonString = try String(contentsOf: backupURL, encoding: .utf8)
            print("🔄 Restauration du backup...")
            
            await importFromJSON(jsonString)
            
            // Afficher le message de restauration
            await MainActor.run {
                showRestoredMessage = true
                // Masquer après 3 secondes
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showRestoredMessage = false
                }
            }
        } catch {
            print("❌ Erreur restauration backup: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Export/Import JSON manuel
    
    func exportToJSON() -> String? {
        guard let schedule = schedules.first else { return nil }
        
        let exportData = ExportData(
            exportDate: Date(),
            shifts: schedule.shifts.map { shift in
                ShiftExport(
                    date: shift.date,
                    startTime: shift.startTime,
                    endTime: shift.endTime,
                    location: shift.location,
                    segment: shift.segment,
                    notes: shift.notes
                )
            }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        guard let jsonData = try? encoder.encode(exportData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    func exportToZIP() -> URL? {
        guard let jsonString = exportToJSON() else { return nil }
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "shifts_export_\(timestamp)"
        
        // Créer un répertoire temporaire
        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("\(filename).zip")
        let jsonURL = tempDir.appendingPathComponent("\(filename).json")
        
        do {
            // Écrire le JSON dans un fichier temporaire
            try jsonData.write(to: jsonURL)
            
            // Créer l'archive ZIP en utilisant l'API native
            let coordinator = NSFileCoordinator()
            var error: NSError?
            
            coordinator.coordinate(readingItemAt: jsonURL, options: .forUploading, error: &error) { zipURLFromCoordinator in
                do {
                    // Supprimer le ZIP existant si présent
                    if FileManager.default.fileExists(atPath: zipURL.path) {
                        try FileManager.default.removeItem(at: zipURL)
                    }
                    
                    // Copier le fichier zippé
                    try FileManager.default.copyItem(at: zipURLFromCoordinator, to: zipURL)
                } catch {
                    print("Erreur lors de la création du ZIP: \(error)")
                }
            }
            
            if let error = error {
                print("Erreur coordination: \(error)")
                return nil
            }
            
            // Nettoyer le fichier JSON temporaire
            try? FileManager.default.removeItem(at: jsonURL)
            
            return zipURL
        } catch {
            print("Erreur lors de l'export ZIP: \(error)")
            return nil
        }
    }
    
    func importFromJSON(_ jsonString: String) async {
        guard let context = modelContext else { return }
        
        isLoading = true
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "Format JSON invalide"])
            }
            
            let exportData = try decoder.decode(ExportData.self, from: jsonData)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let schedule = WorkSchedule(
                title: "Horaires importés du \(dateFormatter.string(from: exportData.exportDate))",
                imageData: nil,
                rawOCRText: nil
            )
            
            for shiftData in exportData.shifts {
                let shift = Shift(
                    date: shiftData.date,
                    startTime: shiftData.startTime,
                    endTime: shiftData.endTime,
                    location: shiftData.location,
                    segment: shiftData.segment,
                    notes: shiftData.notes,
                    isConfirmed: true
                )
                shift.schedule = schedule
                schedule.shifts.append(shift)
                context.insert(shift)
            }
            
            context.insert(schedule)
            try context.save()
            
            fetchSchedules()
            isLoading = false
        } catch {
            isLoading = false
            handleError(error)
        }
    }
    
    // MARK: - Apple Watch Sync
    
    /// Synchronise les statistiques Top 3 avec l'Apple Watch
    private func syncToWatch() {
        guard let schedule = schedules.first else {
            print("⚠️ Aucun schedule à synchroniser")
            return
        }
        
        // Récupérer tous les shifts
        let allShifts = schedule.shifts
        
        // Envoyer via WatchConnectivity
        WatchConnectivityManager.shared.syncTop3FromShifts(allShifts)
    }
}

// MARK: - Export Models

struct ExportData: Codable {
    let exportDate: Date
    let shifts: [ShiftExport]
}

struct ShiftExport: Codable {
    let date: Date
    let startTime: Date
    let endTime: Date
    let location: String
    let segment: String
    let notes: String
}
