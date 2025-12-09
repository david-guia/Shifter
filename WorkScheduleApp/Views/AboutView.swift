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
                    VStack(spacing: 20) {
                        // MARK: - Logo et nom de l'app
                        VStack(spacing: 12) {
                            // Logo rond comme sur Apple Watch
                            Image("AppIconImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.systemBlack, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                            
                            Text("Shifter")
                                .font(.custom("Chicago", size: 32))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.systemBlack)
                            
                            Text("Version \(appVersion) (Build \(buildNumber))")
                                .font(.geneva10)
                                .foregroundStyle(Color.systemGray)
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Description
                        VStack(spacing: 8) {
                            Text("Gestion d'horaires de travail")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.systemBlack)
                            
                            Text("Importez vos captures d'écran WorkJam\net visualisez vos statistiques")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.systemGray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 32)
                        
                        // Barre de séparation
                        Rectangle()
                            .fill(Color.systemBlack)
                            .frame(height: 2)
                            .padding(.horizontal, 40)
                        
                        // MARK: - Informations
                        VStack(spacing: 10) {
                            InfoRow(icon: "📱", text: "iOS 18+")
                            
                            Button {
                                if let url = URL(string: "https://github.com/sakofchit/system.css") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text("🎨")
                                        .font(.system(size: 18))
                                    HStack(spacing: 0) {
                                        Text("Design inspiré macOS classique (")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.systemBlack)
                                        Text("GitHub")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.blue)
                                            .underline()
                                        Text(")")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.systemBlack)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 48)
                            }
                            .buttonStyle(.plain)
                            
                            InfoRow(icon: "🤖", text: "OCR & Parsing automatique")
                            InfoRow(icon: "💾", text: "Backup automatique")
                            
                            // Afficher le timer de certificat développeur
                            if let installDate = UserDefaults.standard.object(forKey: "firstInstallDate") as? Date {
                                let expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: installDate)!
                                let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0)
                                
                                if days <= 5 {
                                    InfoRow(
                                        icon: days <= 1 ? "⏱️" : "🕐",
                                        text: "Certificat expire dans \(days)j",
                                        color: days <= 1 ? .red : (days <= 3 ? .orange : .green)
                                    )
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.systemBlack)
                            .frame(height: 2)
                            .padding(.horizontal, 40)
                        
                        // MARK: - Copyright
                        Text("© 2025 David Guia")
                            .font(.geneva9)
                            .foregroundStyle(Color.systemGray)
                            .padding(.bottom, 16)
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
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Composant InfoRow

struct InfoRow: View {
    let icon: String
    let text: String
    var color: Color? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(color ?? Color.systemBlack)
                .fontWeight(color != nil ? .bold : .regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 48)
    }
}

#Preview {
    AboutView(isPresented: .constant(true))
}
