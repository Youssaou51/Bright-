# Guide de Soumission App Store - Version 1.0.4+8

## Avant de Soumettre

### 1. Mettre à jour le site de support

Copie le contenu de `SUPPORT_PAGE_CONTENT.md` sur ton site:
- URL: https://bright-future.vercel.app/support
- Assure-toi que la page est accessible et bien formatée

### 2. Préparer l'enregistrement vidéo de suppression de compte

Apple demande un enregistrement montrant le flux complet. Enregistre sur un appareil physique:

**Étapes à montrer:**
1. Ouvre l'app
2. Connecte-toi avec un compte de test
3. Va dans Profile
4. Scroll vers le bas
5. Tape "Delete Account"
6. Montre les avertissements
7. Coche la case de confirmation
8. Tape "Delete My Account"
9. Confirme dans le dialog
10. Montre que l'utilisateur est déconnecté

**Outils d'enregistrement:**
- iOS: Enregistrement d'écran intégré (Centre de contrôle)
- Durée: 30-60 secondes
- Format: MP4 ou MOV

### 3. Build l'application

Sur un Mac avec Xcode:

```bash
# Nettoyer
flutter clean
flutter pub get

# Installer les pods
cd ios
pod install
cd ..

# Builder
flutter build ios --release
```

Puis dans Xcode:
1. Ouvre `ios/Runner.xcworkspace`
2. Product > Archive
3. Distribute App > App Store Connect

## Informations pour App Store Connect

### App Review Information

**Notes pour la Review:**
```
Version 1.0.4 addresses all issues from previous review:

1. GUEST BUTTON: Fixed - Now navigates to dashboard
2. CAMERA PERMISSIONS: Enhanced with specific use case examples
3. ACCOUNT DELETION: Implemented - Full deletion flow available in Profile
4. SUPPORT URL: Updated with comprehensive support information

DEMO ACCOUNT:
Email: demo@brightfuture.org
Password: Demo123!

ACCOUNT DELETION DEMO:
A screen recording demonstrating the complete account deletion flow is attached.

All features have been tested on iPad Air 11-inch (M3) with iPadOS 26.3.1.
```

### What's New in This Version (Release Notes)

**Français:**
```
Corrections importantes suite aux retours d'Apple:
• Bouton "Continuer en tant qu'invité" maintenant fonctionnel
• Descriptions de permissions améliorées avec exemples concrets
• Ajout de la suppression de compte dans les paramètres du profil
• Page de support mise à jour avec FAQ et informations de contact
```

**English:**
```
Important fixes based on Apple's feedback:
• "Continue as Guest" button now works properly
• Enhanced permission descriptions with specific examples
• Added account deletion feature in Profile settings
• Updated support page with FAQ and contact information
```

## Checklist de Soumission

- [ ] Version mise à jour: 1.0.4+8
- [ ] Site de support mis à jour et accessible
- [ ] Vidéo de suppression de compte enregistrée
- [ ] App buildée et archivée dans Xcode
- [ ] Compte de démo créé et testé
- [ ] Release notes rédigées
- [ ] Notes pour la review complétées
- [ ] Vidéo uploadée dans App Store Connect

## Réponse aux Questions d'Apple

Si Apple pose des questions, voici les réponses:

**Q: Comment les utilisateurs suppriment-ils leur compte?**
R: Users can delete their account by going to Profile > Delete Account. The flow includes warnings, confirmation, and complete data removal.

**Q: Pourquoi avez-vous besoin d'accès à la caméra?**
R: Users can take photos and videos to share with the community, capture event moments, and set profile pictures. The permission description now includes these specific examples.

**Q: Le bouton guest fonctionne-t-il?**
R: Yes, it now navigates users to the dashboard where they can browse content without creating an account.

## Après la Soumission

1. Surveille les emails d'Apple
2. Réponds rapidement si Apple a des questions
3. Le délai de review est généralement 24-48 heures
4. Si rejeté, lis attentivement les raisons et corrige

## Contact Support Apple

Si tu as besoin d'aide:
- App Store Connect: "Contact Us"
- Developer Forums: https://developer.apple.com/forums/
- Phone: Request callback in App Store Connect

## Prochaines Étapes Après Approbation

1. L'app sera disponible sur l'App Store
2. Surveille les reviews et ratings
3. Réponds aux commentaires des utilisateurs
4. Planifie les prochaines mises à jour

Bonne chance! 🚀
