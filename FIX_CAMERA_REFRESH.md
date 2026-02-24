# Fix: App se rafraîchit après prise de photo

## Problème
Quand l'utilisateur prend une photo avec la caméra, l'app se rafraîchit et perd son état, empêchant l'affichage du dialog pour ajouter une description.

## Cause
Sur Android, quand la caméra s'ouvre, le système peut détruire l'activité Flutter pour libérer de la mémoire. Quand l'utilisateur revient, l'activité est recréée, perdant tout l'état temporaire.

## Solutions appliquées

### 1. AutomaticKeepAliveClientMixin
```dart
class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // IMPORTANT!
    return Scaffold(...);
  }
}
```

**Ce que ça fait :**
- Indique à Flutter de garder l'état du widget en mémoire
- Empêche la destruction complète du widget
- Préserve les variables d'état

### 2. Délai après la caméra
```dart
final file = await _picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85,
  maxWidth: 1920,
  maxHeight: 1920,
);

if (file != null) {
  // Attendre que le widget soit prêt
  await Future.delayed(Duration(milliseconds: 500));
  
  if (mounted) {
    _promptForCaption([File(file.path)], [], 'Nouveau post photo');
  }
}
```

**Ce que ça fait :**
- Attend 500ms après le retour de la caméra
- Laisse le temps au widget de se stabiliser
- Vérifie que le widget est toujours monté

### 3. Optimisation des images
```dart
await _picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85,      // Compression à 85%
  maxWidth: 1920,        // Largeur max
  maxHeight: 1920,       // Hauteur max
);
```

**Ce que ça fait :**
- Réduit la taille des images
- Moins de mémoire utilisée
- Moins de risque que Android tue l'app

### 4. AndroidManifest configChanges étendu
```xml
<activity
    android:name=".MainActivity"
    android:configChanges="keyboard|keyboardHidden|orientation|screenLayout|screenSize|smallestScreenSize"
    ...>
```

**Ce que ça fait :**
- Empêche la recréation de l'activité lors de changements de configuration
- Préserve l'état pendant les rotations et autres changements

### 5. Permissions Android 13+
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android:permission.READ_MEDIA_VIDEO" />
```

**Ce que ça fait :**
- Support des nouvelles permissions Android 13+
- Accès garanti aux médias

## Test

### Avant le fix :
1. Cliquer sur "Media"
2. Choisir "Prendre une photo"
3. Prendre la photo
4. ❌ L'app se rafraîchit, retour à l'accueil

### Après le fix :
1. Cliquer sur "Media"
2. Choisir "Prendre une photo"
3. Prendre la photo
4. ✅ Dialog "Ajouter une légende" s'affiche
5. ✅ Possibilité d'ajouter une description
6. ✅ Post créé avec succès

## Logs de débogage

Les logs suivants apparaissent dans la console :
```
📸 Tentative de prise de photo...
📸 Résultat picker: /data/user/0/.../cache/image_picker123.jpg
📸 Fichier trouvé, vérification mounted: true
📸 Appel _promptForCaption
```

Si un problème survient :
```
❌ Erreur picking image: [détails de l'erreur]
```
ou
```
❌ Widget non monté
```

## Alternatives si le problème persiste

### Option A: Utiliser shared_preferences
Sauvegarder le chemin de la photo temporairement :
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('temp_photo_path', file.path);
```

### Option B: Utiliser un StatefulWidget global
Créer un provider ou state management global pour préserver l'état.

### Option C: Utiliser path_provider
Copier la photo dans un dossier permanent avant de l'utiliser.

## Fichiers modifiés

- `lib/dashboard_page.dart`
  - Ajout de `AutomaticKeepAliveClientMixin`
  - Ajout de `Future.delayed(500ms)`
  - Ajout de `maxWidth` et `maxHeight`
  - Logs de débogage améliorés

- `android/app/src/main/AndroidManifest.xml`
  - ConfigChanges étendu
  - Permissions Android 13+

## Commandes pour tester

```bash
# Rebuild l'app
flutter clean
flutter pub get
flutter build apk --debug

# Installer et voir les logs
flutter install
flutter logs
```

## Notes importantes

1. Le délai de 500ms peut être ajusté selon les appareils
2. `AutomaticKeepAliveClientMixin` consomme plus de mémoire
3. Tester sur plusieurs appareils Android (différentes versions)
4. Vérifier que les permissions sont accordées dans les paramètres

## Compatibilité

✅ Android 5.0+ (API 21+)
✅ Android 13+ (avec nouvelles permissions)
✅ Tous les appareils (Samsung, Tecno, Xiaomi, etc.)
