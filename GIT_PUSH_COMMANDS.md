# Commandes pour Push sur GitHub

## Étape 1: Vérifier Git
```powershell
git --version
```

Si Git n'est pas installé, télécharge-le depuis: https://git-scm.com/download/win

## Étape 2: Configurer Git (si première fois)
```powershell
git config --global user.name "Ton Nom"
git config --global user.email "ton.email@example.com"
```

## Étape 3: Initialiser le Repo (si pas déjà fait)
```powershell
git init
```

## Étape 4: Ajouter tous les fichiers
```powershell
git add .
```

## Étape 5: Créer un Commit
```powershell
git commit -m "Fix Apple Review issues v1.0.4+8 - Remove guest button, add account deletion, improve permissions"
```

## Étape 6: Ajouter le Remote GitHub (si pas déjà fait)
```powershell
# Remplace USERNAME et REPO par tes valeurs
git remote add origin https://github.com/USERNAME/REPO.git
```

Si le remote existe déjà, vérifie avec:
```powershell
git remote -v
```

## Étape 7: Push vers GitHub
```powershell
# Première fois
git push -u origin main

# Ou si la branche s'appelle master
git push -u origin master

# Fois suivantes
git push
```

## Si tu as des Conflits ou Erreurs

### Erreur: "remote origin already exists"
```powershell
git remote remove origin
git remote add origin https://github.com/USERNAME/REPO.git
```

### Erreur: "failed to push some refs"
```powershell
# Pull d'abord
git pull origin main --rebase

# Puis push
git push origin main
```

### Erreur: "src refspec main does not match any"
Ta branche s'appelle peut-être "master":
```powershell
git branch -M main
git push -u origin main
```

## Créer un Nouveau Repo sur GitHub

1. Va sur https://github.com/new
2. Nomme ton repo (ex: "bright-future-app")
3. Ne coche PAS "Initialize with README"
4. Clique "Create repository"
5. Copie l'URL du repo
6. Utilise les commandes ci-dessus avec cette URL

## Fichiers à Ignorer (.gitignore)

Assure-toi que ton `.gitignore` contient:
```
# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/

# Android
*.jks
*.keystore
key.properties
local.properties

# iOS
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xcuserstate
Pods/

# Secrets
.env
*.log
```

## Résumé des Changements à Commit

Cette version inclut:
- ✅ Suppression du bouton "Continue as Guest"
- ✅ Amélioration des descriptions de permissions iOS
- ✅ Ajout de la page de suppression de compte
- ✅ Création de la Edge Function de suppression
- ✅ Page de support créée
- ✅ Corrections d'overflow sur dashboard
- ✅ Amélioration du design de la page profile
- ✅ Début d'implémentation responsive
- ✅ Version mise à jour: 1.0.4+8

## Commandes Rapides (Copier-Coller)

```powershell
# Tout en une fois
git add .
git commit -m "v1.0.4+8: Apple Review fixes - account deletion, permissions, support page"
git push
```

## Vérifier le Push

Après le push, va sur GitHub et vérifie que tous tes fichiers sont là!
