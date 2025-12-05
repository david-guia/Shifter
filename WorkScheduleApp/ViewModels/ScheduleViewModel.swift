//
//  ScheduleViewModel.swift
//  WorkScheduleApp
//
//  ViewModel pour gérer la logique métier des horaires
//

import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var schedules: [WorkSchedule] = []
    @Published var selectedSchedule: WorkSchedule?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var filterLocation: String?
    
    private let ocrService = OCRService()
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchSchedules()
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
    
    func importScheduleFromImage(_ image: UIImage) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Étape 1: OCR
            let recognizedText = try await ocrService.recognizeText(from: image)
            print("📄 Texte OCR détecté:\n\(recognizedText)\n")
            
            // Étape 2: Parsing
            let parsedShifts = ocrService.parseScheduleText(recognizedText)
            print("📊 Shifts parsés: \(parsedShifts.count)")
            
            // Si aucun shift détecté, afficher une erreur claire
            if parsedShifts.isEmpty {
                throw NSError(domain: "ViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Aucun horaire détecté. Vérifiez que l'image contient des dates et horaires au format WorkJam."])
            }
            
            // Étape 3: Ajouter à un schedule existant ou en créer un nouveau
            guard let context = modelContext else {
                throw NSError(domain: "ViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Context non disponible"])
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            // Récupérer ou créer le schedule principal
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
            
            // Ajouter les nouveaux shifts au schedule existant
            for parsed in parsedShifts {
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
            }
            
            try context.save()
            
            fetchSchedules()
            selectedSchedule = schedule
            
            isLoading = false
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
        } catch {
            handleError(error)
        }
    }
    
    func toggleShiftConfirmation(_ shift: Shift) {
        guard let context = modelContext else { return }
        
        shift.isConfirmed.toggle()
        
        do {
            try context.save()
            fetchSchedules()
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
            case .noTextFound:
                errorMessage = "Aucun texte détecté dans l'image. Vérifiez que la capture contient des horaires."
            case .invalidImage:
                errorMessage = "L'image est invalide ou corrompue. Sélectionnez une autre image."
            }
        } else {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        
        showError = true
    }
    
    // Filtrage et statistiques
    var filteredShifts: [Shift] {
        guard let schedule = selectedSchedule else { return [] }
        
        if let location = filterLocation {
            return schedule.shifts.filter { $0.location == location }
        }
        return schedule.shifts
    }
    
    var totalHoursForFiltered: Double {
        filteredShifts.reduce(0) { $0 + $1.duration / 3600 }
    }
    
    var shiftsGroupedByDate: [Date: [Shift]] {
        Dictionary(grouping: filteredShifts) { shift in
            Calendar.current.startOfDay(for: shift.date)
        }
    }
    
    // MARK: - Export/Import JSON
    
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
