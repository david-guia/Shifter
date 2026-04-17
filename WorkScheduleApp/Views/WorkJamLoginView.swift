//
//  WorkJamLoginView.swift
//  WorkScheduleApp
//
//  Vue de connexion WorkJam SSO - style system.css (Classic macOS)
//

import SwiftUI
import SwiftData

struct WorkJamLoginView: View {

    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authVM = WorkJamAuthViewModel()

    var onImportComplete: ((Int) -> Void)?

    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    SystemTitleBar(title: "WorkJam — Connexion SSO", isActive: true) {
                        isPresented = false
                    }

                    Divider()
                        .frame(height: 2)
                        .background(Color.systemBlack)

                    if authVM.isAuthenticated {
                        authenticatedView
                    } else {
                        ssoFormView
                    }
                }
                .background(Color.systemWhite)
                .border(Color.systemBlack, width: 2)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 4)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }

            if authVM.isLoading || authVM.isImporting {
                loadingOverlay
            }
        }
        .onChange(of: authVM.showImportSuccess) { _, success in
            if success {
                onImportComplete?(authVM.importedCount)
                isPresented = false
            }
        }
    }

    // MARK: - Formulaire SSO

    private var ssoFormView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En-tête
            HStack(spacing: 12) {
                Text("🔐")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connexion via votre entreprise")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Text("Vous serez redirigé vers la page SSO de WorkJam")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.systemBeige)

            Divider().background(Color.systemBlack)

            VStack(alignment: .leading, spacing: 16) {
                // Info SSO
                HStack(alignment: .top, spacing: 8) {
                    Text("ℹ️")
                        .font(.system(size: 14))
                    Text("Votre compte utilise l'authentification SSO. Saisissez votre email pour ouvrir la page de connexion de votre entreprise.")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemDarkGray)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.systemBeige)
                .border(Color.systemBlack, width: 1)

                // Email
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email professionnel")
                        .font(.chicago12)
                        .foregroundStyle(Color.systemBlack)
                    SystemTextField(placeholder: "votre@entreprise.com", text: $authVM.email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                // Message de statut
                if let status = authVM.statusMessage, authVM.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(status)
                            .font(.geneva9)
                            .foregroundStyle(Color.systemGray)
                    }
                }

                // Message d'erreur
                if let error = authVM.errorMessage {
                    HStack(spacing: 6) {
                        Text("⚠️")
                            .font(.system(size: 14))
                        Text(error)
                            .font(.geneva9)
                            .foregroundStyle(Color.red)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .border(Color.red, width: 1)
                }

                // Boutons
                HStack(spacing: 12) {
                    SystemButton("Annuler") {
                        isPresented = false
                    }
                    Spacer()
                    SystemButton("Se connecter →", isDefault: true) {
                        Task { await authVM.startSSO() }
                    }
                    .disabled(!authVM.canStartAuth)
                    .opacity(authVM.canStartAuth ? 1 : 0.5)
                }
            }
            .padding(16)
            .background(Color.systemWhite)
        }
    }

    // MARK: - Vue connecté

    private var authenticatedView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("✅")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connecté à WorkJam")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Text("Prêt à importer vos horaires")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.systemBeige)

            Divider().background(Color.systemBlack)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Text("📅")
                        .font(.system(size: 18))
                    Text("Import des 28 prochains jours")
                        .font(.geneva10)
                        .foregroundStyle(Color.systemBlack)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.systemBeige)
                .border(Color.systemBlack, width: 1)

                if let error = authVM.errorMessage {
                    HStack(spacing: 6) {
                        Text("⚠️")
                            .font(.system(size: 14))
                        Text(error)
                            .font(.geneva9)
                            .foregroundStyle(Color.red)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .border(Color.red, width: 1)
                }

                HStack(spacing: 12) {
                    SystemButton("Se déconnecter", isDestructive: true) {
                        authVM.logout()
                    }
                    Spacer()
                    SystemButton("Importer", isDefault: true) {
                        Task { await authVM.importShifts(context: modelContext) }
                    }
                }
            }
            .padding(16)
            .background(Color.systemWhite)
        }
    }

    // MARK: - Overlay chargement

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.systemWhite)
                Text(authVM.isImporting ? "Import en cours…" : (authVM.statusMessage ?? "Connexion…"))
                    .font(.chicago12)
                    .foregroundStyle(Color.systemWhite)
            }
            .padding(24)
            .background(Color.systemBlack)
            .border(Color.systemWhite, width: 2)
        }
    }
}
