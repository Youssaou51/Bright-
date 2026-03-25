# État de la Suppression de Compte

## Situation Actuelle

### ❌ Problème Identifié
Quand un utilisateur supprime son compte:
- ✅ Les données de la table `users` sont supprimées
- ✅ Les posts de l'utilisateur sont supprimés
- ✅ L'utilisateur est déconnecté
- ❌ **MAIS** le compte d'authentification Supabase reste actif
- ❌ L'utilisateur peut se reconnecter avec les mêmes identifiants

### 🔧 Solution Implémentée

**Code App (lib/delete_account_page.dart):**
- Supprime les posts
- Supprime les données utilisateur
- Appelle la fonction Edge `deleteAccount` (si elle existe)
- Déconnecte l'utilisateur

**Edge Function (supabase/functions/deleteAccount/index.ts):**
- Utilise la clé service_role pour avoir les permissions admin
- Supprime les données de la base
- **Supprime le compte d'authentification** avec `auth.admin.deleteUser()`

## Actions Requises

### 1. Déployer la Edge Function

```bash
# Installer Supabase CLI
scoop install supabase

# Se connecter
supabase login

# Lier le projet
supabase link --project-ref YOUR_PROJECT_ID

# Déployer
supabase functions deploy deleteAccount
```

### 2. Tester

1. Crée un compte de test
2. Supprime-le via l'app
3. Essaie de te reconnecter
4. ✅ Ça devrait échouer

## Pourquoi C'est Important

### Pour Apple Review
Apple exige que la suppression de compte soit complète. Si l'utilisateur peut se reconnecter après "suppression", Apple rejettera l'app.

### Pour les Utilisateurs
Quand un utilisateur demande la suppression, il s'attend à ce que:
- Toutes ses données soient supprimées
- Il ne puisse plus accéder à son compte
- Son email soit libéré pour créer un nouveau compte

## État Actuel du Code

### ✅ Ce qui Fonctionne
- Interface de suppression dans l'app
- Avertissements et confirmations
- Suppression des données de la base
- Déconnexion de l'utilisateur

### ⚠️ Ce qui Nécessite le Déploiement
- Suppression du compte d'authentification
- Nécessite la Edge Function déployée

## Alternatives

Si tu ne peux pas déployer la fonction immédiatement:

### Option 1: Désactiver le Compte
Au lieu de supprimer, marque le compte comme "deleted":
```dart
await _supabase.from('users').update({
  'deleted_at': DateTime.now().toIso8601String(),
  'email': 'deleted_${userId}@deleted.com',
}).eq('id', userId);
```

Puis dans le login, vérifie si `deleted_at` existe et refuse la connexion.

### Option 2: Support Manuel
Ajoute un message: "Account deletion in progress. Contact support@brightfuture.org to complete."

Puis supprime manuellement via Supabase Dashboard.

## Recommandation

**Pour la soumission Apple:**
1. Déploie la Edge Function (10 minutes)
2. Teste la suppression complète
3. Enregistre une vidéo montrant qu'on ne peut pas se reconnecter
4. Soumets à Apple

**Si tu ne peux pas déployer maintenant:**
1. Utilise l'Option 1 (désactivation)
2. Soumets à Apple avec une note expliquant le processus
3. Déploie la vraie suppression après approbation

## Fichiers Modifiés

- ✅ `lib/delete_account_page.dart` - Interface et logique
- ✅ `supabase/functions/deleteAccount/index.ts` - Fonction de suppression
- ✅ `DEPLOY_DELETE_ACCOUNT_FUNCTION.md` - Guide de déploiement

## Prochaine Étape

Déploie la fonction avec les commandes dans `DEPLOY_DELETE_ACCOUNT_FUNCTION.md`
