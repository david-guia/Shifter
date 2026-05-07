//
//  SegmentFilterView.swift
//  WorkScheduleApp
//
//  Sélection des segments à afficher dans la vue statistiques
//

import SwiftUI

struct SegmentFilterView: View {
    let segments: [String]
    @Binding var hiddenSegments: Set<String>
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Filtrer les shifts")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemBlack)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.systemWhite)
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(Color.systemBlack),
                    alignment: .bottom
                )

                // Boutons tout afficher / tout masquer
                HStack(spacing: 12) {
                    Button {
                        hiddenSegments = []
                    } label: {
                        Text("Tout afficher")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.systemWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        hiddenSegments = Set(segments)
                    } label: {
                        Text("Tout masquer")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.systemWhite)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.systemBlack, lineWidth: 2)
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Note informative
                Text("Le total continue d'inclure toutes les heures, même celles des lignes masquées.")
                    .font(.geneva10)
                    .foregroundStyle(Color.systemGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Liste des segments
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(segments, id: \.self) { segment in
                            let isHidden = hiddenSegments.contains(segment)

                            Button {
                                if isHidden {
                                    hiddenSegments.remove(segment)
                                } else {
                                    hiddenSegments.insert(segment)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: isHidden ? "square" : "checkmark.square.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.systemBlack)

                                    Text(segment)
                                        .font(.chicago12)
                                        .foregroundStyle(isHidden ? Color.systemGray : Color.systemBlack)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.systemWhite)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundStyle(Color.systemBlack.opacity(0.15)),
                                    alignment: .bottom
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.systemBlack, lineWidth: 2)
                    )
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }

                // Bouton fermer
                Button {
                    isPresented = false
                } label: {
                    Text("OK")
                        .font(.chicago14)
                        .foregroundStyle(Color.systemWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.systemBlack, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
}
