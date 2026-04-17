//
//  WorkJamAuthViewModel.swift
//  WorkScheduleApp
//
//  ViewModel gérant l'authentification WorkJam et le déclenchement de l'import
//

import Foundation
import SwiftData

@MainActor
class WorkJamAuthViewModel: ObservableObject {

    // MARK: - État de l'interface

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var mfaCode: String = ""

    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var needsMFA: Bool = false
    @Published var errorMessage: String?
    @Published var saveCredentials: Bool = false

    @Published var importedCount: Int = 0
    @Published var showImportSuccess: Bool = false
    @Published var isImporting: Bool = false

    // MARK: - Propriétés privées

    private var mfaToken: String?
    private let api = WorkJamAPIClient.shared
    private let keychain = WorkJamKeychain.shared

    // MARK: - Initialisation

    init() {
        checkExistingSession()
        loadSavedCredentials()
    }

    // MARK: - Session existante

    func checkExistingSession() {
        isAuthenticated = keychain.isLoggedIn()
    }

    private func loadSavedCredentials() {
        if let savedEmail = keychain.retrieveEmail() {
            email = savedEmail
            saveCredentials = true
        }
        if let savedPassword = keychain.retrievePassword() {
            password = savedPassword
        }
    }

    // MARK: - Connexion

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Veuillez saisir votre email et votre mot de passe."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.login(email: email, password: password)

            if response.requiresMFA == true,
               let token = response.mfaToken ?? response.sessionId {
                mfaToken = token
                needsMFA = true
                isLoading = false
                return
            }

            guard let token = response.bearerToken, let empID = response.empID else {
                errorMessage = "Réponse inattendue du serveur."
                isLoading = false
                return
            }

            _ = keychain.saveToken(token)
            _ = keychain.saveEmployeeID(empID)

            if saveCredentials {
                _ = keychain.saveEmail(email)
                _ = keychain.savePassword(password)
            }

            isAuthenticated = true

        } catch let error as WJAPIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Vérification MFA

    func verifyMFA() async {
        guard let mfaToken, !mfaCode.isEmpty else {
            errorMessage = "Veuillez saisir le code de vérification."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.verifyMFA(mfaToken: mfaToken, code: mfaCode)

            guard let token = response.bearerToken, let empID = response.empID else {
                errorMessage = "Réponse MFA inattendue."
                isLoading = false
                return
            }

            _ = keychain.saveToken(token)
            _ = keychain.saveEmployeeID(empID)

            if saveCredentials {
                _ = keychain.saveEmail(email)
                _ = keychain.savePassword(password)
            }

            needsMFA = false
            isAuthenticated = true

        } catch let error as WJAPIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Import des horaires

    /// Récupère les shifts WorkJam sur les 28 prochains jours et les insère dans Shifter
    func importShifts(context: ModelContext) async {
        guard let token = keychain.retrieveToken(),
              let empID = keychain.retrieveEmployeeID() else {
            errorMessage = "Vous n'êtes pas connecté."
            return
        }

        isImporting = true
        errorMessage = nil

        let today = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 28, to: today) ?? today

        do {
            let events = try await api.fetchEvents(
                token: token,
                employeeID: empID,
                startDate: today,
                endDate: endDate
            )

            let shifts = WorkJamImportService.convertEvents(events)
            let count = WorkJamImportService.insertShifts(shifts, into: context)

            importedCount = count
            showImportSuccess = true

        } catch WJAPIError.tokenExpired {
            // Tenter une reconnexion automatique
            if !email.isEmpty, !password.isEmpty {
                await login()
                if isAuthenticated {
                    await importShifts(context: context)
                    return
                }
            }
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            isAuthenticated = false

        } catch let error as WJAPIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    // MARK: - Déconnexion

    func logout() {
        keychain.logout()
        isAuthenticated = false
        email = ""
        password = ""
        mfaCode = ""
        mfaToken = nil
        needsMFA = false
    }
}
