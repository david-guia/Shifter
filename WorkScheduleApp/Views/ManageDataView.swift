//
//  ManageDataView.swift
//  WorkScheduleApp
//
//  Vue de gestion des données - Correction et suppression des shifts
//

import SwiftUI
import SwiftData

struct ManageDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var isPresented: Bool
    @State private var showingDeleteAllAlert = false
    @State private var selectedShiftToDelete: Shift?
    @State private var selectedShiftToEdit: Shift?
    @State private var searchText = ""
    
    private var allShifts: [Shift] {
        guard let schedule = viewModel.schedules.first else { return [] }
        return schedule.shifts.sorted { $0.date > $1.date }
    }
    
    private var filteredShifts: [Shift] {
        if searchText.isEmpty {
            return allShifts
        }
        return allShifts.filter { shift in
            shift.segment.localizedCaseInsensitiveContains(searchText) ||
            shift.location.localizedCaseInsensitiveContains(searchText)
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
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                
                // Barre de recherche pleine largeur
                HStack(spacing: 12) {
                    Text("🔍")
                        .font(.system(size: 18))
                    TextField("Rechercher par segment ou emplacement...", text: $searchText)
                        .font(.geneva10)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemWhite)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Statistiques modernisées
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("\(allShifts.count)")
                            .font(.custom("Chicago", size: 28))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.systemBlack)
                        Text("Shifts totaux")
                            .font(.geneva9)
                            .foregroundStyle(Color.systemGray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Rectangle()
                        .fill(Color.systemBlack)
                        .frame(width: 2)
                        .padding(.vertical, 12)
                    
                    VStack(spacing: 6) {
                        Text(totalHours)
                            .font(.custom("Chicago", size: 28))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.systemBlack)
                        Text("Heures de travail")
                            .font(.geneva9)
                            .foregroundStyle(Color.systemGray)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 20)
                .background(Color.systemBeige)
                .overlay(
                    Rectangle()
                        .stroke(Color.systemBlack, lineWidth: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Liste des shifts avec message si vide
                if filteredShifts.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text(searchText.isEmpty ? "📋" : "🔍")
                            .font(.system(size: 64))
                        Text(searchText.isEmpty ? "Aucune donnée" : "Aucun résultat")
                            .font(.chicago14)
                            .foregroundStyle(Color.systemBlack)
                        Text(searchText.isEmpty ? "Importez des captures d'écran" : "Essayez une autre recherche")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredShifts) { shift in
                                ShiftRowView(shift: shift) {
                                    selectedShiftToEdit = shift
                                } onDelete: {
                                    selectedShiftToDelete = shift
                                }
                                
                                if shift != filteredShifts.last {
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
                Text("Voulez-vous vraiment supprimer ce shift (\(shift.segment) - \(shift.date.mediumFrench)) ?")
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
                    Text(shift.date.shortDate)
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
