---
name: Anomalie
about: Signaler un comportement inattendu d'un service ou d'un test
labels: bug
---

## Ce que j'attendais

<!-- Le comportement attendu, en une phrase. -->

## Ce que j'ai obtenu

<!-- Le comportement observé : le message d'erreur exact, pas un résumé. -->

## Comment reproduire

```bash
# Les commandes exactes, dans l'ordre.
./bin/farci status
```

## Environnement

<!-- Ne pas oublier l'adresse IP : elle change d'un poste à l'autre. -->

- Adresse du poste (`ip_var` dans `config/services.yaml`) :
- Rôle (`FARCI_ROLE` dans `config/workshop.env`) :
- Service concerné :
- Machine : nombre de cœurs, RAM
- `./bin/farci version` :

## Est-ce que cela arrive sans Internet ?

- [ ] oui, le service est coupé / réseau de la salle indisponible
- [ ] non, il faut être connecté

## Étendue

- [ ] un seul service
- [ ] toute la chaîne
- [ ] uniquement sur ma machine
- [ ] sur toutes les machines de l'équipe

## Ce que j'ai déjà essayé

<!-- Essayer avant de signaler fait gagner du temps à tout le monde. -->
