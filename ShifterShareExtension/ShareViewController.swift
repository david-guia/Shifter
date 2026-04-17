//
//  ShareViewController.swift
//  ShifterShareExtension
//
//  Extension de partage pour importer rapidement des captures d'écran
//

@preconcurrency import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let appGroupIdentifier = "group.com.davidguia.shifter"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppLogger.shared.debug("🟢 ShareViewController loaded!")
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1.0) // systemBeige
        
        // Extraire l'image partagée
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let itemProvider = extensionItem.attachments?.first {
            
            AppLogger.shared.debug("📦 Found item provider")
            handleImageProvider(itemProvider)
        } else {
            AppLogger.shared.error("❌ No extension item found")
            showError("Aucune image détectée")
        }
    }
    
    private func handleImageProvider(_ itemProvider: NSItemProvider) {
        // Vérifier si c'est une image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.showError("Erreur: \(error.localizedDescription)")
                    }
                    return
                }

                // Charger / convertir l'image en arrière-plan pour éviter de bloquer l'UI
                DispatchQueue.global(qos: .userInitiated).async {
                    var imageToProcess: UIImage?

                    // Gérer différents types de données
                    if let image = item as? UIImage {
                        imageToProcess = image
                    } else if let url = item as? URL {
                        if let data = try? Data(contentsOf: url) {
                            imageToProcess = UIImage(data: data)
                        }
                    } else if let data = item as? Data {
                        imageToProcess = UIImage(data: data)
                    }

                    DispatchQueue.main.async {
                        if let image = imageToProcess {
                            self.saveImageToSharedContainer(image)
                        } else {
                            self.showError("Format d'image non supporté")
                        }
                    }
                }
            }
        } else {
            showError("Veuillez partager une image")
        }
    }
    
    private func saveImageToSharedContainer(_ image: UIImage) {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            AppLogger.shared.error("❌ Cannot access App Group container")
            showError("Erreur d'accès au conteneur partagé")
            return
        }
        
        AppLogger.shared.debug("📁 Shared container: \(sharedContainer.path)")
        
        // Créer un nom de fichier unique
        let fileName = "shared_image_\(UUID().uuidString).png"
        let fileURL = sharedContainer.appendingPathComponent(fileName)
        
        // Sauvegarder l'image
        if let imageData = image.pngData() {
            do {
                try imageData.write(to: fileURL)
                AppLogger.shared.info("✅ Image saved to: \(fileURL.path)")
                
                // Notifier l'app principale
                UserDefaults(suiteName: appGroupIdentifier)?.set(fileURL.path, forKey: "pendingImagePath")
                AppLogger.shared.debug("✅ Path saved to UserDefaults")
                
                UserDefaults(suiteName: appGroupIdentifier)?.set(Date(), forKey: "pendingImageDate")
                AppLogger.shared.debug("✅ Date saved: \(Date())")
                
                showSuccess()
            } catch {
                AppLogger.shared.error("❌ Write error: \(error)")
                showError("Erreur de sauvegarde: \(error.localizedDescription)")
            }
        } else {
            AppLogger.shared.error("❌ Cannot convert image to PNG")
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
