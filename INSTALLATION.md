# 📱 Installation de Shifter

## ⚠️ Important

Shifter utilise un **certificat développeur gratuit** qui nécessite une installation via Xcode. L'application **n'est pas disponible sur l'App Store** pour le moment.

---

## 🚀 Installation depuis le Code Source

### Prérequis

- **Mac** avec macOS Sonoma 14.0+
- **Xcode** 16.0+ ([Télécharger](https://developer.apple.com/xcode/))
- **iPhone** avec iOS 18.0+
- **Compte Apple** (gratuit)

### Étapes d'Installation

#### 1. Télécharger le Code Source

**Option A : Via Git**
```bash
git clone https://github.com/david-guia/Shifter.git
cd Shifter
```

**Option B : Via ZIP**
1. Aller sur https://github.com/david-guia/Shifter/releases
2. Télécharger `Source code (zip)` de la dernière version
3. Décompresser le fichier

#### 2. Ouvrir le Projet

```bash
open WorkScheduleApp.xcodeproj
```

#### 3. Configurer Xcode

**a) Sélectionner votre Équipe**
1. Cliquer sur le projet `WorkScheduleApp` dans la barre latérale
2. Sélectionner la target **WorkScheduleApp**
3. Onglet **Signing & Capabilities**
4. Dans **Team**, choisir votre compte Apple personnel
5. Activer **Automatically manage signing**

**⚠️ Répéter pour :**
- Target **ShifterWidget**
- Target **ShifterShareExtension**

**b) Modifier l'App Group (Obligatoire)**

L'App Group `group.com.davidguia.shifter` n'est **pas disponible** pour vous. Vous devez créer le vôtre :

1. Dans **Signing & Capabilities** de **WorkScheduleApp** :
   - Cliquer sur **App Groups**
   - Décocher `group.com.davidguia.shifter`
   - Cliquer **+** → Créer `group.votreidentifiant.shifter` (ex: `group.john.shifter`)
   - Cocher votre nouveau groupe

2. **Répéter pour ShifterWidget et ShifterShareExtension**

3. **Modifier le code** :

Ouvrir les fichiers suivants et remplacer `group.com.davidguia.shifter` par **votre App Group** :

**Fichier 1 : `WorkScheduleApp/WorkScheduleAppApp.swift` (ligne 21)**
```swift
// Avant
guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.davidguia.shifter") else {

// Après (remplacer par VOTRE groupe)
guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.votreidentifiant.shifter") else {
```

**Fichier 2 : `ShifterWidget/WidgetDataProvider.swift` (ligne 14)**
```swift
// Avant
private let appGroupIdentifier = "group.com.davidguia.shifter"

// Après
private let appGroupIdentifier = "group.votreidentifiant.shifter"
```

**Fichier 3 : `ShifterShareExtension/ShareViewController.swift`** (si présent)
```swift
// Remplacer toutes les occurrences de group.com.davidguia.shifter
```

#### 4. Installer sur iPhone

1. **Connecter** votre iPhone via USB
2. **Déverrouiller** l'iPhone et faire confiance à l'ordinateur
3. Dans Xcode, en haut à gauche, sélectionner **votre iPhone** (pas "Any iOS Device")
4. Cliquer sur **Product → Run** (ou ⌘R)

#### 5. Autoriser l'App sur iPhone

Au premier lancement, iOS affichera une erreur. C'est normal !

1. Sur iPhone : **Réglages → Général → Gestion des appareils**
2. Toucher votre **compte développeur**
3. Toucher **Faire confiance à "[Votre Nom]"**
4. Confirmer
5. Relancer l'app depuis l'écran d'accueil

---

## ⚠️ Limitation du Certificat Gratuit

### Expiration après 7 Jours

Les certificats gratuits expirent tous les **7 jours**. L'app affichera :

| Jours Restants | Badge | Action |
|----------------|-------|--------|
| 6-7 jours | 🟢 Vert | Aucune |
| 2-3 jours | 🟠 Orange | Prévention |
| 0-1 jour | 🔴 Rouge | Réinstaller |

### Comment Réinstaller

Après expiration, il suffit de :

```bash
# Dans Xcode
Product → Clean Build Folder (⇧⌘K)
Product → Run (⌘R)
```

**Vos données sont sauvegardées** grâce au backup automatique JSON ! Elles seront restaurées automatiquement.

---

## 🛠️ Dépannage

### Problème 1 : "Failed to register bundle identifier"

**Cause** : L'identifiant de bundle `com.davidguia.shifter` est déjà pris.

**Solution** :
1. Dans Xcode, sélectionner la target **WorkScheduleApp**
2. Onglet **General**
3. Changer **Bundle Identifier** : `com.VOTREPRENOM.shifter`
4. Répéter pour **ShifterWidget** et **ShifterShareExtension**

### Problème 2 : "Widget vide malgré les données"

**Cause** : App Group mal configuré.

**Solution** : Vérifier que les 3 fichiers `.swift` utilisent **le même App Group** que celui coché dans Xcode.

### Problème 3 : "App crash au lancement"

**Cause** : Certificat expiré ou App Group manquant.

**Solution** :
1. Vérifier que l'App Group est créé et coché
2. Rebuilder : `Product → Clean Build Folder` puis `Run`

---

## 📚 Ressources

- **GitHub** : https://github.com/david-guia/Shifter
- **Issues** : https://github.com/david-guia/Shifter/issues
- **README** : [Documentation complète](README.md)

---

## 💡 Alternative : Compte Développeur Payant

Si vous souhaitez **éviter la réinstallation tous les 7 jours**, vous pouvez souscrire au **Apple Developer Program** (99 €/an) :

✅ Certificat valide **1 an**  
✅ Distribution **TestFlight** (beta publique)  
✅ Publication **App Store** possible  

[S'inscrire au Developer Program](https://developer.apple.com/programs/)

---

<p align="center">
  <strong>Besoin d'aide ?</strong> Ouvrez une <a href="https://github.com/david-guia/Shifter/issues">issue sur GitHub</a>
</p>
