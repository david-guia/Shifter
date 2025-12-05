//
//  OCRService.swift
//  WorkScheduleApp
//
//  Service pour extraire du texte des images via Vision Framework
//

import Foundation
import Vision
import UIKit

class OCRService {
    
    // MARK: - Regex statiques pré-compilées (optimisation performance)
    
    private static let workJamDateRegex: NSRegularExpression? = {
        let pattern = "(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\\s+(\\d{1,2})\\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    private static let timeRangeAMPMRegex: NSRegularExpression? = {
        let pattern = "(\\d{1,2}):(\\d{2})\\s*(AM|PM)\\s*[\\-–]\\s*(\\d{1,2}):(\\d{2})\\s*(AM|PM)"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    private static let timeRange24HRegex1: NSRegularExpression? = {
        let pattern = "(\\d{1,2})[h:](\\d{2})?\\s*[\\-\\u{2013}]\\s*(\\d{1,2})[h:](\\d{2})?"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()
    
    private static let timeRange24HRegex2: NSRegularExpression? = {
        let pattern = "(\\d{1,2}):(\\d{2})\\s*[\\-\\u{2013}]\\s*(\\d{1,2}):(\\d{2})"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()
    
    private static let segmentRegex: NSRegularExpression? = {
        let pattern = "Sales \\d+|PZ On Point|Pause repas|Learn and Grow|Runner \\d+|Break|Training|Meeting|Opening|Closing|Daily Download|Setup"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Impossible de traiter l'image"
            case .noTextFound:
                return "Aucun texte détecté dans l'image"
            case .invalidImage:
                return "Image invalide"
            }
        }
    }
    
    /// Extrait le texte d'une image
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }
            
            // Configuration optimale pour l'OCR
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr-FR", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.imageProcessingFailed)
            }
        }
    }
    
    /// Parse le texte OCR pour extraire les shifts avec segments (catégories)
    func parseScheduleText(_ text: String) -> [(date: Date, startTime: Date, endTime: Date, location: String, segment: String)] {
        var shifts: [(date: Date, startTime: Date, endTime: Date, location: String, segment: String)] = []
        let lines = text.components(separatedBy: .newlines)
        
        print("🔍 Parsing \(lines.count) lignes...")
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        
        var currentDate: Date?
        var currentLocation = "Non spécifié"
        var currentSegment = "Général"
        var isInSegmentsSection = false
        
        // Variables pour le nouveau format WorkJam
        var shiftMainDate: Date?
        var segmentTimeRanges: [(segment: String, start: Date, end: Date)] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Détection de la date principale (ex: "mercredi 26 novembre")
            if let date = detectWorkJamDate(in: trimmedLine, using: dateFormatter) {
                print("📅 Date détectée: \(date) dans '\(trimmedLine)'")
                // Si on avait des segments en attente, créer les shifts
                if let mainDate = shiftMainDate, !segmentTimeRanges.isEmpty {
                    for segmentTime in segmentTimeRanges {
                        shifts.append((
                            date: mainDate,
                            startTime: segmentTime.start,
                            endTime: segmentTime.end,
                            location: currentLocation,
                            segment: segmentTime.segment
                        ))
                    }
                    segmentTimeRanges.removeAll()
                }
                
                shiftMainDate = date
                currentDate = date
                continue
            }
            
            // Détection de la section SEGMENTS
            if trimmedLine.uppercased().contains("SEGMENT") {
                isInSegmentsSection = true
                continue
            }
            
            // Détection de la section EMPLACEMENT
            if trimmedLine.uppercased().contains("EMPLACEMENT") {
                isInSegmentsSection = false
                continue
            }
            
            // Détection de lieu
            if let location = detectLocation(in: trimmedLine) {
                currentLocation = location
                continue
            }
            
            // Dans la section segments, parser segment + horaire sur la même ligne
            if isInSegmentsSection {
                // Chercher pattern: "Sales 1" suivi de "10:00 AM–11:30 AM"
                if let segment = detectSegment(in: trimmedLine) {
                    currentSegment = segment
                    
                    // Chercher l'horaire sur la même ligne ou ligne suivante
                    if let (start, end) = detectTimeRangeAMPM(in: trimmedLine) {
                        segmentTimeRanges.append((segment: segment, start: start, end: end))
                        currentSegment = "Général" // Reset
                        continue
                    }
                }
                
                // Si on a déjà un segment en cours, chercher l'horaire
                if currentSegment != "Général" {
                    if let (start, end) = detectTimeRangeAMPM(in: trimmedLine) {
                        segmentTimeRanges.append((segment: currentSegment, start: start, end: end))
                        currentSegment = "Général" // Reset
                        continue
                    }
                }
            }
            
            // Détection d'horaire format AM/PM (ex: "10:00 AM–11:30 AM")
            if let (start, end) = detectTimeRangeAMPM(in: trimmedLine),
               let date = currentDate {
                print("⏰ Horaire AM/PM détecté: \(start)-\(end) dans '\(trimmedLine)'")
                shifts.append((date: date, startTime: start, endTime: end, location: currentLocation, segment: currentSegment))
            }
            // Détection d'horaire format 24h (ex: "09:00 - 17:00", "9h-17h")
            else if let (start, end) = detectTimeRange24H(in: trimmedLine),
               let date = currentDate {
                print("⏰ Horaire 24h détecté: \(start)-\(end) dans '\(trimmedLine)'")
                shifts.append((date: date, startTime: start, endTime: end, location: currentLocation, segment: currentSegment))
            }
        }
        
        // Traiter les derniers segments en attente
        if let mainDate = shiftMainDate, !segmentTimeRanges.isEmpty {
            for segmentTime in segmentTimeRanges {
                shifts.append((
                    date: mainDate,
                    startTime: segmentTime.start,
                    endTime: segmentTime.end,
                    location: currentLocation,
                    segment: segmentTime.segment
                ))
            }
        }
        
        print("✅ Total shifts extraits: \(shifts.count)")
        return shifts
    }
    
    private func detectWorkJamDate(in text: String, using formatter: DateFormatter) -> Date? {
        // Utiliser regex statique pré-compilée
        guard let regex = Self.workJamDateRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let matchedText = (text as NSString).substring(with: match.range)
        
        // Parser avec l'année courante
        formatter.dateFormat = "EEEE dd MMMM"
        if let date = formatter.date(from: matchedText) {
            // Déterminer l'année correcte en fonction du trimestre fiscal
            let calendar = Calendar.current
            let month = calendar.component(.month, from: date)
            let currentDate = Date()
            let currentMonth = calendar.component(.month, from: currentDate)
            let currentYear = calendar.component(.year, from: currentDate)
            
            // Déterminer l'année fiscale appropriée
            var targetYear = currentYear
            
            // Si le mois détecté est Oct/Nov/Dec (Q1 fiscal)
            // et qu'on est actuellement en Jan-Sep, c'est l'année précédente
            if month >= 10 && currentMonth < 10 {
                targetYear = currentYear - 1
            }
            // Si le mois détecté est Jan-Sep
            // et qu'on est actuellement en Oct-Dec, c'est l'année suivante
            else if month < 10 && currentMonth >= 10 {
                targetYear = currentYear + 1
            }
            
            var components = calendar.dateComponents([.day, .month], from: date)
            components.year = targetYear
            return calendar.date(from: components)
        }
        
        return nil
    }
    
    private func detectSegment(in text: String) -> String? {
        // Utiliser regex statique pr\u00e9-compil\u00e9e pour segments
        if let regex = Self.segmentRegex,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            return (text as NSString).substring(with: match.range)
        }
        
        // Si c'est une ligne qui ne contient pas d'horaire mais du texte, c'est probablement un segment
        if !text.contains("AM") && !text.contains("PM") && !text.contains(":") && text.count > 3 {
            // Nettoyer le texte des caractères spéciaux
            let cleaned = text.trimmingCharacters(in: CharacterSet.letters.inverted)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        
        return nil
    }
    
    private func detectDate(in text: String, using formatter: DateFormatter) -> Date? {
        // Utiliser la nouvelle méthode WorkJam
        if let date = detectWorkJamDate(in: text, using: formatter) {
            return date
        }
        
        // Format français: "Lundi 25 Novembre"
        formatter.dateFormat = "EEEE dd MMMM"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // Format court: "25/11/2025"
        formatter.dateFormat = "dd/MM/yyyy"
        if let date = formatter.date(from: text) {
            return date
        }
        
        // Format avec abréviation: "25 Nov"
        formatter.dateFormat = "dd MMM"
        if let date = formatter.date(from: text) {
            return date
        }
        
        return nil
    }
    
    private func detectLocation(in text: String) -> String? {
        let locationKeywords = ["site", "magasin", "boutique", "bureau", "entrepôt", "store", "location"]
        let lowercased = text.lowercased()
        
        for keyword in locationKeywords {
            if lowercased.contains(keyword) {
                return text
            }
        }
        
        return nil
    }
    
    private func detectTimeRangeAMPM(in text: String) -> (Date, Date)? {
        // Utiliser regex statique pr\u00e9-compil\u00e9e
        guard let regex = Self.timeRangeAMPMRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let startHour = Int((text as NSString).substring(with: match.range(at: 1))) ?? 0
        let startMin = Int((text as NSString).substring(with: match.range(at: 2))) ?? 0
        let startPeriod = (text as NSString).substring(with: match.range(at: 3)).uppercased()
        
        let endHour = Int((text as NSString).substring(with: match.range(at: 4))) ?? 0
        let endMin = Int((text as NSString).substring(with: match.range(at: 5))) ?? 0
        let endPeriod = (text as NSString).substring(with: match.range(at: 6)).uppercased()
        
        // Conversion AM/PM vers 24h
        var startHour24 = startHour
        if startPeriod == "PM" && startHour != 12 {
            startHour24 += 12
        } else if startPeriod == "AM" && startHour == 12 {
            startHour24 = 0
        }
        
        var endHour24 = endHour
        if endPeriod == "PM" && endHour != 12 {
            endHour24 += 12
        } else if endPeriod == "AM" && endHour == 12 {
            endHour24 = 0
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        guard let startTime = calendar.date(bySettingHour: startHour24, minute: startMin, second: 0, of: today),
              let endTime = calendar.date(bySettingHour: endHour24, minute: endMin, second: 0, of: today) else {
            return nil
        }
        
        return (startTime, endTime)
    }
    
    private func detectTimeRange24H(in text: String) -> (Date, Date)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Essayer regex1 (format avec h: optionnel)
        if let regex = Self.timeRange24HRegex1,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                let startHour = (text as NSString).substring(with: match.range(at: 1))
                let startMin = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound
                    ? (text as NSString).substring(with: match.range(at: 2))
                    : "00"
                
                let endHour = (text as NSString).substring(with: match.range(at: 3))
                let endMin = match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound
                    ? (text as NSString).substring(with: match.range(at: 4))
                    : "00"
                
                let startString = "\(startHour):\(startMin)"
                let endString = "\(endHour):\(endMin)"
                
                if let startTime = formatter.date(from: startString),
                   let endTime = formatter.date(from: endString) {
                    return (startTime, endTime)
                }
            }
        
        // Essayer regex2 (format strict HH:MM)
        if let regex = Self.timeRange24HRegex2,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            
            let startHour = (text as NSString).substring(with: match.range(at: 1))
            let startMin = (text as NSString).substring(with: match.range(at: 2))
            
            let endHour = (text as NSString).substring(with: match.range(at: 3))
            let endMin = (text as NSString).substring(with: match.range(at: 4))
            
            let startString = "\(startHour):\(startMin)"
            let endString = "\(endHour):\(endMin)"
            
            if let startTime = formatter.date(from: startString),
               let endTime = formatter.date(from: endString) {
                return (startTime, endTime)
            }
        }
        
        return nil
    }
}
