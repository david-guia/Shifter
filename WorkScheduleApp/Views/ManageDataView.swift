//
//  ManageDataView.swift
//  WorkScheduleApp
//
//  Vue de gestion des données - Correction et suppression des shifts
//

import SwiftUI
import SwiftData
import WidgetKit

struct ManageDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isPresented: Bool
    @State private var showingDeleteAllAlert = false
    @State private var selectedShiftToDelete: Shift?
    @State private var selectedShiftToEdit: Shift?
    @State private var selectedCalendarDate = Date()
    @State private var showingAddShiftSheet = false
    
    private var allShifts: [Shift] {
        guard let schedule = viewModel.schedules.first else { return [] }
        return schedule.shifts.sorted { $0.date > $1.date }
    }
    
    // Shifts filtrés par le mois sélectionné dans le calendrier
    private var shiftsForSelectedMonth: [Shift] {
        let calendar = Calendar.current
        return allShifts.filter { shift in
            calendar.isDate(shift.date, equalTo: selectedCalendarDate, toGranularity: .month)
        }
    }
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header personnalisé pleine largeur
                HStack {
                    Spacer()
                    Text("Gérer les données")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.systemWhite)
                
                // Calendrier mensuel avec cases ✅
                VStack(spacing: 0) {
                    // En-tête du calendrier avec navigation
                    HStack(spacing: 0) {
                        Button {
                            changeMonth(by: -1)
                        } label: {
                            Text("◀")
                                .font(.chicago12)
                                .foregroundStyle(Color.systemWhite)
                                .frame(width: 40)
                        }
                        .buttonStyle(.plain)
                        
                        Text(monthYearLabel)
                            .font(.chicago14)
                            .foregroundStyle(Color.systemWhite)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Button {
                            changeMonth(by: 1)
                        } label: {
                            Text("▶")
                                .font(.chicago12)
                                .foregroundStyle(Color.systemWhite)
                                .frame(width: 40)
                        }
                        .buttonStyle(.plain)
                        
                        HStack(spacing: 6) {
                            Text("\(shiftsInSelectedMonth.count)")
                                .font(.chicago12)
                                .fontWeight(.bold)
                            Text("•")
                                .font(.geneva9)
                            Text(totalHoursInSelectedMonth)
                                .font(.chicago12)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(Color.systemWhite)
                        .padding(.trailing, 12)
                    }
                    .padding(.vertical, 10)
                    .background(Color.systemBlack)
                    
                    // Jours de la semaine
                    HStack(spacing: 0) {
                        ForEach(weekdaySymbols, id: \.self) { day in
                            Text(day)
                                .font(.chicago12)
                                .foregroundStyle(Color.systemBlack)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color.systemBeige)
                    .overlay(
                        Rectangle()
                            .stroke(Color.systemBlack, lineWidth: 1)
                    )
                    
                    // Grille du calendrier
                    VStack(spacing: 0) {
                        ForEach(0..<numberOfWeeks, id: \.self) { weekIndex in
                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { dayIndex in
                                    let dayNumber = getDayNumber(for: weekIndex, dayIndex: dayIndex)
                                    
                                    ZStack {
                                        if let day = dayNumber {
                                            let hasShift = dayHasShift(day: day)
                                            
                                            VStack(spacing: 2) {
                                                Text("\(day)")
                                                    .font(.chicago12)
                                                    .foregroundStyle(hasShift ? Color.systemBlack : Color.systemGray)
                                                
                                                if hasShift {
                                                    Text("✅")
                                                        .font(.system(size: 12))
                                                } else {
                                                    Text(" ")
                                                        .font(.system(size: 12))
                                                }
                                            }
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                    .frame(height: 44)
                                    .background(dayNumber != nil ? Color.systemWhite : Color.systemBeige.opacity(0.3))
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.systemBlack, lineWidth: 0.5)
                                    )
                                }
                            }
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Liste des shifts avec message si vide
                if shiftsForSelectedMonth.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("📋")
                            .font(.system(size: 64))
                        Text("Aucun shift")
                            .font(.chicago14)
                            .foregroundStyle(Color.systemBlack)
                        Text("Aucun horaire pour ce mois")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(shiftsForSelectedMonth) { shift in
                                ShiftRowView(shift: shift) {
                                    selectedShiftToEdit = shift
                                } onDelete: {
                                    selectedShiftToDelete = shift
                                }
                                
                                if shift != shiftsForSelectedMonth.last {
                                    Rectangle()
                                        .fill(Color.systemBlack)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                    .background(Color.systemWhite)
                    .overlay(
                        Rectangle()
                            .stroke(Color.systemBlack, lineWidth: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                // Boutons en bas
                VStack(spacing: 12) {
                    Button {
                        showingAddShiftSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Text("➕")
                                .font(.system(size: 18))
                            Text("Ajouter un shift")
                                .font(.chicago14)
                        }
                        .foregroundStyle(Color.systemBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.systemWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.systemBlack, lineWidth: 3)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showingDeleteAllAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Text("🗑️")
                                .font(.system(size: 20))
                            Text("Tout effacer")
                                .font(.chicago14)
                        }
                        .foregroundStyle(allShifts.isEmpty ? Color.systemGray : Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(allShifts.isEmpty ? Color.systemWhite.opacity(0.5) : Color.systemWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(allShifts.isEmpty ? Color.systemGray : Color.red, lineWidth: 3)
                        )
                        .cornerRadius(8)
                        .shadow(color: allShifts.isEmpty ? .clear : .red.opacity(0.15), radius: 0, x: 3, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(allShifts.isEmpty)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Fermer")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.systemBeige)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.systemGray, lineWidth: 2)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .alert("Supprimer le shift", isPresented: .constant(selectedShiftToDelete != nil)) {
            Button("Annuler", role: .cancel) {
                selectedShiftToDelete = nil
            }
            Button("Supprimer", role: .destructive) {
                if let shift = selectedShiftToDelete {
                    viewModel.deleteShift(shift)
                    selectedShiftToDelete = nil
                }
            }
        } message: {
            if let shift = selectedShiftToDelete {
                Text("Voulez-vous vraiment supprimer ce shift (\(shift.segment) - \(shift.date.formatted(date: .abbreviated, time: .omitted))) ?")
            }
        }
        .alert("Effacer toutes les données", isPresented: $showingDeleteAllAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Tout effacer", role: .destructive) {
                viewModel.deleteAllShifts()
                dismiss()
            }
        } message: {
            Text("Voulez-vous vraiment supprimer tous les shifts (\(allShifts.count) au total) ? Cette action est irréversible.")
        }
        .sheet(item: $selectedShiftToEdit) { shift in
            EditShiftView(viewModel: viewModel, shift: shift, isPresented: .constant(true))
        }
        .sheet(isPresented: $showingAddShiftSheet) {
            ManualShiftView(viewModel: viewModel, isPresented: $showingAddShiftSheet, parentIsPresented: $isPresented)
        }
    }
    
    /// Label du mois et année sélectionné (ex: "Décembre 2025")
    private var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedCalendarDate).capitalized
    }
    
    /// Shifts dans le mois sélectionné
    private var shiftsInSelectedMonth: [Shift] {
        let calendar = Calendar.current
        return allShifts.filter { shift in
            calendar.isDate(shift.date, equalTo: selectedCalendarDate, toGranularity: .month)
        }
    }
    
    /// Total d'heures pour le mois sélectionné
    private var totalHoursInSelectedMonth: String {
        let total = shiftsInSelectedMonth.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total / 3600)
        let minutes = Int((total.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if minutes == 0 {
            return "\(hours)h"
        }
        return String(format: "%dh%02d", hours, minutes)
    }
    
    /// Nombre de semaines dans le mois sélectionné
    private var numberOfWeeks: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .weekOfMonth, in: .month, for: selectedCalendarDate)!
        return range.count
    }
    
    /// Premier jour du mois sélectionné (jour de la semaine, 1 = Lundi)
    private var firstWeekdayOfMonth: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedCalendarDate)
        let firstDay = calendar.date(from: components)!
        let weekday = calendar.component(.weekday, from: firstDay)
        
        // Convertir au format européen (1 = Lundi)
        return weekday == 1 ? 7 : weekday - 1
    }
    
    /// Nombre de jours dans le mois sélectionné
    private var numberOfDaysInMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedCalendarDate)!
        return range.count
    }
    
    /// Change de mois (navigation)
    private func changeMonth(by value: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedCalendarDate) {
            selectedCalendarDate = newDate
        }
    }
    
    // MARK: - Propriétés du calendrier
    
    /// Symboles des jours de la semaine (L M M J V S D)
    private var weekdaySymbols: [String] {
        ["L", "M", "M", "J", "V", "S", "D"]
    }
    
    /// Retourne le numéro du jour pour une position donnée dans le calendrier
    private func getDayNumber(for weekIndex: Int, dayIndex: Int) -> Int? {
        let position = weekIndex * 7 + dayIndex + 1
        let dayNumber = position - firstWeekdayOfMonth + 1
        
        guard dayNumber >= 1 && dayNumber <= numberOfDaysInMonth else {
            return nil
        }
        
        return dayNumber
    }
    
    /// Vérifie si un jour donné a au moins un shift enregistré
    private func dayHasShift(day: Int) -> Bool {
        let calendar = Calendar.current
        
        for shift in allShifts {
            // Vérifier si le shift est dans le mois sélectionné
            if calendar.isDate(shift.date, equalTo: selectedCalendarDate, toGranularity: .month) {
                let shiftDay = calendar.component(.day, from: shift.date)
                if shiftDay == day {
                    return true
                }
            }
        }
        
        return false
    }
    
    private var totalHours: String {
        let total = allShifts.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total / 3600)
        let minutes = Int((total.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if minutes == 0 {
            return "\(hours)h"
        }
        return String(format: "%dh%02d", hours, minutes)
    }
}

// MARK: - Manual Shift View (embedded to avoid adding new target file)
struct ManualShiftView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isPresented: Bool
    // Binding optionnel vers la feuille parente (ManageDataView) pour pouvoir la fermer après enregistrement
    private var parentIsPresented: Binding<Bool>? = nil
    // Le champ "nom" a été remplacé par un picker `segment` renommé en "Shift"
    @State private var date: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Calendar.current.date(byAdding: .hour, value: 8, to: Date()) ?? Date()
    @State private var segment: String = "Général"
    @State private var customShiftName: String = ""
    @State private var notes: String = ""
    
    let segments: [String]

    init(viewModel: ScheduleViewModel, isPresented: Binding<Bool>, parentIsPresented: Binding<Bool>? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.parentIsPresented = parentIsPresented
        // Liste restreinte demandée + variantes numérotées générées pour Sales/Runner/Setup
        var list: [String] = []
        list.append("Aucun")

        // Sales (variantes numérotées 1..3) — base "Sales" retirée
        for i in 1...3 { list.append("Sales \(i)") }

        // Runner (uniquement variante 1) — base et Runner 2 retirés
        list.append("Runner 1")

        // Setup (base seule) — variantes numérotées retirées
        list.append("Setup")

        // Autres segments demandés
        list.append(contentsOf: [
            "PZ On Point",
            "GB On Point",
            "Cycle Counts",
            "Connection",
            "Roundtable",
            "Onboarding",
            "Visuals",
            "Pause repas",
            "Daily Download",
            "Learn and Grow",
            "Avenues"
        ])

        self.segments = list
        if let first = self.segments.first {
            self._segment = State(initialValue: first)
        }

        // Définir les heures par défaut: 08:00 -> 19:00 sur la journée sélectionnée
        let calendar = Calendar.current
        let now = Date()
        var startComps = calendar.dateComponents([.year, .month, .day], from: now)
        startComps.hour = 8
        startComps.minute = 0
        var endComps = calendar.dateComponents([.year, .month, .day], from: now)
        endComps.hour = 19
        endComps.minute = 0

        let defaultStart = calendar.date(from: startComps) ?? now
        let defaultEnd = calendar.date(from: endComps) ?? calendar.date(byAdding: .hour, value: 11, to: defaultStart) ?? now

        self._startTime = State(initialValue: defaultStart)
        self._endTime = State(initialValue: defaultEnd)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                Section(header: Text("Détails")) {
                    // Picker 'Shift' (liste restreinte)
                    Picker("Shift", selection: $segment) {
                        ForEach(segments, id: \.self) { s in
                            Text(s)
                        }
                    }

                    // Si 'Aucun' sélectionné, afficher un champ pour nom personnalisé
                    if segment == "Aucun" {
                        TextField("Nom personnalisé", text: $customShiftName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 4)
                    }

                    DatePicker("Jour", selection: $date, displayedComponents: .date)

                    HStack {
                        DatePicker("Début", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Fin", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                // Section 'Notes' supprimée à la demande (champ inutile en bas de l'écran)
                }
                .scrollContentBackground(.hidden)
                .background(Color.systemBeige)

                // Espace vide pour aérer la feuille
                Spacer(minLength: 120)
            }
            .background(Color.systemBeige.ignoresSafeArea())
            .navigationTitle("Ajouter un shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveShift()
                    }
                    .disabled(!isValid())
                }
            }
        }
    }

    private func isValid() -> Bool {
        // Si 'Aucun' est sélectionné, le nom personnalisé doit être non vide
        if segment == "Aucun" {
            return startTime < endTime && !customShiftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return startTime < endTime
    }

    private func saveShift() {
        guard let schedule = viewModel.schedules.first else {
            isPresented = false
            return
        }

        // Combine selected day with chosen times so the shift is anchored to the chosen date
        let calendar = Calendar.current
        func combine(day: Date, time: Date) -> Date {
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
            var comps = DateComponents()
            comps.year = dayComponents.year
            comps.month = dayComponents.month
            comps.day = dayComponents.day
            comps.hour = timeComponents.hour
            comps.minute = timeComponents.minute
            comps.second = timeComponents.second
            return calendar.date(from: comps) ?? time
        }

        let combinedStart = combine(day: date, time: startTime)
        var combinedEnd = combine(day: date, time: endTime)

        // If end is before or equal to start, assume shift ends next day
        if combinedEnd <= combinedStart {
            if let next = calendar.date(byAdding: .day, value: 1, to: combinedEnd) {
                combinedEnd = next
            }
        }

        // Si 'Aucun', utiliser le nom personnalisé comme segment
        let finalSegment = segment == "Aucun" ? customShiftName.trimmingCharacters(in: .whitespacesAndNewlines) : segment

        viewModel.addManualShift(to: schedule, date: date, startTime: combinedStart, endTime: combinedEnd, location: "", segment: finalSegment, notes: notes)
        viewModel.syncToWatch()
        WidgetCenter.shared.reloadAllTimelines()

        // Fermer la feuille d'ajout
        isPresented = false
        // Fermer aussi la feuille parente (ManageDataView) pour revenir directement à l'écran principal
        parentIsPresented?.wrappedValue = false
    }
}

// MARK: - Ligne de shift
struct ShiftRowView: View {
    let shift: Shift
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.segment)
                    .font(.chicago12)
                    .foregroundStyle(Color.systemBlack)
                
                HStack(spacing: 8) {
                    Text(shift.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                    
                    Text("•")
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                    
                    Text(shift.location)
                        .font(.geneva9)
                        .foregroundStyle(Color.systemGray)
                }
            }
            
            Spacer()
            
            Text(shift.durationFormatted)
                .font(.chicago12)
                .foregroundStyle(Color.systemBlack)
                .frame(width: 60, alignment: .trailing)
            
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Text("✏️")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(Color.systemBeige)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 1)
                )
                
                Button {
                    onDelete()
                } label: {
                    Text("🗑️")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(Color.systemBeige)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(Color.systemWhite)
    }
}

// MARK: - Édition de shift
struct EditShiftView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    let shift: Shift
    @Binding var isPresented: Bool
    
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var location: String
    @State private var segment: String
    @State private var notes: String
    
    init(viewModel: ScheduleViewModel, shift: Shift, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.shift = shift
        self._isPresented = isPresented
        
        _date = State(initialValue: shift.date)
        _startTime = State(initialValue: shift.startTime)
        _endTime = State(initialValue: shift.endTime)
        _location = State(initialValue: shift.location)
        _segment = State(initialValue: shift.segment)
        _notes = State(initialValue: shift.notes)
    }
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 16) {
                SystemWindow(title: "Modifier le shift", isActive: true) {
                    VStack(spacing: 12) {
                        // Date
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Date")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        
                        // Heures
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Début")
                                    .font(.geneva9)
                                    .foregroundStyle(Color.systemGray)
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fin")
                                    .font(.geneva9)
                                    .foregroundStyle(Color.systemGray)
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }
                        
                        // Segment
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Segment")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            TextField("", text: $segment)
                                .font(.geneva10)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.systemWhite)
                                .border(Color.systemBlack, width: 1)
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Emplacement")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            TextField("", text: $location)
                                .font(.geneva10)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.systemWhite)
                                .border(Color.systemBlack, width: 1)
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            TextEditor(text: $notes)
                                .font(.geneva10)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color.systemWhite)
                                .border(Color.systemBlack, width: 1)
                        }
                        
                        // Boutons
                        HStack(spacing: 12) {
                            SystemButton("Annuler") {
                                dismiss()
                            }
                            
                            SystemButton("Enregistrer", isDefault: true) {
                                viewModel.updateShift(
                                    shift,
                                    date: date,
                                    startTime: startTime,
                                    endTime: endTime,
                                    location: location,
                                    segment: segment,
                                    notes: notes
                                )
                                dismiss()
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: 500)
            }
            .padding(20)
        }
    }
}
