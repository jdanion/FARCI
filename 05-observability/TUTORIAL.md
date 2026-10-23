# TUTORIAL — Équipe 5 : Observabilité

## Mission

Rendre visible ce qui se passe dans le pipeline : chaque appel au modèle
laisse une **trace** (modèle, latence, tokens, erreur), consultable dans
Phoenix (`05-observability/CONTRACT.md`).

- **Objectif minimal** : Phoenix répond (ligne `Observability` verte) et reçoit
  les traces du parcours Python.
- **Bonus** : Langfuse en second backend sur le même flux OTLP, collecteur
  OTel en fan-out.

## Ce que votre service apporte

Quand un dossier échoue ou qu'une extraction est lente, la trace dit pourquoi.
Elle raconte la même histoire que le score de l'évaluation, vue de l'intérieur.

## Ce que vous devez comprendre

- **Observabilité = la traçabilité des soins** : reconstituer ce qui s'est
  passé, après coup.
- **On enseigne OpenTelemetry, pas Phoenix** : le code est instrumenté une
  fois (`07-applications/common/observability.py`) ; Phoenix et Langfuse
  lisent le même flux.
- **Hors du chemin de production** : si Phoenix tombe (scénario 07),
  l'extraction continue ; seules les traces sont perdues.

## Vos dépendances

Le réseau (équipe 1). Les applications vous envoient leurs traces.

## Votre IP

| Backend | Adresse | Port |
|---|---|---|
| Phoenix | `OBSERVABILITY_A_IP` | `PHOENIX_PORT` |
| Langfuse (bonus) | `OBSERVABILITY_B_IP` | `LANGFUSE_PORT` |
| Collecteur OTel (bonus) | `OTEL_COLLECTOR_IP` | 4317 / 4318 |

`OTEL_EXPORTER_OTLP_ENDPOINT` est dérivée automatiquement (Phoenix,
`/v1/traces`) par `scripts/dev-env.sh`.

## Installation

Image `phoenix` préchargée (`./bin/farci verify-images`) ; bonus :
`./bin/farci verify-images --all`.

## Configuration

- `05-observability/otel-config.env` : nom de service, échantillonnage.
- `FARCI_TRACE=off` (dans `config/workshop.env`) coupe l'envoi des traces.

## Démarrage

```bash
./bin/farci up 05-observability/phoenix
```

Bonus :

```bash
./bin/farci up 05-observability/langfuse
05-observability/langfuse/bootstrap.sh
./bin/farci up 05-observability/collector
```

## Test local

```bash
./bin/farci status
```

## Test contractuel

```bash
./bin/farci test
```

Ligne `observability` : `PASS`. Puis lancer une extraction
(`./bin/farci extract --subset quick`) et retrouver les spans
`chat.completion` dans Phoenix.

## Vérification sur le tableau de bord

Ligne `Observability` verte.

## Commit

Les compose et fichiers de configuration. Jamais de clé Langfuse.

## Pull Request

Joindre une capture d'une trace : modèle demandé (`med-extraction`), modèle
réel, latence, tokens.

## Définition de DONE

```text
[ ] Phoenix démarré
[ ] ligne Observability verte
[ ] ./bin/farci test : observability PASS
[ ] une trace d'extraction visible dans Phoenix
[ ] Pull Request ouverte et relue
```

## Dépannage

| Symptôme | Cause probable | Commande |
|---|---|---|
| aucune trace | SDK OpenTelemetry absent sur le poste | `pip install --no-index --find-links offline/wheels -r requirements.txt` |
| aucune trace | `FARCI_TRACE=off` | le retirer de `config/workshop.env` |
| Phoenix ne démarre pas | port déjà pris | `./bin/farci logs 05-observability/phoenix` |
