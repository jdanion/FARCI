# TUTORIAL — Équipe 7 : Applications (étape 2)

## Mission

Utiliser la plateforme pour une **extraction clinique** : des dossiers
médicaux synthétiques → des variables structurées, validées, comparables.

- **Objectif minimal (étape 1)** : Open WebUI démarré et branché sur `/v1`
  (ligne `Open WebUI` verte) : c'est l'interface des étudiants sans machine
  utilisable à l'étape 2.
- **Bonus (étape 1)** : un premier dossier extrait par le parcours Python.
- **Étape 2, pour tous** : parcours Python sur le jeu rapide (10 dossiers),
  extractions évaluées ; prompt v2 comparé à v1 ; Flowise en démonstration du
  formateur.

## Ce que votre service apporte

C'est la raison d'être de la plateforme. Votre application ne connaît ni le
modèle ni le runtime : seulement le point d'entrée Caddy (`/v1`) et l'alias
`med-extraction`.

## Ce que vous devez comprendre

- **Une sortie de LLM n'est pas une donnée de recherche** tant qu'elle n'a pas
  été validée : un JSON non conforme au schéma n'est **jamais** écrit.
- **Le prompt, le modèle, les paramètres, les données et le code font partie
  de la méthode** : chaque extraction garde dans `_meta` le modèle, le prompt
  et la latence.
- **Même contrat pour tous les parcours** : `datasets/extracted/<run>/patient_<IPP>.json`,
  même schéma (`datasets/schemas/clinical_extraction.schema.json`).

## Vos dépendances

Caddy, la passerelle et un runtime (équipes 1, 2, 3) ; la pseudonymisation
(équipe 4) ; Phoenix (équipe 5) pour les traces, sans en dépendre.

## Votre IP

Les applications n'ont pas d'adresse à connaître : elles utilisent
`FARCI_GATEWAY_URL` (dérivée de `CADDY_IP`). Open WebUI : `OPEN_WEBUI_IP`,
port `OPEN_WEBUI_PORT` ; Flowise : `FLOWISE_IP`, `FLOWISE_PORT`.

## Installation

```bash
pip install --no-index --find-links offline/wheels -r requirements.txt
```

## Configuration

- `07-applications/common/prompts/extraction_v1.md` et `extraction_v2.md` :
  les deux prompts comparés (`v1-vs-v2.md`).
- `config/workshop.env` : `FARCI_TRACK` (parcours), `FARCI_PROFILE` (quick ou
  standard).

## Démarrage

Parcours Python (principal) :

```bash
./bin/farci extract --subset quick --run python
./bin/farci evaluate --subset quick
```

Parcours Open WebUI :

```bash
./bin/farci up 07-applications/open-webui
07-applications/open-webui/post-setup.sh
```

Coller le contenu d'un dossier (prompt : `07-applications/open-webui/prompt.md`),
puis exporter : `07-applications/open-webui/export-submissions.sh`.

Flowise : démonstration du formateur (`07-applications/flowise/README.md`).

## Test local

```bash
./bin/farci test-unit -k structured_output
```

## Test contractuel

Le contrat est le schéma : `./bin/farci evaluate` compte les JSON valides
de chaque run, et `./bin/farci test-unit -k schema_parity` vérifie que le
schéma, Pydantic, les prompts et le gold disent la même chose.

## Vérification sur le tableau de bord

Ligne `Client` verte si Open WebUI tourne. Le résultat qui compte est le
classement de `./bin/farci evaluate`.

## Commit

Code et prompts. Jamais `datasets/extracted/` (résultats d'expérience).

## Pull Request

Joindre le tableau d'évaluation de votre run et une phrase : ce qui change
entre v1 et v2.

## Définition de DONE

```text
[ ] 10 dossiers extraits (jeu rapide)
[ ] run visible dans ./bin/farci evaluate
[ ] tests de sortie structurée verts
[ ] documentation complétée
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| `FARCI_GATEWAY_URL absente` | lancé hors de `./bin/farci` | `./bin/farci extract …` |
| beaucoup de `REJET` | le modèle ne respecte pas le schéma | essayer `--prompt v2`, lire le rapport |
| `ERREUR … Connection` | passerelle ou runtime tombé | `./bin/farci status` |
