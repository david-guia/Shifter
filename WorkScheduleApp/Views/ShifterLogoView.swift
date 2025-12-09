//
//  ShifterLogoView.swift
//  WorkScheduleApp
//
//  Vue personnalisée pour afficher le logo Shifter SVG
//

import SwiftUI
import WebKit

struct ShifterLogoView: View {
    let height: CGFloat
    
    init(height: CGFloat = 40) {
        self.height = height
    }
    
    var body: some View {
        if let svgPath = Bundle.main.path(forResource: "shifter", ofType: "svg"),
           let svgData = try? Data(contentsOf: URL(fileURLWithPath: svgPath)),
           let svgString = String(data: svgData, encoding: .utf8) {
            
            SVGImageView(svgString: svgString, height: height)
                .frame(height: height)
        } else {
            // Fallback si le SVG ne charge pas
            Text("Shifter")
                .font(.custom("Chicago", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(Color.systemBlack)
        }
    }
}

// Vue UIKit pour afficher le SVG via WKWebView
struct SVGImageView: UIViewRepresentable {
    let svgString: String
    let height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Calcul du ratio (logo 2310x1154 = ratio ~2:1)
        let aspectRatio: CGFloat = 2310.0 / 1154.0
        let width = height * aspectRatio
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    background-color: transparent;
                }
                svg {
                    max-width: 100%;
                    max-height: 100%;
                    width: \(width)px;
                    height: \(height)px;
                }
            </style>
        </head>
        <body>
            \(svgString)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

#Preview {
    ShifterLogoView(height: 40)
        .background(Color(red: 0.75, green: 0.75, blue: 0.75)) // Gris système pour tester
}
