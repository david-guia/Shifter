//
//  SystemCSSTheme.swift
//  WorkScheduleApp
//
//  Thème inspiré de system.css - Classic macOS
//

import SwiftUI

// MARK: - Couleurs System.css

extension Color {
    static let systemBeige = Color(red: 0.933, green: 0.933, blue: 0.933)
    static let systemBlack = Color.black
    static let systemWhite = Color.white
    static let systemGray = Color(white: 0.5)
    static let systemDarkGray = Color(white: 0.2)
}

// MARK: - Fonts System.css (Chicago style)

extension Font {
    static let chicago10 = Font.system(size: 10, weight: .bold, design: .monospaced)
    static let chicago12 = Font.system(size: 12, weight: .bold, design: .monospaced)
    static let chicago14 = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let geneva9 = Font.system(size: 9, design: .monospaced)
    static let geneva10 = Font.system(size: 10, design: .monospaced)
}

// MARK: - Composants System.css

/// Fenêtre classique macOS avec barre de titre
struct SystemWindow<Content: View>: View {
    let title: String
    let isActive: Bool
    @Binding var isPresented: Bool
    let content: Content
    
    init(title: String, isActive: Bool = true, isPresented: Binding<Bool> = .constant(true), @ViewBuilder content: () -> Content) {
        self.title = title
        self.isActive = isActive
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre de titre
            SystemTitleBar(title: title, isActive: isActive) {
                isPresented = false
            }
            
            // Séparateur
            Divider()
                .frame(height: 2)
                .background(Color.systemBlack)
            
            // Contenu
            content
                .background(Color.systemWhite)
        }
        .background(Color.systemBlack)
        .border(Color.systemBlack, width: 2)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 4, y: 4)
    }
}

/// Barre de titre macOS classique
struct SystemTitleBar: View {
    let title: String
    let isActive: Bool
    var onClose: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 0) {
            // Close button
            if let onClose = onClose {
                Button(action: onClose) {
                    Rectangle()
                        .fill(Color.systemWhite)
                        .frame(width: 12, height: 12)
                        .border(Color.systemBlack, width: 1)
                }
                .padding(.leading, 6)
            }
            
            Spacer()
            
            // Titre
            Text(title)
                .font(.chicago12)
                .foregroundStyle(isActive ? Color.systemWhite : Color.systemGray)
            
            Spacer()
            
            // Espace pour resize button
            Rectangle()
                .fill(.clear)
                .frame(width: 12, height: 12)
                .padding(.trailing, 6)
        }
        .frame(height: 19)
        .background(
            isActive 
                ? LinearGradient(
                    colors: [.systemBlack, .systemDarkGray, .systemBlack],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                : LinearGradient(
                    colors: [.systemWhite, .systemGray, .systemWhite],
                    startPoint: .leading,
                    endPoint: .trailing
                )
        )
        .overlay(
            // Racing stripes
            HStack(spacing: 2) {
                ForEach(0..<20) { _ in
                    Rectangle()
                        .fill(isActive ? Color.systemWhite.opacity(0.3) : Color.systemBlack.opacity(0.2))
                        .frame(width: 1)
                }
            }
            .padding(.horizontal, 40)
        )
    }
}

/// Bouton classique macOS
struct SystemButton: View {
    let title: String
    let isDefault: Bool
    let isDestructive: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    init(_ title: String, isDefault: Bool = false, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDefault = isDefault
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            Text(title)
                .font(.chicago12)
                .foregroundStyle(isPressed ? Color.systemWhite : (isDestructive ? Color.red : Color.systemBlack))
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(minWidth: 59, minHeight: 20)
                .background(isPressed ? Color.systemBlack : Color.systemWhite)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDefault ? Color.systemBlack : (isDestructive ? Color.red : Color.systemBlack), lineWidth: isDefault ? 3 : 2)
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// Checkbox classique
struct SystemCheckbox: View {
    @Binding var isChecked: Bool
    let label: String
    
    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Rectangle()
                        .fill(Color.systemWhite)
                        .frame(width: 12, height: 12)
                        .border(Color.systemBlack, width: 2)
                    
                    if isChecked {
                        Text("✓")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.systemBlack)
                    }
                }
                
                Text(label)
                    .font(.geneva10)
                    .foregroundStyle(Color.systemBlack)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Champ de texte classique
struct SystemTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.geneva10)
            .padding(4)
            .background(Color.systemWhite)
            .border(Color.systemBlack, width: 1)
            .overlay(
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(Color.systemBlack.opacity(0.3))
                    .padding(2)
            )
    }
}

/// Boîte de dialogue modale classique
struct SystemDialog<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Titre
            Text(title)
                .font(.chicago12)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.systemWhite)
            
            Divider()
                .frame(height: 1)
                .background(Color.systemBlack)
            
            // Contenu
            content
                .padding(16)
                .background(Color.systemWhite)
        }
        .background(Color.systemBlack)
        .border(Color.systemBlack, width: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.systemWhite, lineWidth: 2)
                .padding(2)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, x: 6, y: 6)
    }
}

/// Card avec style rétro
struct SystemCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(12)
            .background(Color.systemWhite)
            .border(Color.systemBlack, width: 2)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.systemGray.opacity(0.3), lineWidth: 1)
                    .padding(1)
            )
    }
}

/// Barre de menu classique (simplifiée pour iOS)
struct SystemMenuBar: View {
    let items: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.chicago12)
                    .foregroundStyle(Color.systemBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                Spacer()
            }
        }
        .frame(height: 20)
        .background(Color.systemWhite)
        .border(Color.systemBlack, width: 1)
    }
}
