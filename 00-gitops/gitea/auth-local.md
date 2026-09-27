# FARCI — authentification locale Gitea

## Stratégie

Gitea est configuré en mode **authentification locale** (pas de LDAP, pas d'OAuth).
Les comptes sont créés manuellement par l'administrateur ou via `bootstrap.sh`.

## Création d'un utilisateur

```bash
curl -X POST "$GITEA_URL/api/v1/admin/users" \
  -H "Content-Type: application/json" \
  -u "admin:password" \
  -d '{
    "username": "etudiant1",
    "password": "mot-de-passe-temporaire",
    "email": "etudiant1@farci.local",
    "must_change_password": true
  }'
```

## Token d'accès API

Chaque utilisateur peut créer un token d'accès dans :
**Settings → Applications → Generate New Token**

Ce token est utilisé pour :
- `git push` via HTTPS
- Les appels API (création de PR, etc.)

## Sécurité

- `DISABLE_REGISTRATION = true` : pas d'inscription publique
- `REQUIRE_SIGNIN_VIEW = true` : connexion requise pour voir les dépôts
- Les mots de passe sont stockés hashés (bcrypt)
- Les tokens sont stockés hashés

## En cas de perte de mot de passe

```bash
gitea admin user change-password --username <user> --password <new>
```
