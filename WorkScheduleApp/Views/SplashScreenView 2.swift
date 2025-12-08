//
//  SplashScreenView.swift
//  WorkScheduleApp
//
//  Écran de démarrage avec logo Shifter
//

import SwiftUI
import SwiftData

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8
    
    @Binding var sharedImagePath: String?
    
    var body: some View {
        if isActive {
            ContentView(sharedImagePath: $sharedImagePath)
        } else {
            ZStack {
                // Fond beige macOS Classic
                Color.systemBeige
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo Shifter
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                    
                    // Version (optionnel)
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("version : \(version)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.systemBlack.opacity(0.5))
                            .opacity(logoOpacity)
                    }
                }
            }
            .onAppear {
                // Animation d'apparition
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    logoScale = 1.0
                }
                withAnimation(.easeIn(duration: 0.6)) {
                    logoOpacity = 1.0
                }
                
                // Transition vers ContentView après 1.8s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isActive = true
                    }
                }
            }
        }
    }
}
