# Contribuer à FARCI

FARCI est un atelier **GitOps** : la forge n'est pas une décoration, c'est l'outil
de travail. Tout ce qui n'est pas versionné n'existe pas pour l'étape 1.

---

## Le cycle de travail d'une équipe

```
1. copier   cp .env.example .env && cp config/network.env.example config/network.env
2. vérifier ./bin/farci doctor && ./bin/farci bootstrap
3. créer    git switch -c feat/equipe-N/ma-brique
4. déployer la brique
5. tester   le test contractuel de l'équipe (scripts/cmd/../tests)
6. commit   messages explicites, un changement par commit
7. ouvrir   une Pull Request vers main
8. faire intégrer, puis vérifier la sonde verte sur le dashboard
```

La branche `main` est protégée : **aucun push direct n'est accepté**. C'est la
seule façon de s'assurer qu'un student qui casse la plateforme ne casse pas les
autres.

---

## Conventions de nommage

| Objet | Forme | Exemple |
|---|---|---|
| Branche | `feat/equipe-N/sujet` | `feat/equipe-2/llamacpp-gguf` |
| Branche de correction | `fix/equipe-N/sujet` | `fix/equipe-1/caddy-healthz` |
| Commit | `équipe-N : sujet à l'impératif` | `équipe-2 : monte le GGUF partagé dans llama.cpp` |
| Image Docker construite | `farci/<service>:<version>` | `farci/llamacpp:server-b10600` |
| Fichier de test | `tests/test_<sujet>.sh` | `tests/test_inference_contract.sh` |

---

## Règles absolues

Ces règles sont vérifiées automatiquement par `./bin/farci lint`. Une Pull
Request qui les enfreint ne peut pas être intégrée.

1. **Jamais `latest`**, jamais `main`, jamais un tag flottant.
   Toutes les versions passent par `versions.env`.
2. **Aucune adresse IP en dur** hors de `config/`. On utilise `${VARIABLE}`.
3. **Aucun appel sortant** : ni CDN, ni police distante, ni script distant,
   ni `pull_policy: always`. L'atelier fonctionne sans Internet.
4. **Aucun secret commité** : `.env` et `config/network.env` sont ignorés par Git.
5. **Aucun marqueur de travail livré** (`TODO`, `FIXME`, code vide).
   Si ce n'est pas terminé, ça n'est pas dans la Pull Request.
6. **Aucune donnée réelle de patient.** Tout le jeu de données est synthétique.
7. **Un `TUTORIAL.md` par équipe**, avec les 14 sections imposées.

---

## Ce que doit contenir une Pull Request

La Pull Request est l'unité de revue. Elle doit permettre à un autre étudiant de
comprendre la contribution **sans lui parler à son auteur**.

- [ ] Le `TUTORIAL.md` de l'équipe est à jour (14 sections)
- [ ] Le healthcheck du service est **vert sur un endpoint réel** (pas « le
      processus existe »)
- [ ] Le test contractuel passe : `./tests/test_<sujet>.sh`
- [ ] `./bin/farci lint` est vert
- [ ] `versions.env` est à jour si une version a changé
- [ ] La sonde du service est visible dans le tableau de progression
- [ ] Les messages de commit expliquent **pourquoi**, pas seulement **quoi**

---

## Rédaction d'un message de commit

Bon :

```
équipe-3 : bascule le gateway vers bifrost via Caddy sans redémarrage

Caddy ne répartit pas la charge entre les deux gateways (choix pédagogique
délibéré, cf. docs/ARCHITECTURE.md) : la permutation se fait en rechargeant
la configuration, ce qui rend le changement visible en direct pendant
l'étape 3.
```

Moins bon :

```
fix gateway
```

Le premier explique la décision. Le second oblige le relecteur à deviner.

---

## Ce que le relecteur doit vérifier

- La Pull Request respecte-t-elle le **contrat** de la brique
  (`CONTRACT.md`) plutôt que l'implémentation ?
- Le code est-il lisible par un étudiant en médecine ?
- Les tests **échoueraient-ils** si la brique était cassée ? Un test qui passe
  toujours ne teste rien.
- La documentation explique-t-elle le *pourquoi* ?

---

## Interdits qui ont du sens ici

- **Réécrire le code métier pour contourner un contrat.** Si LiteLLM ne convient
  pas, on écrit Bifrost, on ne modifie pas l'application.
- **Ajouter une dépendance** sans indiquer qui l'utilise
  (`requirements.in` le précise pour chaque ligne).
- **Désactiver un test** pour faire passer la CI. Si un test est faux, on le
  corrige et on l'explique dans le commit.

---

## Avant de demander une revue

```bash
./bin/farci lint          # vert ?
./bin/farci selftest      # les briques maison fonctionnent ?
./bin/farci status        # ma brique apparaît-elle UP ?
```

Si les trois réponses sont bonnes, la Pull Request est prête.
