//
//  WorkJamAuthViewModel.swift
//  WorkScheduleApp
//
//  ViewModel gérant l'authentification SSO WorkJam via ASWebAuthenticationSession
//  et le déclenchement de l'import automatique des horaires
//

import Foundation
import Observation
import SwiftData
import AuthenticationServices

@Observable
@MainActor
class WorkJamAuthViewModel: NSObject {

    // MARK: - État de l'interface

    var email: String = ""
    var companyID: String = ""
    var isLoading: Bool = false
    var isAuthenticated: Bool = false
    var errorMessage: String?
    var statusMessage: String?

    var importedCount: Int = 0
    var showImportSuccess: Bool = false
    var isImporting: Bool = false

    // MARK: - Privé

    private let api = WorkJamAPIClient.shared
    private let keychain = WorkJamKeychain.shared
    private var authSession: ASWebAuthenticationSession?

    private let lastSyncKey = "workjam_last_sync_date"
    /// Intervalle minimum entre deux syncs automatiques (en heures)
    private let autoSyncIntervalHours: Double = 6

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    // MARK: - Initialisation

    override init() {
        super.init()
        checkExistingSession()
        if let savedEmail = keychain.retrieveEmail() {
            email = savedEmail
        }
        if let savedCompanyID = keychain.retrieveCompanyID() {
            companyID = savedCompanyID
        }
    }

    func checkExistingSession() {
        isAuthenticated = keychain.isLoggedIn()
    }

    // MARK: - Connexion SSO

    var canStartAuth: Bool {
        !email.isEmpty && email.contains("@") && !companyID.isEmpty && !isLoading
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
            _ = keychain.saveCompanyID(companyID)
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

        // Depuis le 6 juin 2024 jusqu'à 28 jours dans le futur
        var startComponents = DateComponents()
        startComponents.year = 2024
        startComponents.month = 6
        startComponents.day = 6
        let historyStart = Calendar.current.date(from: startComponents)
            ?? Calendar.current.startOfDay(for: Date())

        let today = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 28, to: today) ?? today

        do {
            // Découper en tranches de 3 mois pour fiabilité (limite API WorkJam)
            statusMessage = "Chargement des horaires…"
            var allEvents: [WJEvent] = []
            var sliceStart = historyStart
            let cal = Calendar.current
            var sliceIndex = 0

            while sliceStart < endDate {
                let sliceEnd = min(
                    cal.date(byAdding: .month, value: 3, to: sliceStart) ?? endDate,
                    endDate
                )
                let slice = try await api.fetchEvents(
                    token: token,
                    employeeID: empID,
                    startDate: sliceStart,
                    endDate: sliceEnd
                )
                allEvents.append(contentsOf: slice)
                sliceStart = sliceEnd
                sliceIndex += 1
                statusMessage = "Chargement des horaires… (\(sliceIndex * 3) mois traités)"
            }

            // Dédupliquer les événements par ID
            var seen = Set<String>()
            let events = allEvents.filter { seen.insert($0.id).inserted }

            // Récupérer les détails de shift en parallèle pour obtenir les vraies zones
            statusMessage = "Récupération des zones de travail…"
            let shiftEvents = events.filter { $0.type == "SHIFT" && $0.location != nil }
            var detailMap: [String: WJShiftDetail] = [:]

            await withTaskGroup(of: (String, WJShiftDetail?).self) { group in
                for event in shiftEvents {
                    guard let locationID = event.location?.id else { continue }
                    group.addTask {
                        let detail = try? await self.api.fetchShiftDetail(
                            token: token,
                            shiftID: event.id,
                            locationID: locationID
                        )
                        return (event.id, detail)
                    }
                }
                for await (eventID, detail) in group {
                    if let detail { detailMap[eventID] = detail }
                }
            }

            let shifts = WorkJamImportService.convertEvents(events, detailMap: detailMap)
            let count = WorkJamImportService.insertShifts(shifts, into: context)
            importedCount = count
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
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

    // MARK: - Sync automatique au lancement

    /// Sync silencieuse : se déclenche si connecté et si la dernière sync date
    /// de plus de `autoSyncIntervalHours` heures (ou n'a jamais eu lieu).
    func autoSyncIfNeeded(context: ModelContext) async {
        guard isAuthenticated else { return }

        if let last = lastSyncDate {
            let hoursSinceLast = Date().timeIntervalSince(last) / 3600
            guard hoursSinceLast >= autoSyncIntervalHours else { return }
        }

        await importShifts(context: context)
    }

    // MARK: - Déconnexion

    func logout() {
        keychain.logout()
        isAuthenticated = false
        email = ""
        companyID = ""
        errorMessage = nil
        statusMessage = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension WorkJamAuthViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = (scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene)
                             ?? (scenes.first as? UIWindowScene) else {
            // Ne devrait jamais arriver sur iOS 26 (scene-based obligatoire)
            return UIWindow(windowScene: scenes.first as! UIWindowScene)
        }
        return windowScene.windows.first(where: { $0.isKeyWindow })
            ?? windowScene.windows.first
            ?? UIWindow(windowScene: windowScene)
    }
}
