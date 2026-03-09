# Build iOS sans Mac - Guide Codemagic

## Étape 1: Préparer ton projet

1. Commit et push tous tes changements sur GitHub/GitLab/Bitbucket
```bash
git add .
git commit -m "Fix iOS camera crash - v1.0.3+7"
git push
```

## Étape 2: Configurer Codemagic

1. Va sur https://codemagic.io/signup
2. Connecte-toi avec GitHub/GitLab
3. Clique "Add application"
4. Sélectionne ton repo "bright"
5. Codemagic détecte automatiquement que c'est un projet Flutter

## Étape 3: Configuration iOS

1. Dans Codemagic, va dans "App settings"
2. Section "Build" :
   - Build mode: Release
   - Build iOS: Activé
   
3. Section "Distribution" :
   - Distribution method: App Store Connect
   
4. Ajoute tes certificats iOS :
   - Apple Developer account credentials
   - Distribution certificate
   - Provisioning profile

## Étape 4: Build automatique

1. Clique "Start new build"
2. Sélectionne la branche (main/master)
3. Codemagic va :
   - Builder l'app iOS
   - Signer l'app
   - Uploader sur App Store Connect automatiquement

## Alternative: GitHub Actions (Gratuit)

Si tu préfères GitHub Actions, crée `.github/workflows/ios.yml` :

```yaml
name: iOS Build

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.0'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build iOS
      run: flutter build ios --release --no-codesign
    
    - name: Upload IPA
      uses: actions/upload-artifact@v3
      with:
        name: ios-build
        path: build/ios/iphoneos/Runner.app
```

## Option Rapide: MacinCloud (Payant - $1/heure)

1. Va sur https://www.macincloud.com
2. Loue un Mac pour 1 heure (~$1)
3. Connecte-toi via VNC
4. Clone ton repo
5. Build avec Xcode
6. Soumets à l'App Store

## Recommandation

Pour ton cas, je recommande **Codemagic** car :
- Gratuit pour 500 minutes/mois
- Configuration simple
- Build et soumission automatiques
- Pas besoin de Mac physique
