# Script PowerShell pour fixer le build iOS

Write-Host "Nettoyage complet du projet..." -ForegroundColor Yellow

# Clean Flutter
flutter clean

# Supprimer les fichiers de cache iOS
if (Test-Path "ios/Pods") {
    Remove-Item -Recurse -Force "ios/Pods"
    Write-Host "✓ Pods supprimés" -ForegroundColor Green
}

if (Test-Path "ios/Podfile.lock") {
    Remove-Item -Force "ios/Podfile.lock"
    Write-Host "✓ Podfile.lock supprimé" -ForegroundColor Green
}

if (Test-Path "ios/.symlinks") {
    Remove-Item -Recurse -Force "ios/.symlinks"
    Write-Host "✓ Symlinks supprimés" -ForegroundColor Green
}

if (Test-Path "ios/Runner.xcworkspace") {
    Remove-Item -Recurse -Force "ios/Runner.xcworkspace"
    Write-Host "✓ Workspace supprimé" -ForegroundColor Green
}

# Get dependencies
Write-Host "`nInstallation des dépendances Flutter..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n✓ Nettoyage terminé!" -ForegroundColor Green
Write-Host "`nMaintenant, sur un Mac, exécute:" -ForegroundColor Cyan
Write-Host "  cd ios" -ForegroundColor White
Write-Host "  pod install" -ForegroundColor White
Write-Host "  cd .." -ForegroundColor White
Write-Host "  flutter build ios --release" -ForegroundColor White
