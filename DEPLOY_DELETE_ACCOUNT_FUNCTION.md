# Déployer la Fonction de Suppression de Compte

## Problème
Actuellement, quand un utilisateur supprime son compte, seules les données de la base de données sont supprimées, mais le compte d'authentification Supabase reste actif. L'utilisateur peut donc se reconnecter.

## Solution
Créer une Edge Function Supabase qui utilise la clé service_role pour supprimer complètement le compte d'authentification.

## Étapes de Déploiement

### 1. Installer Supabase CLI

```bash
# Windows (avec Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Ou télécharger depuis
# https://github.com/supabase/cli/releases
```

### 2. Se Connecter à Supabase

```bash
supabase login
```

### 3. Lier le Projet

```bash
# Obtenir l'ID du projet depuis Supabase Dashboard > Settings > General
supabase link --project-ref YOUR_PROJECT_ID
```

### 4. Déployer la Fonction

```bash
supabase functions deploy deleteAccount
```

### 5. Vérifier le Déploiement

Dans Supabase Dashboard:
1. Va dans "Edge Functions"
2. Tu devrais voir "deleteAccount"
3. Vérifie que le statut est "Active"

## Test de la Fonction

### Test depuis l'App

1. Crée un compte de test
2. Va dans Profile > Delete Account
3. Confirme la suppression
4. Essaie de te reconnecter avec les mêmes identifiants
5. ✅ Tu ne devrais PAS pouvoir te reconnecter

### Test Manuel (optionnel)

```bash
# Obtenir un token d'authentification
# Depuis l'app, log le token: print(_supabase.auth.currentSession?.accessToken)

curl -X POST \
  'https://YOUR_PROJECT_ID.supabase.co/functions/v1/deleteAccount' \
  -H 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  -H 'Content-Type: application/json'
```

## Alternative: Suppression via Dashboard

Si tu ne peux pas déployer la fonction, tu peux supprimer manuellement les comptes:

1. Va dans Supabase Dashboard
2. Authentication > Users
3. Trouve l'utilisateur
4. Clique sur les 3 points > Delete user

Mais cette méthode n'est pas automatique et ne respecte pas les exigences d'Apple.

## Vérification des Permissions

Assure-toi que la fonction a accès à la clé service_role:

1. Supabase Dashboard > Settings > API
2. Copie la clé "service_role" (pas la clé "anon"!)
3. La fonction utilise automatiquement `SUPABASE_SERVICE_ROLE_KEY` qui est injectée par Supabase

## Sécurité

✅ La fonction vérifie que l'utilisateur est authentifié
✅ Un utilisateur ne peut supprimer que son propre compte
✅ La clé service_role n'est jamais exposée au client
✅ Toutes les données associées sont supprimées

## Dépannage

**Erreur: "Function not found"**
- Vérifie que la fonction est déployée: `supabase functions list`
- Redéploie: `supabase functions deploy deleteAccount`

**Erreur: "Unauthorized"**
- Vérifie que l'utilisateur est connecté
- Vérifie que le token est valide

**L'utilisateur peut toujours se connecter**
- Vérifie que la fonction s'exécute sans erreur
- Regarde les logs: Supabase Dashboard > Edge Functions > deleteAccount > Logs
- Vérifie que `auth.admin.deleteUser()` est appelé

## Code de la Fonction

La fonction est dans: `supabase/functions/deleteAccount/index.ts`

Elle fait:
1. Vérifie l'authentification de l'utilisateur
2. Supprime les posts de l'utilisateur
3. Supprime les données utilisateur
4. **Supprime le compte d'authentification** (la partie importante!)

## Après le Déploiement

L'app essaiera automatiquement d'appeler cette fonction. Si elle n'existe pas, elle supprimera quand même les données (mais pas le compte auth).

Une fois déployée, la suppression sera complète et l'utilisateur ne pourra plus se reconnecter.
