//
//  CalendarSyncView.swift
//  WorkScheduleApp
//

import SwiftUI
import EventKit

struct CalendarSyncView: View {
    @Binding var isPresented: Bool

    let shifts: [Shift]
    let service: CalendarSyncService

    @State private var showingCalendarPicker = false
    @State private var showingResetConfirm   = false
    @State private var syncDone              = false
    @State private var firstSyncStarted      = false

    // First-sync setup pending choice (local until confirmed)
    @State private var pendingFromToday = true

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale   = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                content
                Spacer()
                footer
            }
        }
        .onAppear { service.checkStatus() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Text("Calendrier iPhone")
                .font(.chicago14)
                .foregroundStyle(Color.systemBlack)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.systemWhite)
        .overlay(Rectangle().stroke(Color.systemBlack, lineWidth: 2))
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch service.authorizationStatus {
        case .notDetermined:
            permissionRequestView
        case .denied, .restricted:
            permissionDeniedView
        default:
            if showingCalendarPicker || !service.isConfigured {
                calendarPickerView
            } else if service.lastSyncDate == nil && !firstSyncStarted {
                firstSyncSetupView
            } else {
                syncControlView
            }
        }
    }

    // MARK: - Permission request

    private var permissionRequestView: some View {
        VStack(spacing: 28) {
            iconCircle("📅")

            VStack(spacing: 10) {
                Text("Accès au Calendrier")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemBlack)
                Text("Shifter a besoin d'accéder à votre\ncalendrier pour y ajouter vos horaires.")
                    .font(.geneva10)
                    .foregroundStyle(Color.systemGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            SystemButton("Autoriser l'accès") {
                Task {
                    await service.requestAccess()
                }
            }
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 28) {
            iconCircle("🔒")

            VStack(spacing: 10) {
                Text("Accès refusé")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemBlack)
                Text("Activez l'accès au Calendrier dans\nRéglages > Shifter > Calendrier.")
                    .font(.geneva10)
                    .foregroundStyle(Color.systemGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            SystemButton("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Calendar picker

    private var calendarPickerView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Choisir un calendrier")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemBlack)
                Text("Sélectionnez le calendrier où\nvos horaires seront ajoutés.")
                    .font(.geneva10)
                    .foregroundStyle(Color.systemGray)
                    .multilineTextAlignment(.center)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(service.writableCalendars, id: \.calendarIdentifier) { calendar in
                        calendarRow(calendar)
                    }
                }
                .background(Color.systemWhite)
                .overlay(Rectangle().stroke(Color.systemBlack, lineWidth: 2))
            }
            .frame(maxHeight: 300)
        }
        .padding(.horizontal, 24)
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        Button {
            service.selectedCalendarID = calendar.calendarIdentifier
            showingCalendarPicker      = false
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.systemBlack, lineWidth: 1))

                Text(calendar.title)
                    .font(.geneva10)
                    .foregroundStyle(Color.systemBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if calendar.calendarIdentifier == service.selectedCalendarID {
                    Text("✓")
                        .font(.chicago12)
                        .foregroundStyle(Color.systemBlack)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.systemWhite)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.systemBlack.opacity(0.2)),
            alignment: .bottom
        )
    }

    // MARK: - First sync setup

    private var firstSyncSetupView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Première synchronisation")
                    .font(.chicago14)
                    .foregroundStyle(Color.systemBlack)
                Text("La synchro remplace toujours les\névénements Shifter existants.")
                    .font(.geneva10)
                    .foregroundStyle(Color.systemGray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                setupOptionRow(
                    title: "À partir d'aujourd'hui",
                    subtitle: "Ignore les horaires passés",
                    isOn: $pendingFromToday
                )
            }
            .background(Color.systemWhite)
            .overlay(Rectangle().stroke(Color.systemBlack, lineWidth: 2))
        }
        .padding(.horizontal, 24)
    }

    private func setupOptionRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.geneva10)
                        .foregroundStyle(Color.systemBlack)
                    Text(subtitle)
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(isOn.wrappedValue ? "OUI" : "NON")
                    .font(.chicago12)
                    .foregroundStyle(isOn.wrappedValue ? Color.systemBlack : Color.systemGray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isOn.wrappedValue ? Color.systemBlack.opacity(0.08) : Color.clear)
                    .overlay(Rectangle().stroke(
                        isOn.wrappedValue ? Color.systemBlack : Color.systemGray,
                        lineWidth: 1.5
                    ))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sync control

    private var syncControlView: some View {
        VStack(spacing: 24) {
            iconCircle("📅")

            // Current calendar
            if let cal = service.selectedCalendar {
                VStack(spacing: 6) {
                    Text("Calendrier actif")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(cgColor: cal.cgColor))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.systemBlack, lineWidth: 1))
                        Text(cal.title)
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.systemWhite)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.systemBlack, lineWidth: 2))
                }
            }

            // Last sync
            VStack(spacing: 4) {
                if let date = service.lastSyncDate {
                    Text("Dernière sync : \(dateFormatter.string(from: date))")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                    Text("\(service.lastSyncCount) horaire\(service.lastSyncCount > 1 ? "s" : "") synchronisé\(service.lastSyncCount > 1 ? "s" : "")")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                } else {
                    Text("Synchronisation en cours...")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                }
            }

            // Error
            if let error = service.syncError {
                Text("⚠️ \(error)")
                    .font(.geneva9)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Success toast
            if syncDone {
                Text("✅ Synchronisation réussie")
                    .font(.chicago12)
                    .foregroundStyle(Color.green)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if service.authorizationStatus == .notDetermined || !service.isAuthorized {
                EmptyView()
            } else if showingCalendarPicker || !service.isConfigured {
                EmptyView()
            } else if service.lastSyncDate == nil && !firstSyncStarted {
                // First sync: confirm setup + launch
                Button {
                    service.syncFromToday   = pendingFromToday
                    firstSyncStarted = true
                    syncDone = false
                    Task {
                        await service.syncShifts(shifts)
                        if service.syncError == nil {
                            syncDone = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { syncDone = false }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("▶")
                            .font(.system(size: 14))
                        Text("Démarrer la synchronisation")
                            .font(.chicago14)
                    }
                    .foregroundStyle(Color.systemBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.systemWhite)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemBlack, lineWidth: 3))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.15), radius: 0, x: 3, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                // Sync button
                Button {
                    syncDone = false
                    Task {
                        await service.syncShifts(shifts)
                        if service.syncError == nil {
                            syncDone = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { syncDone = false }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        if service.isSyncing {
                            ProgressView().tint(.systemBlack)
                        } else {
                            Text("🔄")
                                .font(.system(size: 18))
                        }
                        Text(service.isSyncing ? "Synchronisation..." : "Synchroniser maintenant")
                            .font(.chicago14)
                    }
                    .foregroundStyle(Color.systemBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.systemWhite)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemBlack, lineWidth: 3))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.15), radius: 0, x: 3, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(service.isSyncing)

                // Change calendar
                Button {
                    showingCalendarPicker = true
                } label: {
                    Text("Changer de calendrier")
                        .font(.chicago12)
                        .foregroundStyle(Color.systemBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.systemBeige)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemBlack, lineWidth: 2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Reset
                Button {
                    showingResetConfirm = true
                } label: {
                    Text("Désactiver la sync")
                        .font(.chicago12)
                        .foregroundStyle(Color.systemGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.systemBeige)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemGray, lineWidth: 2))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Close
            Button {
                isPresented = false
            } label: {
                Text("Fermer")
                    .font(.chicago12)
                    .foregroundStyle(Color.systemGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.systemBeige)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.systemGray, lineWidth: 2))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .alert("Désactiver la sync ?", isPresented: $showingResetConfirm) {
            Button("Supprimer les événements", role: .destructive) {
                Task {
                    await service.resetSync()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tous les horaires ajoutés par Shifter seront supprimés du calendrier.")
        }
    }

    // MARK: - Helpers

    private func iconCircle(_ emoji: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.systemWhite)
                .frame(width: 120, height: 120)
                .overlay(Circle().stroke(Color.systemBlack, lineWidth: 3))
            Text(emoji)
                .font(.system(size: 64))
        }
    }
}
