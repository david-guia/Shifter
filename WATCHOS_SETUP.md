# 📝 Instructions de Configuration watchOS

## 🎯 Objectif
Ajouter la target watchOS à Shifter pour afficher le **Top 3 des shifts** sur Apple Watch.

---

## 🛠️ Étapes de Configuration dans Xcode

### 1. Créer la Target watchOS

1. **Ouvrir le projet** : `WorkScheduleApp.xcodeproj`

2. **Ajouter une Watch App** :
   - `File` → `New` → `Target...`
   - Sélectionner **"Watch App"**
   - Remplir les champs :
     - **Product Name** : `ShifterWatch`
     - **Organization Identifier** : `com.davidguia`
     - **Bundle Identifier** : `com.davidguia.WorkScheduleApp.ShifterWatch`
     - **Team** : Votre compte Apple
     - **Language** : Swift
     - **Minimum Deployment** : watchOS 10.0
   - Décocher "Include Notification Scene"
   - Cliquer **Finish**

3. **Xcode créera automatiquement** :
   - Target `ShifterWatch Watch App`
   - Scheme `ShifterWatch Watch App`

### 2. Organiser les Fichiers

1. **Supprimer les fichiers par défaut** créés par Xcode :
   - `ContentView.swift` (dans ShifterWatch Watch App/)
   - Garder uniquement `Assets.xcassets`

2. **Ajouter les fichiers watchOS créés** :
   - Glisser-déposer dans Xcode :
     - `ShifterWatchApp.swift`
     - `WatchDataManager.swift`
     - `Top3View.swift`
   - **Target Membership** : Cocher `ShifterWatch Watch App`

3. **Ajouter WatchConnectivityManager à iPhone** :
   - Créer dossier `Managers/` dans `WorkScheduleApp/`
   - Ajouter `WatchConnectivityManager.swift`
   - **Target Membership** : Cocher `WorkScheduleApp`

### 3. Configurer les Capabilities

#### **Pour WorkScheduleApp (iPhone)** :
1. Sélectionner target **WorkScheduleApp**
2. Onglet **Signing & Capabilities**
3. Cliquer **+ Capability**
4. Ajouter **"Background Modes"**
5. Cocher :
   - ☑️ **Remote notifications** (optionnel)
   - ☑️ **Background fetch** (optionnel)

#### **Pour ShifterWatch Watch App** :
1. Sélectionner target **ShifterWatch Watch App**
2. Onglet **Signing & Capabilities**
3. **Team** : Choisir votre compte Apple
4. **Automatically manage signing** : Activer
5. Pas de capability supplémentaire requise

### 4. Configurer Info.plist watchOS

1. Sélectionner `ShifterWatch Watch App/Info.plist`
2. Ajouter les clés suivantes (si absentes) :

```xml
<key>WKApplication</key>
<true/>
<key>WKCompanionAppBundleIdentifier</key>
<string>com.davidguia.WorkScheduleApp</string>
```

### 5. Mettre à Jour le Code Existant

Les modifications ont déjà été faites dans :
- ✅ `ScheduleViewModel.swift` (ajout `syncToWatch()`)
- ✅ `WorkScheduleAppApp.swift` (activation WatchConnectivity au lancement)

**Si non fait, ajouter dans `WorkScheduleAppApp.swift`** :

```swift
import SwiftUI
import SwiftData

@main
struct WorkScheduleAppApp: App {
    // ... code existant ...
    
    init() {
        // 🆕 Activer WatchConnectivity
        WatchConnectivityManager.shared
    }
    
    var body: some Scene {
        // ... code existant ...
    }
}
```

---

## 🧪 Test sur Simulateur

### 1. Préparer les Simulateurs

1. **Créer paire iPhone + Watch** :
   - Xcode → `Window` → `Devices and Simulators`
   - Onglet **Simulators**
   - Cliquer **+** (en bas à gauche)
   - Sélectionner :
     - **Device Type** : Apple Watch Series 9 (45mm)
     - **Paired with** : iPhone 15 Pro
   - Cliquer **Create**

### 2. Lancer les Apps

**Méthode automatique (recommandée)** :
1. Sélectionner scheme **ShifterWatch Watch App**
2. Device : iPhone 15 Pro + Apple Watch Series 9
3. Cliquer **Run** (⌘R)
4. Xcode lance automatiquement :
   - L'app iPhone en arrière-plan
   - L'app Watch au premier plan

**Méthode manuelle** :
1. Lancer d'abord l'app iPhone :
   - Scheme : `WorkScheduleApp`
   - Device : iPhone 15 Pro
   - Run (⌘R)
   
2. Puis lancer l'app Watch :
   - Scheme : `ShifterWatch Watch App`
   - Device : Apple Watch Series 9
   - Run (⌘R)

### 3. Tester la Synchronisation

1. **Sur iPhone** :
   - Importer un planning (OCR)
   - Vérifier dans Console Xcode :
     ```
     ✅ WatchConnectivity activé
     ✅ Top 3 envoyé à la Watch: Q2 2025
     ```

2. **Sur Watch** :
   - Observer l'app rafraîchir automatiquement
   - Vérifier Console :
     ```
     ✅ WatchConnectivity activé sur Watch
     📲 Réception données iPhone...
     ✅ Top 3 reçu: 3 shifts
     ```

3. **Interaction Watch** :
   - **Tap écran** : Toggle heures ↔ pourcentages
   - Vérifier animations smooth

---

## 📱 Test sur Appareils Physiques

### Prérequis
- iPhone avec iOS 18.0+
- Apple Watch avec watchOS 10.0+
- Watch **jumelée** avec iPhone

### Installation

1. **Connecter iPhone** via USB

2. **Build iPhone** :
   - Scheme : `WorkScheduleApp`
   - Device : Votre iPhone
   - Run (⌘R)

3. **Build Watch** (automatique) :
   - Scheme : `ShifterWatch Watch App`
   - Device : Votre Apple Watch
   - Run (⌘R)
   - ⚠️ Watch doit être **déverrouillée** pendant install

4. **Autoriser sur iPhone** :
   - Réglages → Général → Gestion des appareils
   - Faire confiance au développeur

5. **Autoriser sur Watch** (si nécessaire) :
   - Réglages (Watch) → Général → Gestion des profils

### Vérification

1. Import shifts sur iPhone
2. Attendre 2-5 secondes
3. Ouvrir app Watch → Top 3 doit apparaître
4. Tap écran → Toggle heures/pourcentages

---

## 🐛 Dépannage

### Problème : "No paired watch found"

**Solution** :
- Simulateur : Recréer paire iPhone+Watch
- Physique : Vérifier jumelage dans app Watch (iPhone)

### Problème : "Watch app ne reçoit pas les données"

**Solutions** :
1. Vérifier iPhone et Watch sur **même WiFi** (physique)
2. Vérifier Console Xcode :
   ```
   ✅ WatchConnectivity activé
   ```
3. Relancer les 2 apps
4. Importer un nouveau shift pour déclencher sync

### Problème : "Build failed - Bundle Identifier already in use"

**Solution** :
Modifier Bundle ID dans target `ShifterWatch Watch App` :
- De : `com.davidguia.WorkScheduleApp.ShifterWatch`
- À : `com.VOTREPRENOM.WorkScheduleApp.ShifterWatch`

---

## 📊 Architecture Finale

```
iPhone (WorkScheduleApp)
    ├── Models/ (SwiftData)
    ├── ViewModels/
    │   └── ScheduleViewModel.swift (trigger sync)
    ├── Managers/
    │   └── WatchConnectivityManager.swift (envoi data)
    └── Services/
        └── OCRService.swift
            ↓
     WatchConnectivity
            ↓
Apple Watch (ShifterWatch)
    ├── ShifterWatchApp.swift (entry point)
    ├── WatchDataManager.swift (réception data)
    ├── Top3View.swift (UI)
    └── Cache (UserDefaults)
```

---

## ✅ Checklist Finale

- [ ] Target `ShifterWatch Watch App` créée
- [ ] Fichiers watchOS ajoutés avec bon Target Membership
- [ ] `WatchConnectivityManager.swift` dans target iPhone
- [ ] Capabilities configurées
- [ ] `WorkScheduleAppApp.swift` initialise WatchConnectivity
- [ ] Test simulateur : iPhone + Watch pairés
- [ ] Test sync : Import shift → Watch reçoit Top 3
- [ ] Test interaction : Tap toggle heures/pourcentages
- [ ] Test physique (optionnel) : iPhone + Watch réels

---

## 🚀 Prêt pour la Release !

Une fois tout validé :
1. Commit les nouveaux fichiers
2. Tag version `v1.1.0-watchos`
3. Push sur GitHub
4. Créer release avec notes watchOS

**Temps estimé** : 30-45 min de configuration + 15 min de tests = **~1h total**
