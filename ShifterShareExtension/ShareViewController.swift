//
//  ShareViewController.swift
//  ShifterShareExtension
//
//  Extension de partage pour importer rapidement des captures d'écran
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupIdentifier = "group.com.davidguia.shifter"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if DEBUG
        print("🟢 ShareViewController loaded!")
        #endif
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1.0) // systemBeige
        
        // Extraire l'image partagée
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let itemProvider = extensionItem.attachments?.first {
            
            #if DEBUG
            print("📦 Found item provider")
            #endif
            handleImageProvider(itemProvider)
        } else {
            #if DEBUG
            print("❌ No extension item found")
            #endif
            showError("Aucune image détectée")
        }
    }
    
    private func handleImageProvider(_ itemProvider: NSItemProvider) {
        // Vérifier si c'est une image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.showError("Erreur: \(error.localizedDescription)")
                        return
                    }
                    
                    var imageToProcess: UIImage?
                    
                    // Gérer différents types de données
                    if let image = item as? UIImage {
                        imageToProcess = image
                    } else if let url = item as? URL {
                        imageToProcess = UIImage(contentsOfFile: url.path)
                    } else if let data = item as? Data {
                        imageToProcess = UIImage(data: data)
                    }
                    
                    if let image = imageToProcess {
                        self.saveImageToSharedContainer(image)
                    } else {
                        self.showError("Format d'image non supporté")
                    }
                }
            }
        } else {
            showError("Veuillez partager une image")
        }
    }
    
    private func saveImageToSharedContainer(_ image: UIImage) {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            #if DEBUG
            print("❌ Cannot access App Group container")
            #endif
            showError("Erreur d'accès au conteneur partagé")
            return
        }
        
        #if DEBUG
        print("📁 Shared container: \(sharedContainer.path)")
        #endif
        
        // Créer un nom de fichier unique
        let fileName = "shared_image_\(UUID().uuidString).png"
        let fileURL = sharedContainer.appendingPathComponent(fileName)
        
        // Sauvegarder l'image
        if let imageData = image.pngData() {
            do {
                try imageData.write(to: fileURL)
                #if DEBUG
                print("✅ Image saved to: \(fileURL.path)")
                #endif
                
                // Notifier l'app principale
                UserDefaults(suiteName: appGroupIdentifier)?.set(fileURL.path, forKey: "pendingImagePath")
                #if DEBUG
                print("✅ Path saved to UserDefaults")
                #endif
                
                UserDefaults(suiteName: appGroupIdentifier)?.set(Date(), forKey: "pendingImageDate")
                #if DEBUG
                print("✅ Date saved: \(Date())")
                #endif
                
                showSuccess()
            } catch {
                #if DEBUG
                print("❌ Write error: \(error)")
                #endif
                showError("Erreur de sauvegarde: \(error.localizedDescription)")
            }
        } else {
            #if DEBUG
            print("❌ Cannot convert image to PNG")
            #endif
            showError("Impossible de convertir l'image")
        }
    }
    
    private func showSuccess() {
        let successView = UIView(frame: view.bounds)
        successView.backgroundColor = view.backgroundColor
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let checkmark = UILabel()
        checkmark.text = "✓"
        checkmark.font = .systemFont(ofSize: 64, weight: .bold)
        checkmark.textColor = UIColor(red: 0.0, green: 0.48, blue: 0.0, alpha: 1.0) // green
        
        let titleLabel = UILabel()
        titleLabel.text = "Image envoyée à Shifter"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .black
        
        let messageLabel = UILabel()
        messageLabel.text = "L'OCR sera lancé au prochain démarrage"
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .darkGray
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        
        stackView.addArrangedSubview(checkmark)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        
        successView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: successView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: successView.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: successView.trailingAnchor, constant: -32)
        ])
        
        view.addSubview(successView)
        
        // Fermer après 1.5 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Erreur", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShifterShareExtension", code: -1))
        })
        present(alert, animated: true)
    }
}
