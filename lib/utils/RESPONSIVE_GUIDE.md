# Guide d'utilisation du système Responsive

## Import
```dart
import 'utils/responsive.dart';
```

## Fonctions disponibles

### 1. Dimensions d'écran
```dart
Responsive.width(context)   // Largeur de l'écran
Responsive.height(context)  // Hauteur de l'écran
```

### 2. Type d'appareil
```dart
Responsive.isMobile(context)   // < 600px
Responsive.isTablet(context)   // 600-900px
Responsive.isDesktop(context)  // > 900px
```

### 3. Tailles de police responsives
```dart
// Ajuste automatiquement selon la taille d'écran
Text(
  'Hello',
  style: TextStyle(fontSize: Responsive.sp(context, 16)),
)
```

### 4. Espacement en pourcentage
```dart
// Largeur en pourcentage
SizedBox(width: Responsive.wp(context, 50))  // 50% de la largeur

// Hauteur en pourcentage
SizedBox(height: Responsive.hp(context, 10))  // 10% de la hauteur
```

### 5. Padding responsive
```dart
// Padding de page (16/24/32 selon l'appareil)
Padding(
  padding: Responsive.pagePadding(context),
  child: YourWidget(),
)

// Padding de carte (12/16/20 selon l'appareil)
Padding(
  padding: Responsive.cardPadding(context),
  child: YourCard(),
)
```

### 6. Tailles d'icônes responsives
```dart
Icon(
  Icons.home,
  size: Responsive.iconSize(context, base: 24),
)
```

## Exemples d'utilisation

### Container responsive
```dart
Container(
  width: Responsive.wp(context, 90),  // 90% de la largeur
  height: Responsive.hp(context, 20), // 20% de la hauteur
  padding: Responsive.pagePadding(context),
  child: Text(
    'Responsive Text',
    style: TextStyle(
      fontSize: Responsive.sp(context, 18),
    ),
  ),
)
```

### Layout conditionnel
```dart
if (Responsive.isMobile(context)) {
  return Column(children: widgets);
} else {
  return Row(children: widgets);
}
```

### Spacing responsive
```dart
Column(
  children: [
    Widget1(),
    SizedBox(height: Responsive.hp(context, 2)), // 2% de hauteur
    Widget2(),
  ],
)
```

## Bonnes pratiques

1. Utilisez `Responsive.sp()` pour toutes les tailles de police
2. Utilisez `Responsive.wp()` et `Responsive.hp()` pour les espacements
3. Utilisez les padding prédéfinis pour la cohérence
4. Testez sur différentes tailles d'écran (petit, moyen, grand)
5. Utilisez les conditions isMobile/isTablet/isDesktop pour des layouts différents

## Tailles d'écran de référence

- Petit mobile: 320-360px
- Mobile standard: 360-400px
- Grand mobile: 400-600px
- Tablette: 600-900px
- Desktop: 900px+
