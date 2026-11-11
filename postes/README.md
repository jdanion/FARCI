# Fiches de poste

Un fichier par machine de la salle : `equipe-<N>-<surnom>.env`. Il dit ce que
la machine **est** (mémoire, carte graphique) et ce qu'elle **fait** dans le
projet (équipe, runtime, parcours).

Chaque fiche naît sur la branche de son poste, `poste/equipe-<N>-<surnom>`,
et arrive ici par une Pull Request vers `seance` :

```bash
git switch -c poste/equipe-2-atlas
./bin/farci poste nouveau        # écrit postes/equipe-2-atlas.env
git add postes/equipe-2-atlas.env
git commit -m "poste: atlas, 16 Go sans GPU, llama.cpp et modèle 2B"
```

`./bin/farci` lit la fiche tant que l'on est sur cette branche. Le guide
complet : `docs/GIT.md` (`./bin/farci docs git`).

Règles, vérifiées par `./bin/farci poste verifier` et par la CI :

- le surnom est celui de la **machine**, jamais celui d'une personne ;
- **aucun secret** (les mots de passe restent dans `.env`) ;
- seulement les clés `POSTE_*` et celles de `config/workshop.env.example`.
