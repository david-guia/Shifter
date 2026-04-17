//
//  WorkJamModels.swift
//  WorkScheduleApp
//
//  Modèles de données pour l'API WorkJam
//

import Foundation

// MARK: - Réponse d'authentification

struct WJAuthResponse: Codable {
    let xToken: String?
    let token: String?
    let accessToken: String?
    let id: String?
    let employeeId: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let requiresMFA: Bool?
    let mfaToken: String?
    let sessionId: String?

    var bearerToken: String? {
        xToken ?? token ?? accessToken
    }

    var empID: String? {
        id ?? employeeId
    }
}

// MARK: - Réponse MFA

struct WJMFAResponse: Codable {
    let xToken: String?
    let token: String?
    let accessToken: String?
    let id: String?
    let employeeId: String?

    var bearerToken: String? {
        xToken ?? token ?? accessToken
    }

    var empID: String? {
        id ?? employeeId
    }
}

// MARK: - Événement WorkJam (shifts + congés)

struct WJEvent: Codable {
    let id: String
    let type: String          // "SHIFT", "AVAILABILITY_TIME_OFF", etc.
    let startDateTime: String
    let endDateTime: String
    let title: String?
    let note: String?
    let location: WJEventLocation?
}

// MARK: - Localisation d'événement

struct WJEventLocation: Codable {
    let id: String
    let name: String
    let type: String?
    let externalCode: String?
    let timeZoneId: String?
}

// MARK: - Détail d'un shift (zones / segments)

struct WJShiftDetail: Codable {
    let id: String
    let position: WJPosition?
    let segments: [WJShiftSegment]

    /// Nom de la zone principale : premier segment non-pause, sinon position racine
    var primaryZone: String? {
        segments.first(where: { !$0.isBreak })?.position?.name
            ?? position?.name
    }
}

struct WJPosition: Codable {
    let id: String
    let name: String
}

struct WJShiftSegment: Codable {
    let type: String          // "SHIFT", "BREAK_MEAL", "BREAK_REST"
    let startDateTime: String
    let endDateTime: String
    let position: WJPosition?

    var isBreak: Bool { type.contains("BREAK") }
}

// MARK: - Erreurs API

enum WJAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case tokenExpired
    case invalidCredentials
    case serverError(String)
    case decodingError(Error)
    case missingCompanyID

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .networkError(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide du serveur"
        case .unauthorized:
            return "Non autorisé. Vérifiez vos identifiants."
        case .tokenExpired:
            return "Session expirée. Veuillez vous reconnecter."
        case .invalidCredentials:
            return "Email ou mot de passe incorrect"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Impossible de lire la réponse du serveur"
        case .missingCompanyID:
            return "Identifiant entreprise manquant. Veuillez le saisir dans les paramètres de connexion."
        }
    }
}
