//
//  WorkJamAPIClient.swift
//  WorkScheduleApp
//
//  Client HTTP pour l'API WorkJam - récupération automatique des horaires
//

import Foundation

class WorkJamAPIClient {

    static let shared = WorkJamAPIClient()

    private let baseURL = "https://api.workjam.com"
    private let authEndpoint = "/auth/v3"
    private let verifyMFAEndpoint = "/auth/v3/verify-mfa"
    private let companyID = "COMPANY_ID_REMOVED"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Authentification

    func login(email: String, password: String) async throws -> WJAuthResponse {
        guard let url = URL(string: baseURL + authEndpoint) else {
            throw WJAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("WORKJAM", forHTTPHeaderField: "marketplace")

        let body: [String: Any] = [
            "username": email,
            "password": password,
            "isSharedDevice": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WJAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(WJAuthResponse.self, from: data)
            case 401:
                throw WJAPIError.invalidCredentials
            case 400...499:
                if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorDict["message"] as? String {
                    throw WJAPIError.serverError(message)
                }
                throw WJAPIError.unauthorized
            default:
                throw WJAPIError.serverError("Le serveur a retourné le statut \(httpResponse.statusCode)")
            }
        } catch let error as WJAPIError {
            throw error
        } catch {
            throw WJAPIError.networkError(error)
        }
    }

    // MARK: - Vérification MFA

    func verifyMFA(mfaToken: String, code: String) async throws -> WJMFAResponse {
        guard let url = URL(string: baseURL + verifyMFAEndpoint) else {
            throw WJAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("WORKJAM", forHTTPHeaderField: "marketplace")
        request.addValue("Bearer \(mfaToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["code": code, "trustDevice": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WJAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(WJMFAResponse.self, from: data)
            case 401:
                throw WJAPIError.invalidCredentials
            default:
                throw WJAPIError.serverError("Échec de la vérification MFA")
            }
        } catch let error as WJAPIError {
            throw error
        } catch {
            throw WJAPIError.networkError(error)
        }
    }

    // MARK: - Récupération des événements (shifts + congés)

    func fetchEvents(token: String, employeeID: String, startDate: Date, endDate: Date) async throws -> [WJEvent] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startStr = iso.string(from: startDate)
        let endStr = iso.string(from: endDate)

        let urlString = String(
            format: "https://api.workjam.com/api/v4/companies/%@/employees/%@/events?startDateTime=%@&endDateTime=%@&types=SHIFT,AVAILABILITY_TIME_OFF",
            companyID,
            employeeID,
            startStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? startStr,
            endStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endStr
        )

        guard let url = URL(string: urlString) else {
            throw WJAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("WORKJAM", forHTTPHeaderField: "marketplace")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WJAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                let events = try JSONDecoder().decode([WJEvent].self, from: data)
                return events.filter { $0.type == "SHIFT" || $0.type == "AVAILABILITY_TIME_OFF" }
            case 401:
                throw WJAPIError.tokenExpired
            case 403:
                throw WJAPIError.unauthorized
            default:
                throw WJAPIError.serverError("Impossible de récupérer les horaires")
            }
        } catch let error as DecodingError {
            throw WJAPIError.decodingError(error)
        } catch let error as WJAPIError {
            throw error
        } catch {
            throw WJAPIError.networkError(error)
        }
    }

    // MARK: - Vérification du token

    func isTokenValid(token: String, employeeID: String) async -> Bool {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        do {
            _ = try await fetchEvents(token: token, employeeID: employeeID, startDate: today, endDate: tomorrow)
            return true
        } catch {
            return false
        }
    }
}
