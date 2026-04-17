//
//  WorkJamAuthViewModel.swift
//  WorkScheduleApp
//
//  ViewModel gérant l'authentification SSO WorkJam via ASWebAuthenticationSession
//  et le déclenchement de l'import automatique des horaires
//

import Foundation
import SwiftData
import AuthenticationServices

@MainActor
class WorkJamAuthViewModel: NSObject, ObservableObject {

    // MARK: - État de l'interface

    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    @Published var importedCount: Int = 0
    @Published var showImportSuccess: Bool = false
    @Published var isImporting: Bool = false

    // MARK: - Privé

    private let api = WorkJamAPIClient.shared
    private let keychain = WorkJamKeychain.shared
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Initialisation

    override init() {
        super.init()
        checkExistingSession()
        if let savedEmail = keychain.retrieveEmail() {
            email = savedEmail
        }
    }

    func checkExistingSession() {
        isAuthenticated = keychain.isLoggedIn()
    }

    // MARK: - Connexion SSO

    var canStartAuth: Bool {
        !email.isEmpty && email.contains("@") && !isLoading
    }

    func startSSO() async {
        guard canStartAuth else {
            errorMessage = "Veuillez saisir votre email professionnel."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = "Préparation de l'authentification…"

        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorMessage = "Email invalide."
            isLoading = false
            return
        }

        var components = URLComponents(string: "https://sso.workjam.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: "workjam"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "write"),
            URLQueryItem(name: "redirect_uri", value: "com.workjam.workjam://login/oauth2"),
            URLQueryItem(name: "login_hint", value: encodedEmail)
        ]

        guard let url = components.url else {
            errorMessage = "Impossible de construire l'URL SSO."
            isLoading = false
            return
        }

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "com.workjam.workjam"
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.statusMessage = "Connexion annulée."
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Erreur : \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    return
                }
                guard let callbackURL else {
                    self.errorMessage = "Aucune URL de retour reçue."
                    self.isLoading = false
                    return
                }
                await self.handleCallback(url: callbackURL)
            }
        }

        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.presentationContextProvider = self
        statusMessage = "Ouverture de la page de connexion…"

        guard authSession?.start() == true else {
            errorMessage = "Impossible de démarrer l'authentification."
            isLoading = false
            return
        }
    }

    private func handleCallback(url: URL) async {
        statusMessage = "Extraction du code d'autorisation…"
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            errorMessage = "Code d'autorisation introuvable."
            isLoading = false
            return
        }
        await exchangeCode(code)
    }

    private func exchangeCode(_ code: String) async {
        statusMessage = "Finalisation de la connexion…"
        do {
            let authResponse = try await api.exchangeOAuthCode(code: code)
            guard let token = authResponse.bearerToken, let empID = authResponse.empID else {
                errorMessage = "Réponse invalide du serveur."
                isLoading = false
                return
            }
            _ = keychain.saveToken(token)
            _ = keychain.saveEmployeeID(empID)
            _ = keychain.saveEmail(email)
            isAuthenticated = true
            statusMessage = "Connexion réussie !"
            isLoading = false
        } catch let error as WJAPIError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Import des horaires

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
            errorMessage = "Session expirée. Veuillez vous reconnecter."
            isAuthenticated = false
            keychain.logout()
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
        errorMessage = nil
        statusMessage = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension WorkJamAuthViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? ASPresentationAnchor()
    }
}
