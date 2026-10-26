# Déployer FARCI sur un Raspberry Pi 5 seul (LAN domestique)

Ce guide se suit **dans l'ordre**, commande par commande, sur le Pi. Il est
écrit pour être exécuté tel quel par une autre session (humaine ou Claude
Code) sans rien deviner.

| Cible | Valeur |
|---|---|
| Machine | Raspberry Pi 5, 8 Go de RAM, CPU 4 cœurs, `aarch64` |
| Système | Debian 13 « trixie » arm64, Docker Engine + plugin Compose déjà installés |
| Disque | 108 Go libres ; il en faut **~30 Go** (voir § 8) |
| Réseau | LAN domestique, adresse fixe **192.168.0.222**, nom **farci.local** |
| Rôle | machine seule : la **pile de référence** (`reference/`) sert toutes les briques (🛟) |
| Source | dépôt public `jdanion/FARCI`, branche `claude/youthful-curie-5ofyyy` (le SHA attendu est donné avec ce guide) |

> ⚠️ **Ne pas utiliser `main`** sur GitHub pour l'instant : le 23 octobre,
> `main` a été ramené à un état du 27 septembre (une synchronisation depuis
> Gitea l'a écrasé). La branche ci-dessus contient tout le travail à jour
> (lots 1 à 4, EDS-NLP, ce guide).

---

## 1. Prérequis système

```bash
uname -m                                   # attendu : aarch64
docker version --format '{{.Server.Arch}}' # attendu : arm64
docker compose version                     # attendu : Docker Compose version v2.x

sudo apt update
sudo apt install -y git curl ca-certificates python3 python3-venv python3-pip avahi-daemon
sudo hostnamectl set-hostname farci        # le Pi répond à farci.local (mDNS, avahi)
sudo usermod -aG docker "$USER"            # si ce n'est pas déjà fait, puis se reconnecter
```

Vérification : depuis un autre poste du LAN, `ping farci.local` répond
depuis 192.168.0.222. L'adresse fixe se règle sur la box (bail DHCP
réservé) ou dans la configuration réseau du Pi.

## 2. Récupérer le dépôt

Le dépôt est **public** : aucune clé ni jeton n'est nécessaire.

```bash
cd ~
git clone --branch claude/youthful-curie-5ofyyy https://github.com/jdanion/FARCI.git farci
cd farci
git log -1 --format='%H %s'                # comparer au SHA donné avec ce guide
# pour figer exactement cette version : git checkout <SHA>
```

## 3. Créer la configuration

```bash
sudo mkdir -p /srv/farci && sudo chown "$USER": /srv/farci
./bin/farci bootstrap                      # crée .env, config/network.env, config/workshop.env
./bin/farci room set reference 192.168.0.222
```

`room set reference` écrit `REFERENCE_IP=192.168.0.222` et
`FARCI_SUBNET=192.168.0.0/24` dans `config/network.env`. Au premier passage,
`bootstrap` signale que `offline/wheels/` est vide : c'est normal, on le
relance après le préchargement (§ 4).

Les secrets, à générer **soi-même** (aucun n'est utilisé par la pile du Pi,
mais rien ne doit rester à sa valeur d'exemple) :

```bash
for k in GATEWAY_KEY_STANDARD GATEWAY_KEY_PRIORITY LITELLM_MASTER_KEY BIFROST_CONFIG_KEY; do
  sed -i "s|^$k=.*|$k=sk-$(openssl rand -hex 16)|" .env
done
for k in GITEA_ADMIN_PASSWORD GITEA_DB_PASSWORD GITEA_SECRET_KEY GITEA_INTERNAL_TOKEN GITEA_RUNNER_TOKEN POSTGRES_PASSWORD; do
  sed -i "s|^$k=.*|$k=$(openssl rand -hex 24)|" .env
done
sed -i 's|^FARCI_ROLE=.*|FARCI_ROLE=full|; s|^FARCI_PROFILE=.*|FARCI_PROFILE=quick|' config/workshop.env

./bin/farci env-check                      # attendu : OK configuration valide
./bin/farci network-check                  # attendu : OK référence 192.168.0.222 …
```

### Fichiers et valeurs

| Fichier | Variable | Valeur pour ce Pi | Note |
|---|---|---|---|
| `.env` | `FARCI_DATA_DIR` | `/srv/farci` | images, modèles, wheels (hors Git) |
| `.env` | `FARCI_STUDENT_ID` | vide | sans objet sur le Pi |
| `.env` | `FARCI_DATASET_SEED` | `20260926` | **ne jamais changer** (le gold en dépend) |
| `.env` | `FARCI_CASES` | `20` | |
| `.env` | `GATEWAY_KEY_STANDARD`, `GATEWAY_KEY_PRIORITY`, `LITELLM_MASTER_KEY`, `BIFROST_CONFIG_KEY` | **secrets à générer** | inutilisés par la pile du Pi (LiteLLM y tourne sans clé) |
| `.env` | `GITEA_*`, `POSTGRES_PASSWORD` | **secrets à générer** | briques bonus (forge) seulement |
| `.env` | `FARCI_ENFORCE_OFFLINE`, `FARCI_HEALTH_TIMEOUT` | `1`, `3` | |
| `.env` | `REFERENCE_RUNTIME_HOST` | absente (option § 7 : `ollama:11434`) | runtime de la passerelle du Pi |
| `config/network.env` | `REFERENCE_IP` | `192.168.0.222` | **seule adresse** utile |
| `config/network.env` | `FARCI_SUBNET` | `192.168.0.0/24` | |
| `config/network.env` | toutes les IP d'équipe (`CADDY_IP` … `GITEA_IP`) | vides | machine seule : la référence sert tout |
| `config/network.env` | ports | valeurs de l'exemple | voir § 9 |
| `config/workshop.env` | `FARCI_ROLE` | `full` | |
| `config/workshop.env` | `FARCI_PROFILE` | `quick` | 10 dossiers |
| `config/workshop.env` | `FARCI_TRACE` | `on` | traces vers Phoenix |

Les adresses restent des **IP** (`farci.local` sert au navigateur) : le
dépôt n'écrit jamais de nom d'hôte dans sa configuration.

## 4. Précharger (avec Internet)

```bash
./preload.sh --pi                          # images arm64, image EDS-NLP compilée ici, modèle 2B, wheels, manifeste
./bin/farci bootstrap                      # installe .venv/ HORS LIGNE depuis offline/wheels
./bin/farci verify-images --reference      # attendu : 0 manquante(s)
./verify-airgap.sh
```

`--pi` est l'alias de `--reference` : images de la pile de référence pour
l'architecture **du Pi**, un seul modèle (Qwen3.5-2B Q4_K_M), les wheels
Python et le manifeste. Résultat attendu de `./verify-airgap.sh` :

| Contrôle | Attendu |
|---|---|
| images | `PASS` (caddy, python, ollama, litellm, docling, eds-nlp, phoenix, open-webui) |
| versions | `PASS` |
| compose | `PASS` |
| models | `WARN` : seul le modèle 2B est présent (normal pour le profil « pi ») |
| manifest | `PASS` |
| offline-policy | `PASS` |

## 5. Démarrer

```bash
make core-up        # = ./bin/farci core-up : pile de référence + Docling
make dashboard-up   # = ./bin/farci dashboard-up : accueil + agrégateur, affiche les adresses
make health         # = ./bin/farci health : tableau, code 0 si « service rendu » READY
```

`make health` doit afficher toutes les lignes cœur en `🛟 REF`, puis :

```
CLINICAL PIPELINE          NOT READY   ← normal : aucune équipe n'a livré
Service rendu (avec 🛟)     READY       ← c'est le critère sur un Pi seul
service rendu : READY — il manque : rien
```

Code de sortie : `0`. Si Docling n'a pas démarré (premier démarrage lent,
mémoire), le service rendu est `DEGRADED` : `./bin/farci logs reference
docling`, puis `make core-up` à nouveau.

## 6. Vérifier

```bash
curl -s http://farci.local/livez                    # attendu : ok
curl -s http://192.168.0.222/v1/models              # attendu : med-extraction, med-extraction-lite, med-chaos
curl -s http://192.168.0.222/eds/health             # attendu : {"status": "ok", ...}
./bin/farci test                                    # attendu : gateway-contract, eds-nlp, observability, airgap PASS
./bin/farci extract --subset quick --limit 3 --run pi   # attendu : au moins 2 dossier(s) écrit(s), 0 erreur
./bin/farci eds pseudo datasets/raw/patient_1234567890123_cro.txt   # [PRENOM] [NOM], [IPP], [SECU]…
./bin/farci rehearse                                # attendu : Verdict : PASS, moins de 15 min
```

Dans un navigateur du LAN :

| Adresse | Attendu |
|---|---|
| `http://farci.local/` | **le tableau de la salle** (redirige vers `/tableau`) : tuiles, classement, fil |
| `http://farci.local/status` | JSON : `service_rendu.state` = `READY` |
| `http://farci.local:3080` | Open WebUI, sans compte ; modèle `med-extraction` |
| `http://farci.local:6006` | Phoenix ; des traces après `./bin/farci extract` |

Sans modèle, les réponses viennent du **runtime rejoué** (réponses
enregistrées, instantanées). C'est voulu : un Pi ne sert pas un modèle à une
salle. Pour un vrai modèle, voir § 7.

### Le tableau de la salle sur l'iPad

1. Safari → `http://farci.local/` (ou `http://192.168.0.222/`).
2. Partager → « Sur l'écran d'accueil » : le tableau s'ouvre ensuite en plein
   écran, sans barre d'adresse.
3. Toucher « Plein écran · écran allumé » (en bas à droite) : l'iPad ne se
   met plus en veille tant que la page est ouverte.
4. Recopie vidéo (AirPlay ou adaptateur) vers l'écran de la salle.
5. Avant l'arrivée des étudiants, sur le Pi : `./bin/farci tableau reset`
   (scores, badges, fil et chrono à zéro).

Une équipe marque des points quand l'accueil sert **sa** brique (✅) : 100
par brique cœur, 50 par brique bonus, +50 « Premiers ! », +50 « Pipeline
READY » à chaque équipe ayant livré, +50 « Increvable » après 30 minutes
sans interruption. Une panne ne coûte rien.

## 7. Option : un vrai modèle sur le Pi (Qwen3.5-2B)

À faire après le § 6. Docling et le modèle ensemble dépassent ce que 8 Go
supportent confortablement : on arrête Docling le temps de l'essai.

```bash
./bin/farci down reference docling
./bin/farci up reference ollama
OLLAMA_CONTAINER=farci-ref-ollama 02-inference/ollama/create-model.sh secours
echo 'REFERENCE_RUNTIME_HOST=ollama:11434' >> .env
./bin/farci up reference litellm
time ./bin/farci eds entites datasets/raw/patient_1234567890123_crap.txt
time ./bin/farci extract --subset quick --limit 1 --run pi-modele
```

Retour au runtime rejoué : retirer la ligne `REFERENCE_RUNTIME_HOST` de
`.env`, puis `./bin/farci up reference litellm`, `./bin/farci down reference
ollama`, `make core-up`.

### Modèles et RAM (CPU 4 cœurs, 8 Go)

| Modèle (GGUF, `models/models.env`) | Fichier | Taille annoncée | Sur ce Pi |
|---|---|---|---|
| Qwen3.5-2B Q4_K_M | `Qwen3.5-2B-Q4_K_M.gguf` | ~1,2 Go | **oui** : le modèle du profil « pi » |
| Ornith-1.5-9B Q4_K_M | `Ornith-1.5-9B-Q4_K_M.gguf` | ~5,5 Go | se charge seul, mais pas avec la pile ; quelques tokens/s : non |
| Ornith-1.5-9B Q5_K_M | `Ornith-1.5-9B-Q5_K_M.gguf` | ~6,5 Go | non |
| Qwen3.8-27B Q4_K_M | `Qwen3.8-27B-Q4_K_M.gguf` | ~16,5 Go | non |

Les fichiers GGUF sont servis par Ollama sous le nom logique
`med-extraction` (`02-inference/ollama/create-model.sh`).

## 8. Disque et durée

| Poste | Estimation |
|---|---|
| Téléchargement des images arm64 (compressé) | ~7,5 Go : ollama 2,8 ; docling 2,1 ; open-webui 1,5 ; litellm 0,4 ; phoenix 0,35 ; python + caddy 0,07 |
| Images décompressées (Docker) | ~16–18 Go |
| Archives `offline/images/*.tar` | ~8–17 Go selon le stockage d'images de Docker |
| Image EDS-NLP construite + cache | ~1,5 Go |
| Modèle 2B + wheels | ~1,8 Go |
| **Total** | **~30 Go** (fourchette 25–40 Go) sur 108 Go libres |

Durée de `./preload.sh --pi` : **45 à 90 min**. Comptez 15 à 40 min de
téléchargement selon le débit, 10 à 20 min de décompression sur carte SD,
10 à 15 min de compilation EDS-NLP, puis quelques minutes de sauvegarde et
d'empreintes. Les archives `.tar` ne servent qu'à recopier les images vers
d'autres machines arm64 : on peut les supprimer pour regagner de la place
(`rm /srv/farci/offline/images/*.tar`, puis `./preload.sh --only manifest`).

## 9. Ports exposés sur le Pi

| Service | Conteneur | Port hôte | Variable |
|---|---|---|---|
| Accueil (Caddy) : `/v1`, `/runtime`, `/docling`, `/eds`, `/observability`, `/status`, `/livez` | `farci-ref-caddy` | 80 | `ENTRY_PORT` |
| Agrégateur de santé | `farci-ref-aggregator` | 8088 | `HEALTH_AGGREGATOR_PORT` |
| Runtime rejoué | `farci-ref-replay` | 8090 | `REPLAY_PORT` |
| LiteLLM | `farci-ref-litellm` | 4000 | `GATEWAY_A_PORT` |
| Docling | `farci-ref-docling` | 5001 | `DOCLING_PORT` |
| EDS-NLP | `farci-ref-eds-nlp` | 5002 | `EDS_NLP_PORT` |
| Phoenix | `farci-ref-phoenix` | 6006 | `PHOENIX_PORT` |
| Open WebUI | `farci-ref-open-webui` | 3080 | `OPEN_WEBUI_PORT` |
| Ollama (option § 7) | `farci-ref-ollama` | non publié | — |

Ports des briques d'équipe (autres machines, non utilisés ici) :
`config/network.env.example`.

## 10. Images Docker et arm64

Vérifié le 26/10/2026 auprès des registres (Docker Hub, ghcr.io) : **toutes**
les images ont une variante `linux/arm64`.

| Image | arm64 | Utilisée sur le Pi |
|---|---|---|
| `caddy:2.11.4-alpine` | oui | oui |
| `python:3.13.15-slim-trixie` | oui | oui (agrégateur, runtime rejoué) |
| `ghcr.io/berriai/litellm:1.102.1` | oui | oui |
| `arizephoenix/phoenix:20.16.0` | oui | oui |
| `ghcr.io/open-webui/open-webui:0.11.4` | oui | oui |
| `ghcr.io/docling-project/docling-serve-cpu:v1.35.0` | oui | oui |
| `ollama/ollama:0.34.4` | oui | option § 7 |
| `farci/eds-nlp:0.23.0` | construite sur le Pi | oui |
| `gitea/gitea:1.27.3`, `gitea/act_runner:0.6.1`, `node:20.19.5-bookworm`, `postgres:18.6-alpine`, `redis:8.8.3-alpine`, `louislam/uptime-kuma:2.5.5`, `maximhq/bifrost:v1.6.0`, `langfuse/langfuse:4.46.0`, `otel/opentelemetry-collector-contrib:0.120.0`, `ghcr.io/mlflow/mlflow:v3.16.1`, `flowiseai/flowise:3.1.4` | oui | non (briques bonus) |
| `farci/llamacpp:server-b10600` | construite localement | non (bonus, groupe `build_llamacpp`, absent du profil « pi ») |

## 11. Dépannage

| Symptôme | Commande |
|---|---|
| « n'a pas accès à Docker » (ou « Docker ne répond pas ») | `sudo usermod -aG docker "$USER"`, se déconnecter et se reconnecter (ou `newgrp docker`) ; vérifier avec `docker ps` sans `sudo` |
| « le service Docker est arrêté » | `sudo systemctl enable --now docker` |
| `preload` : échec du clonage d'eds-pseudo ou de la compilation EDS-NLP | relancer `./preload.sh --only build_eds_nlp` ; joindre la sortie |
| `preload` : un modèle en erreur 404 | l'URL de `models/models.env` a changé sur Hugging Face : la corriger (même nom de fichier) |
| `make core-up` : « image absente » | `./bin/farci verify-images --reference`, puis `./preload.sh --pi --skip-existing` |
| `make health` : DEGRADED, docling | `./bin/farci logs reference docling` ; `docker stats --no-stream` (mémoire) |
| tout est DOWN | `REFERENCE_IP` faux : `./bin/farci room set reference 192.168.0.222` |
| `ModuleNotFoundError: pydantic` | `./bin/farci bootstrap` (après le préchargement des wheels) |

## 12. Ce qui n'a pas encore été vérifié sur un vrai Pi

- La compilation arm64 de l'image EDS-NLP et la durée réelle du préchargement.
- Docling sur 8 Go avec le reste de la pile (mémoire et temps de démarrage).
- Les URL Hugging Face des modèles (inaccessibles depuis la session qui a
  écrit ce guide) ; tailles reprises de la documentation du dépôt.
- La vitesse du modèle 2B sur CPU (§ 7).

À renvoyer après l'installation : la sortie de `./preload.sh --pi` en cas
d'échec, celle de `./verify-airgap.sh` et de `make health`, le rapport
`datasets/reports/rehearse-*.txt`, et `docker stats --no-stream`.
