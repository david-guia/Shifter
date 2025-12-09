//
//  OCRService.swift
//  WorkScheduleApp
//
//  Service pour extraire du texte des images via Vision Framework
//

import Foundation
import Vision
import UIKit
import PDFKit

class OCRService {
    
    // MARK: - Cache de parsing
    
    /// Cache des résultats de parsing pour éviter de reparser le même texte
    /// Limite: 20 entrées maximum pour éviter une croissance infinie
    private var parseCache: [String: [(date: Date, startTime: Date, endTime: Date, segment: String)]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.shifter.ocr.cache", attributes: .concurrent)
    
    // MARK: - Regex statiques pré-compilées (optimisation performance)
    
    /// Regex pour détecter les dates au format WorkJam: "lundi 25 novembre"
    private static let workJamDateRegex: NSRegularExpression? = {
        let pattern = "(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)\\s+(\\d{1,2})\\s+(janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre)"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    /// Regex pour détecter les indicateurs temporels relatifs
    private static let relativeTimeRegex: NSRegularExpression? = {
        // Détecte: "hier", "Il y a X jour(s)", "Il y a X semaine(s)", "Il y a X mois", "Aujourd'hui"
        let pattern = "(hier|aujourd'hui|il y a (\\d+) jour[s]?|il y a (\\d+) semaine[s]?|il y a (\\d+) mois)"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    /// Regex pour horaires format AM/PM: "10:00 AM–11:30 AM"
    private static let timeRangeAMPMRegex: NSRegularExpression? = {
        let pattern = "(\\d{1,2}):(\\d{2})\\s*(AM|PM)\\s*[\\-–]\\s*(\\d{1,2}):(\\d{2})\\s*(AM|PM)"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    /// Regex pour horaires format 24h avec 'h': "9h-17h" ou "9:00-17:00"
    private static let timeRange24HRegex1: NSRegularExpression? = {
        let pattern = "(\\d{1,2})[h:](\\d{2})?\\s*[\\-\\u{2013}]\\s*(\\d{1,2})[h:](\\d{2})?"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()
    
    private static let timeRange24HRegex2: NSRegularExpression? = {
        let pattern = "(\\d{1,2}):(\\d{2})\\s*[\\-\\u{2013}]\\s*(\\d{1,2}):(\\d{2})"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()
    
    /// Regex pour détecter les segments/catégories de travail
    private static let segmentRegex: NSRegularExpression? = {
        // Détecte les segments WorkJam spécifiques + segments standards
        // Setup peut être avec ou sans numéro
        let pattern = "(?:Shift|Sales|Runner|Setup)(?:\\s+\\d+)?|PZ\\s+On\\s+Point|GB\\s+On\\s+Point|Cycle\\s+Counts|Connection|Roundtable|Onboarding|Visuals|Pause\\s+repas|Daily\\s+Download|Learn\\s+and\\s+Grow|Avenues|Break|Training|Meeting|Opening|Closing"
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    
    // MARK: - Erreurs
    
    /// Erreurs personnalisées avec contexte pour faciliter le debugging
    enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound(imageSize: CGSize)
        case invalidImage
        case parsingFailed(lineCount: Int, sampleText: String)
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Impossible de traiter l'image"
            case .noTextFound(let imageSize):
                return "Aucun texte détecté dans l'image (\(Int(imageSize.width))×\(Int(imageSize.height)) px)"
            case .invalidImage:
                return "Image invalide"
            case .parsingFailed(let lineCount, let sampleText):
                let preview = sampleText.prefix(100)
                return "Échec du parsing (\(lineCount) lignes). Aperçu: \(preview)..."
            }
        }
    }
    
    // MARK: - OCR (Reconnaissance de texte)
    
    /// Extrait le texte d'une image via Vision Framework
    /// Retourne le texte reconnu ou lance une erreur OCRError
    func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        let imageSize = image.size
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound(imageSize: imageSize))
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound(imageSize: imageSize))
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
    
    // MARK: - Conversion PDF vers image
    
    /// Convertit la première page d'un PDF en UIImage pour l'OCR
    /// Retourne une image haute résolution (300 DPI) pour améliorer la précision de l'OCR
    func convertPDFToImage(from url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            return nil
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3.0 // 300 DPI pour une meilleure qualité OCR
        let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            
            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
    
    // MARK: - Parsing du texte OCR
    
    /// Parse le texte OCR pour extraire les shifts avec toutes leurs informations
    /// Utilise un cache pour éviter de reparser le même texte plusieurs fois
    /// Retourne: [(date, startTime, endTime, segment)]
    func parseScheduleText(_ text: String) -> [(date: Date, startTime: Date, endTime: Date, segment: String)] {
        // Vérifier le cache en premier (optimisation)
        let cacheKey = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cacheQueue.sync {
            if let cached = parseCache[cacheKey] {
                return cached
            }
            
            // Si pas en cache, effectuer le parsing
            let shifts = performParsing(text)
            
            // Mettre en cache (limite: 20 entrées max)
            if parseCache.count >= 20 {
                // Supprimer la première entrée pour éviter une croissance infinie
                if let firstKey = parseCache.keys.first {
                    parseCache.removeValue(forKey: firstKey)
                }
            }
            parseCache[cacheKey] = shifts
            
            return shifts
        }
    }
    
    /// Effectue le parsing réel du texte OCR
    /// Analyse ligne par ligne pour détecter dates, horaires et segments
    private func performParsing(_ text: String) -> [(date: Date, startTime: Date, endTime: Date, segment: String)] {
        var shifts: [(date: Date, startTime: Date, endTime: Date, segment: String)] = []
        let lines = text.components(separatedBy: .newlines)
        
        #if DEBUG
        print("🔍 Parsing \(lines.count) lignes...")
        #endif
        
        // ÉTAPE 1: Scanner TOUT le texte pour trouver l'indicateur temporel AVANT de parser les dates
        var globalRelativeIndicator: (days: Int?, months: Int?)? = nil
        for line in lines {
            if let (days, months) = detectRelativeTime(in: line) {
                globalRelativeIndicator = (days: days, months: months)
                #if DEBUG
                if let d = days {
                    print("🕐 Indicateur temporel détecté (pré-scan): Il y a \(d) jour(s)")
                } else if let m = months {
                    print("🕐 Indicateur temporel détecté (pré-scan): Il y a \(m) mois")
                }
                #endif
                break // Prendre le premier trouvé
            }
        }
        
        // Variables de contexte pour le parsing ligne par ligne
        var currentDate: Date?
        var currentSegment = "Général"
        var isInSegmentsSection = false
        
        // Variables pour le nouveau format WorkJam
        var shiftMainDate: Date?
        var segmentTimeRanges: [(segment: String, start: Date, end: Date)] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Sauter les lignes d'indicateurs temporels (déjà traités)
            if detectRelativeTime(in: trimmedLine) != nil {
                continue
            }
            
            // Détection de la date principale (ex: "mercredi 26 novembre")
            // Utiliser l'indicateur global trouvé précédemment
            if let date = detectWorkJamDate(in: trimmedLine, relativeTimeIndicator: globalRelativeIndicator) {
                #if DEBUG
                print("📅 Date détectée: \(date) dans '\(trimmedLine)'")
                #endif
                // Si on avait des segments en attente, créer les shifts
                if let mainDate = shiftMainDate, !segmentTimeRanges.isEmpty {
                    for segmentTime in segmentTimeRanges {
                        shifts.append((
                            date: mainDate,
                            startTime: segmentTime.start,
                            endTime: segmentTime.end,
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
            
            // Détection de la section EMPLACEMENT (désactivée)
            if trimmedLine.uppercased().contains("EMPLACEMENT") {
                isInSegmentsSection = false
                continue
            }
            
            // Dans la section segments, parser segment + horaire sur la même ligne
            if isInSegmentsSection {
                // Chercher pattern: "Shift 1" suivi de "10:00 AM–11:30 AM"
                if let segment = detectSegment(in: trimmedLine) {
                    currentSegment = segment
                    
                    // Chercher l'horaire sur la même ligne ou ligne suivante
                    if let mainDate = shiftMainDate,
                       let (start, end) = detectTimeRangeAMPM(in: trimmedLine, referenceDate: mainDate) {
                        segmentTimeRanges.append((segment: segment, start: start, end: end))
                        currentSegment = "Général" // Reset
                        continue
                    }
                }
                
                // Si on a déjà un segment en cours, chercher l'horaire
                if currentSegment != "Général" {
                    if let mainDate = shiftMainDate,
                       let (start, end) = detectTimeRangeAMPM(in: trimmedLine, referenceDate: mainDate) {
                        segmentTimeRanges.append((segment: currentSegment, start: start, end: end))
                        currentSegment = "Général" // Reset
                        continue
                    }
                }
            }
            
            // Détection d'horaire format AM/PM (ex: "10:00 AM–11:30 AM")
            if let date = currentDate,
               let (start, end) = detectTimeRangeAMPM(in: trimmedLine, referenceDate: date) {
                #if DEBUG
                print("⏰ Horaire AM/PM détecté: \(start)-\(end) dans '\(trimmedLine)'")
                #endif
                shifts.append((date: date, startTime: start, endTime: end, segment: currentSegment))
            }
            // Détection d'horaire format 24h (ex: "09:00 - 17:00", "9h-17h")
            else if let date = currentDate,
               let (start, end) = detectTimeRange24H(in: trimmedLine, referenceDate: date) {
                #if DEBUG
                print("⏰ Horaire 24h détecté: \(start)-\(end) dans '\(trimmedLine)'")
                #endif
                shifts.append((date: date, startTime: start, endTime: end, segment: currentSegment))
            }
        }
        
        // Traiter les derniers segments en attente
        if let mainDate = shiftMainDate, !segmentTimeRanges.isEmpty {
            for segmentTime in segmentTimeRanges {
                shifts.append((
                    date: mainDate,
                    startTime: segmentTime.start,
                    endTime: segmentTime.end,
                    segment: segmentTime.segment
                ))
            }
        }
        
        #if DEBUG
        print("✅ Total shifts extraits: \(shifts.count)")
        #endif
        return shifts
    }
    
    private func detectWorkJamDate(in text: String, relativeTimeIndicator: (days: Int?, months: Int?)?) -> Date? {
        // Utiliser regex statique pré-compilée
        guard let regex = Self.workJamDateRegex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let matchedText = (text as NSString).substring(with: match.range)
        
        // Utiliser DateFormatterCache avec un formatter temporaire pour ce format spécifique
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE dd MMMM"
        
        if let date = formatter.date(from: matchedText) {
            let calendar = Calendar.current
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)
            let currentDate = Date()
            let currentMonth = calendar.component(.month, from: currentDate)
            let currentYear = calendar.component(.year, from: currentDate)
            
            // Si on a un indicateur temporel relatif (ex: "Il y a 6 jours" ou "Il y a 5 mois"), l'utiliser en priorité
            if let indicator = relativeTimeIndicator {
                #if DEBUG
                print("🔍 DEBUG: relativeTimeIndicator = days:\(indicator.days ?? -1) months:\(indicator.months ?? -1)")
                #endif
                
                // Cas 1: "Il y a X mois"
                if let monthsAgo = indicator.months {
                    #if DEBUG
                    print("🔍 DEBUG: Traitement mois - monthsAgo=\(monthsAgo)")
                    #endif
                    // Reculer de X mois depuis aujourd'hui pour obtenir l'année approximative
                    if let pastDate = calendar.date(byAdding: .month, value: -monthsAgo, to: currentDate) {
                        // Utiliser l'année de la date calculée, MAIS le mois et jour de la date parsée
                        var calculatedYear = calendar.component(.year, from: pastDate)
                        let calculatedMonth = calendar.component(.month, from: pastDate)
                        
                        #if DEBUG
                        print("🔍 DEBUG: Date calculée (-\(monthsAgo) mois) = \(calculatedYear)/\(calculatedMonth)")
                        print("🔍 DEBUG: Date parsée = mois:\(month) jour:\(day)")
                        #endif
                        
                        // Si le mois parsé est proche du mois calculé (±2 mois), c'est la même année
                        // Sinon, ajuster l'année
                        let monthDiff = abs(month - calculatedMonth)
                        #if DEBUG
                        print("🔍 DEBUG: Différence de mois = \(monthDiff)")
                        #endif
                        
                        if monthDiff > 6 {
                            // Si le mois parsé est beaucoup plus tard dans l'année, c'est l'année précédente
                            if month > calculatedMonth {
                                calculatedYear -= 1
                                #if DEBUG
                                print("🔍 DEBUG: Mois parsé > calculé et diff>6 → année -1 = \(calculatedYear)")
                                #endif
                            } else {
                                calculatedYear += 1
                                #if DEBUG
                                print("🔍 DEBUG: Mois parsé < calculé et diff>6 → année +1 = \(calculatedYear)")
                                #endif
                            }
                        } else {
                            #if DEBUG
                            print("🔍 DEBUG: Différence < 6 mois → même année = \(calculatedYear)")
                            #endif
                        }
                        
                        var components = DateComponents()
                        components.year = calculatedYear
                        components.month = month // Utiliser le mois PARSÉ (juin dans ton cas)
                        components.day = day
                        
                        #if DEBUG
                        print("🔍 DEBUG: DateComponents finale = \(calculatedYear)/\(month)/\(day)")
                        #endif
                        
                        if let finalDate = calendar.date(from: components) {
                            #if DEBUG
                            print("📅 Année corrigée via indicateur temporel (mois): \(calculatedYear)/\(month)/\(day) (Il y a \(monthsAgo) mois)")
                            #endif
                            return finalDate
                        }
                    }
                }
                // Cas 2: "Il y a X jours"
                else if let daysAgo = indicator.days {
                    // Calculer la date exacte en reculant de X jours depuis aujourd'hui
                    if let pastDate = calendar.date(byAdding: .day, value: -daysAgo, to: currentDate) {
                        let targetYear = calendar.component(.year, from: pastDate)
                        let targetMonth = calendar.component(.month, from: pastDate)
                        
                        var components = DateComponents()
                        components.year = targetYear
                        components.month = targetMonth
                        components.day = day
                        
                        if let finalDate = calendar.date(from: components) {
                            #if DEBUG
                            print("📅 Année corrigée via indicateur temporel (jours): \(targetYear) (Il y a \(daysAgo) jours)")
                            #endif
                            return finalDate
                        }
                    }
                }
            }
            
            // Sinon, utiliser la logique fiscale existante (fallback)
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
    
    /// Détecte les indicateurs temporels relatifs et retourne (jours, mois) dans le passé
    /// Exemples: "hier" → (1, nil), "Il y a 6 jours" → (6, nil), "Il y a 5 mois" → (nil, 5)
    private func detectRelativeTime(in text: String) -> (days: Int?, months: Int?)? {
        let lowercased = text.lowercased()
        
        // "aujourd'hui" ou "Aujourd'hui"
        if lowercased.contains("aujourd'hui") {
            return (days: 0, months: nil)
        }
        
        // "hier" ou "Hier"
        if lowercased.contains("hier") {
            return (days: 1, months: nil)
        }
        
        // "Il y a X jour(s)" ou "Il y a X mois" ou "Il y a X semaine(s)"
        if let regex = Self.relativeTimeRegex,
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {
            let matchedText = (lowercased as NSString).substring(with: match.range)
            
            // Extraire le nombre
            if let numberMatch = matchedText.range(of: "\\d+", options: .regularExpression) {
                let numberString = String(matchedText[numberMatch])
                if let number = Int(numberString) {
                    // Cas 1: mois
                    if matchedText.contains("mois") {
                        return (days: nil, months: number)
                    }
                    // Cas 2: semaines → convertir en jours
                    else if matchedText.contains("semaine") {
                        return (days: number * 7, months: nil)
                    }
                    // Cas 3: jours
                    else {
                        return (days: number, months: nil)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func detectDate(in text: String) -> Date? {
        // Utiliser la nouvelle méthode WorkJam (avec support des indicateurs temporels)
        if let date = detectWorkJamDate(in: text, relativeTimeIndicator: (days: nil, months: nil)) {
            return date
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        
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
    
    private func detectSegment(in text: String) -> String? {
        // Utiliser regex statique pré-compilée pour segments
        if let regex = Self.segmentRegex,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let detectedSegment = (text as NSString).substring(with: match.range)
            // Normaliser les espaces multiples et capitalisation
            let normalized = detectedSegment
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            // Normaliser "Shift X" avec majuscule
            if normalized.lowercased().hasPrefix("shift") {
                let components = normalized.components(separatedBy: .whitespaces)
                if components.count == 2, let number = Int(components[1]) {
                    return "Shift \(number)"
                }
            }
            
            return normalized
        }
        
        // Ne plus accepter n'importe quel texte comme segment
        // Si c'est une ligne connue sans horaire, on peut l'accepter
        let knownSegments = [
            "Setup", "Pause repas", "Daily Download", "Learn and Grow", "Avenues",
            "PZ On Point", "GB On Point", "Cycle Counts", "Connection",
            "Roundtable", "Onboarding", "Visuals",
            "Break", "Training", "Meeting", "Opening", "Closing"
        ]
        
        for known in knownSegments {
            if text.lowercased().contains(known.lowercased()) {
                return known
            }
        }
        
        // Détecter "Shift X", "Sales X", "Runner X", "Setup X" avec variations
        let patterns = [
            ("shift", "Shift"),
            ("sales", "Sales"),
            ("runner", "Runner"),
            ("setup", "Setup")
        ]
        
        for (keyword, prefix) in patterns {
            if text.lowercased().contains(keyword) {
                let pattern = "\(keyword)\\s+(\\d+)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   match.numberOfRanges > 1 {
                    let numberRange = match.range(at: 1)
                    if let number = Int((text as NSString).substring(with: numberRange)) {
                        return "\(prefix) \(number)"
                    }
                }
            }
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
    
    private func detectTimeRangeAMPM(in text: String, referenceDate: Date = Date()) -> (Date, Date)? {
        // Utiliser regex statique pré-compilée
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
        
        guard let startTime = calendar.date(bySettingHour: startHour24, minute: startMin, second: 0, of: referenceDate),
              let endTime = calendar.date(bySettingHour: endHour24, minute: endMin, second: 0, of: referenceDate) else {
            return nil
        }
        
        return (startTime, endTime)
    }
    
    private func detectTimeRange24H(in text: String, referenceDate: Date = Date()) -> (Date, Date)? {
        let calendar = Calendar.current
        
        // Essayer regex1 (format avec h: optionnel)
        if let regex = Self.timeRange24HRegex1,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                let startHour = Int((text as NSString).substring(with: match.range(at: 1))) ?? 0
                let startMin = match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound
                    ? Int((text as NSString).substring(with: match.range(at: 2))) ?? 0
                    : 0
                
                let endHour = Int((text as NSString).substring(with: match.range(at: 3))) ?? 0
                let endMin = match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound
                    ? Int((text as NSString).substring(with: match.range(at: 4))) ?? 0
                    : 0
                
                if let startTime = calendar.date(bySettingHour: startHour, minute: startMin, second: 0, of: referenceDate),
                   let endTime = calendar.date(bySettingHour: endHour, minute: endMin, second: 0, of: referenceDate) {
                    return (startTime, endTime)
                }
            }
        
        // Essayer regex2 (format strict HH:MM)
        if let regex = Self.timeRange24HRegex2,
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            
            let startHour = Int((text as NSString).substring(with: match.range(at: 1))) ?? 0
            let startMin = Int((text as NSString).substring(with: match.range(at: 2))) ?? 0
            
            let endHour = Int((text as NSString).substring(with: match.range(at: 3))) ?? 0
            let endMin = Int((text as NSString).substring(with: match.range(at: 4))) ?? 0
            
            if let startTime = calendar.date(bySettingHour: startHour, minute: startMin, second: 0, of: referenceDate),
               let endTime = calendar.date(bySettingHour: endHour, minute: endMin, second: 0, of: referenceDate) {
                return (startTime, endTime)
            }
        }
        
        return nil
    }
}
