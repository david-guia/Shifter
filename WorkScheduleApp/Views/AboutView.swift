//
//  AboutView.swift
//  WorkScheduleApp
//
//  Vue "À Propos" avec informations sur l'application et le développeur
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    
    // Récupérer la version depuis Info.plist
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ZStack {
            Color.systemBeige.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Spacer()
                    Text("À Propos")
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
                
                ScrollView {
                    VStack(spacing: 32) {
                        // MARK: - Logo et nom de l'app
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.systemWhite)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.systemBlack, lineWidth: 3)
                                    )
                                
                                Image("AppIconImage")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            Text("Shifter")
                                .font(.custom("Chicago", size: 32))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.systemBlack)
                            
                            Text("Version \(appVersion) (Build \(buildNumber))")
                                .font(.geneva10)
                                .foregroundStyle(Color.systemGray)
                        }
                        .padding(.top, 32)
                        
                        // MARK: - Description
                        VStack(spacing: 12) {
                            Text("Gestion d'horaires de travail")
                                .font(.chicago14)
                                .foregroundStyle(Color.systemBlack)
                            
                            Text("Importez vos captures d'écran WorkJam\net visualisez vos statistiques")
                                .font(.geneva10)
                                .foregroundStyle(Color.systemGray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 32)
                        
                        // MARK: - Développeur
                        VStack(spacing: 16) {
                            Rectangle()
                                .fill(Color.systemBlack)
                                .frame(height: 2)
                                .padding(.horizontal, 40)
                            
                            VStack(spacing: 8) {
                                Text("Développé par")
                                    .font(.geneva9)
                                    .foregroundStyle(Color.systemGray)
                                
                                Text("David Guia")
                                    .font(.chicago14)
                                    .foregroundStyle(Color.systemBlack)
                                    .fontWeight(.bold)
                            }
                            
                            // Informations supplémentaires
                            VStack(spacing: 8) {
                                InfoRow(icon: "📱", text: "iOS 18+")
                                InfoRow(icon: "🎨", text: "Design inspiré macOS classique")
                                InfoRow(icon: "🤖", text: "OCR & Parsing automatique")
                                InfoRow(icon: "💾", text: "Backup automatique")
                            }
                            .padding(.top, 8)
                            
                            Rectangle()
                                .fill(Color.systemBlack)
                                .frame(height: 2)
                                .padding(.horizontal, 40)
                        }
                        
                        // MARK: - Copyright
                        VStack(spacing: 4) {
                            Text("© 2025 David Guia")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                            
                            Text("Tous droits réservés")
                                .font(.geneva9)
                                .foregroundStyle(Color.systemGray)
                        }
                        .padding(.bottom, 32)
                    }
                }
                
                // MARK: - Bouton Fermer
                Button {
                    dismiss()
                } label: {
                    Text("Fermer")
                        .font(.chicago12)
                        .foregroundStyle(Color.systemBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.systemWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.systemBlack, lineWidth: 2)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Composant InfoRow

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 16))
            Text(text)
                .font(.geneva10)
                .foregroundStyle(Color.systemBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 48)
    }
}

#Preview {
    AboutView(isPresented: .constant(true))
}
