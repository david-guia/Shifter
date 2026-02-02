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
    
    // État pour l'icône sélectionnée
    @State private var selectedIcon: AppIcon = .current
    @State private var isChangingIcon = false
    
    // Récupérer la version depuis Info.plist
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var copyrightYear: String {
        let currentYear = Calendar.current.component(.year, from: Date())
        return "2025 - \(currentYear)"
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
                    VStack(spacing: 14) {
                        // MARK: - Logo et nom de l'app
                        VStack(spacing: 10) {
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

                            // Title removed for a cleaner look (per user request)
                            Text("Version \(appVersion) (Build \(buildNumber))")
                                .font(.geneva10)
                                .foregroundStyle(Color.systemGray)
                        }
                        .padding(.top, 12)
                        
                        // MARK: - Description
                        VStack(spacing: 6) {
                            Text("Gestion d'horaires de travail")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.systemBlack)
                            
                            Text("Importez vos captures d'écran WorkJam\net visualisez vos statistiques")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.systemGray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
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
                                        .font(.system(size: 22))
                                    Text("Design macOS Classic (system.css)")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.blue)
                                        .underline()
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
                        
                        Spacer()
                        
                        // Ligne séparatrice (emplacement du trait rouge)
                        Rectangle()
                            .fill(Color.systemBlack)
                            .frame(height: 2)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 8)

                        // MARK: - Copyright
                        Text("© \(copyrightYear) David Guia")
                            .font(.geneva10)
                            .foregroundStyle(Color.systemGray)
                        
                        // MARK: - Sélecteur d'icônes
                        VStack(spacing: 10) {
                            Text("Icône de l'app")
                                .font(.chicago12)
                                .foregroundStyle(Color.systemBlack)
                                .padding(.top, 8)
                            
                            HStack(spacing: 16) {
                                ForEach(AppIcon.allCases, id: \.self) { icon in
                                    IconSelectionButton(
                                        icon: icon,
                                        isSelected: selectedIcon == icon
                                    ) {
                                        changeAppIcon(to: icon)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer()
                    }
                }
                
                // MARK: - Bouton GitHub
                Button {
                    if let url = URL(string: "https://github.com/david-guia/Shifter") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("🔗")
                            .font(.system(size: 20))
                        Text("Voir sur GitHub")
                            .font(.chicago12)
                            .foregroundStyle(Color.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.systemWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            // Détecter l'icône actuellement utilisée
            selectedIcon = AppIcon.current
        }
    }
    
    // MARK: - Fonction pour changer l'icône
    private func changeAppIcon(to icon: AppIcon) {
        guard UIApplication.shared.supportsAlternateIcons else { 
            print("⚠️ Les icônes alternatives ne sont pas supportées")
            return 
        }
        
        // Éviter de changer si c'est déjà l'icône active ou si un changement est en cours
        if selectedIcon == icon || isChangingIcon {
            return
        }
        
        isChangingIcon = true
        let previousIcon = selectedIcon
        selectedIcon = icon
        
        #if targetEnvironment(simulator)
        // Dans le simulateur, le changement peut échouer - utiliser un délai plus long
        let delay = 1.0
        #else
        // Sur appareil réel, un délai plus court suffit
        let delay = 0.5
        #endif
        
        // Délai pour éviter l'erreur "Ressources temporairement indisponibles"
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIApplication.shared.setAlternateIconName(icon.iconName) { error in
                DispatchQueue.main.async {
                    isChangingIcon = false
                    
                    if let error = error {
                        print("❌ Erreur lors du changement d'icône: \(error.localizedDescription)")
                        #if targetEnvironment(simulator)
                        print("ℹ️ Note: Le changement d'icône peut ne pas fonctionner correctement dans le simulateur.")
                        print("   Veuillez tester sur un appareil iOS physique pour un résultat optimal.")
                        #endif
                        // Revenir à l'icône précédente en cas d'erreur
                        selectedIcon = previousIcon
                    } else {
                        print("✅ Icône changée avec succès vers: \(icon.displayName)")
                    }
                }
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
                .font(.system(size: 22))
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(color ?? Color.systemBlack)
                .fontWeight(color != nil ? .bold : .regular)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 48)
    }
}

// MARK: - Enum pour les icônes d'app

enum AppIcon: String, CaseIterable {
    case dark = "Dark"
    case tinted = "Tinted"
    
    var iconName: String? {
        switch self {
        case .dark:
            return "AppIcon-Dark"
        case .tinted:
            return "AppIcon-Tinted"
        }
    }
    
    var displayName: String {
        switch self {
        case .dark:
            return "Dark"
        case .tinted:
            return "Tinted"
        }
    }
    
    var previewImageName: String {
        switch self {
        case .dark:
            return "ShiftGrabber_Icon_Dark-1024"
        case .tinted:
            return "ShiftGrabber_Icon_Tinted-1024"
        }
    }
    
    static var current: AppIcon {
        let iconName = UIApplication.shared.alternateIconName
        return AppIcon.allCases.first { $0.iconName == iconName } ?? .dark
    }
}

// MARK: - Composant IconSelectionButton

struct IconSelectionButton: View {
    let icon: AppIcon
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let uiImage = UIImage(named: icon.previewImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.blue : Color.systemBlack, lineWidth: isSelected ? 3 : 2)
                        )
                        .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: isSelected ? 6 : 2, x: 0, y: 2)
                }
                
                Text(icon.displayName)
                    .font(.geneva9)
                    .foregroundStyle(isSelected ? Color.blue : Color.systemGray)
                    .fontWeight(isSelected ? .bold : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutView(isPresented: .constant(true))
}
