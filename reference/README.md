# Pile de référence — la machine du formateur

La pile de référence est **la chaîne cœur complète, sur une seule machine**,
démarrée avant l'arrivée des étudiants. Elle a trois rôles :

1. **L'accueil de la salle** : son Caddy (`REFERENCE_IP:ENTRY_PORT`) est
   l'adresse unique que toutes les applications appellent.
2. **Le filet** : pour chaque brique, l'accueil sert celle de l'équipe si
   elle est saine, sinon celle de la référence. Le tableau l'affiche :
   `✅ UP` (l'équipe) ou `🛟 REF` (la référence).
3. **Le poste des étudiants sans machine** : Open WebUI de la référence.

Matériel visé : **Raspberry Pi 5, 8 Go** (arm64), qui crée aussi le Wi-Fi de
la salle. Aucun autre matériel n'est requis sur place.

---

## Ce qui tourne sur le Pi

| Service | Conteneur | Port publié | Mémoire max |
|---|---|---|---|
| Accueil (Caddy) | `farci-ref-caddy` | `ENTRY_PORT` (80) | 128 Mo |
| Agrégateur de santé | `farci-ref-aggregator` | `HEALTH_AGGREGATOR_PORT` | 128 Mo |
| Runtime rejoué (plan C) | `farci-ref-replay` | `REPLAY_PORT` | 128 Mo |
| LiteLLM | `farci-ref-litellm` | `GATEWAY_A_PORT` | 1 Go |
| Phoenix | `farci-ref-phoenix` | `PHOENIX_PORT` | 1 Go |
| Open WebUI | `farci-ref-open-webui` | `OPEN_WEBUI_PORT` | 1,5 Go |
| EDS-NLP (doublure de l'équipe 4) | `farci-ref-eds-nlp` | `EDS_NLP_PORT` | 768 Mo |
| *option* Ollama + modèle 2B | `farci-ref-ollama` | — | 4 Go |
| *option* Docling | `farci-ref-docling` | `DOCLING_PORT` | 3 Go |

Le runtime de la référence est le **runtime rejoué** : il renvoie des
réponses enregistrées, conformes au contrat OpenAI, sans aucun calcul. Un Pi
ne sert pas un modèle à dix machines ; il sert en revanche des réponses
rejouées instantanément, ce qui suffit pour que l'étape 2 et le chaos
fonctionnent même si aucune équipe n'a de modèle.

**Budget mémoire** : la pile de base tient dans ~5 Go. Ollama **ou** Docling
en plus, jamais les deux sur un Pi de 8 Go.

---

## J-7 — Préparer le Pi (avec Internet, à la maison)

```bash
# 1. Raspberry Pi OS 64 bits (Bookworm), à jour ; Docker et le plugin compose
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"     # puis se déconnecter / reconnecter

# 2. Le dépôt et ses données
git clone <dépôt> farci && cd farci
cp .env.example .env
cp config/network.env.example config/network.env   # REFERENCE_IP=192.168.50.1

# 3. Les images et les paquets Python POUR LE PI : à lancer sur le Pi lui-même.
#    `docker pull` tire l'architecture de la machine (arm64) ; les .tar des
#    portables (x86) ne fonctionneraient pas ici, et inversement.
./preload.sh --reference    # dont l'image EDS-NLP, COMPILÉE ici pour arm64 (~10 min)
./bin/farci bootstrap       # .venv/ installé hors ligne (le chaos et le plan C en ont besoin)

# 4. Premier démarrage, pour vérifier
./bin/farci up reference
./bin/farci status          # tout en 🛟 REF, « Service rendu READY »
./bin/farci test            # gateway-contract PASS (par l'accueil)

# 5. La répétition générale, à refaire la veille (voir docs/PILOTAGE.md)
./bin/farci rehearse
```

Alimentation officielle 27 W et refroidissement actif : sous charge, un
Pi 5 sans ventilateur ralentit.

---

## Le Wi-Fi de la salle : le Pi en point d'accès

Avec NetworkManager (par défaut sur Bookworm), une seule connexion suffit.
`ipv4.method shared` fournit aussi le DHCP aux portables.

```bash
sudo nmcli con add type wifi ifname wlan0 con-name farci-ap autoconnect yes \
  ssid FARCI-SALLE mode ap 802-11-wireless.band bg \
  ipv4.method shared ipv4.addresses 192.168.50.1/24 \
  wifi-sec.key-mgmt wpa-psk wifi-sec.psk 'choisir-un-mot-de-passe'
sudo nmcli con up farci-ap
```

L'adresse (`192.168.50.1`) et le sous-réseau (`192.168.50.0/24`) sont ceux
de `config/network.env.example` : ne les changer qu'ici et là.

**Capacité** : le Wi-Fi intégré du Pi tient une **dizaine de machines**.
Au-delà, travailler en binômes (une machine pour deux), ou brancher un
routeur de voyage en Ethernet sur le Pi.

**Pas d'Internet dans la salle** : c'est voulu. Le Pi ne route rien vers
l'extérieur ; tout ce dont la séance a besoin est déjà sur les machines.

---

## J0 — Dans la salle

```bash
sudo nmcli con up farci-ap          # le Wi-Fi FARCI-SALLE apparaît
./bin/farci up reference            # 1 à 2 min sur un Pi
./bin/farci status --watch          # sur l'écran projeté
```

Au départ, toutes les lignes sont `🛟 REF` : la référence rend le service,
**aucune équipe** n'a encore livré. C'est le point de départ voulu.

Chaque équipe lit l'IP de sa machine avec `./bin/farci doctor` et vous la
donne. Vous la déclarez **sur le Pi**, une fois par équipe :

```bash
./bin/farci room set 2 192.168.50.23     # toutes les briques cœur de l'équipe 2
./bin/farci room set gateway-bifrost 192.168.50.31   # une brique précise
./bin/farci room                          # qui héberge quoi, qui sert quoi
```

L'accueil se recharge seul. Dès que la brique de l'équipe répond, sa ligne
passe de `🛟 REF` à `✅ UP`. Les postes étudiants n'ont **rien** à changer :
ils ne connaissent que `REFERENCE_IP`.

---

## Les commandes de secours (sur le Pi)

| Situation | Commande | Effet |
|---|---|---|
| une brique d'équipe répond **mal** (lente, fausse) | `./bin/farci rescue inference` | la référence sert seule cette brique (quelques secondes) |
| l'équipe a réparé | `./bin/farci rescue --off inference` | l'équipe reprend la main |
| tout est confus, fin d'un chaos | `./bin/farci reset-all` | pannes réparées, bascules levées, tableau affiché |
| un vrai modèle sur la référence | `./bin/farci up reference ollama` puis `OLLAMA_CONTAINER=farci-ref-ollama 02-inference/ollama/create-model.sh secours` et `REFERENCE_RUNTIME_HOST=ollama:11434 ./bin/farci up reference litellm` | modèle 2B, lent mais réel |
| Docling sur la référence | `./bin/farci up reference docling` | à tester sur le Pi avant le jour J |
| EDS-NLP de l'équipe 4 répond mal | `./bin/farci rescue eds` | la doublure du Pi sert `/eds` |

Une brique d'équipe qui **tombe** n'a besoin d'aucune commande : l'accueil
passe à la référence tout seul (et l'écarte 20 secondes avant de
réessayer). `rescue` sert quand la brique **répond, mais mal**.

---

## Si le Wi-Fi du Pi lâche

1. `sudo nmcli con up farci-ap` — dans 9 cas sur 10, cela suffit (1 min).
2. Toujours rien : un autre point d'accès (routeur de voyage, partage de
   connexion d'un téléphone). Le Pi s'y connecte, on lit sa nouvelle IP
   (`hostname -I`), puis **sur chaque poste et sur le Pi** :

   ```bash
   ./bin/farci room set reference <nouvelle-ip-du-pi>
   ```

   Le sous-réseau est déduit (/24). Les machines d'équipe déclarées sur
   l'ancien réseau sont oubliées : les redéclarer sur le Pi avec
   `room set` (3 min).
3. Plus de réseau du tout : chaque équipe continue **sur sa machine**
   (`./bin/farci test` vise alors la brique locale), et l'étape 2 se joue
   sans réseau avec `./bin/farci extract --replay`.

Le partage de connexion 5G vers un serveur personnel distant n'est **jamais
requis** : l'atelier ne dépend d'aucune connexion extérieure.

---

## Si le Pi n'est pas disponible

N'importe quelle machine Linux ou macOS avec Docker et 8 Go de RAM peut
porter la pile de référence : mêmes commandes, `./preload.sh --reference`
lancé sur elle. Avec 4 Go seulement (vieux Mac mini, par exemple), démarrer
sans Open WebUI :

```bash
./bin/farci up reference caddy health-aggregator replay litellm phoenix
```

---

## Ce qui reste à vérifier sur le vrai matériel

Ce dépôt a été testé sur x86 avec Docker, sans Pi ni Wi-Fi :

- [ ] toutes les images de `./preload.sh --reference` existent bien en arm64
      (LiteLLM, Phoenix, Open WebUI, Docling en particulier)
- [ ] la pile de base démarre en moins de 2 min sur le Pi et reste sous 5 Go
- [ ] dix portables sur le point d'accès : stabilité et débit suffisants
- [ ] Docling (profil `documents`) sur le Pi : temps de conversion d'un PDF
- [ ] l'image EDS-NLP se compile sur le Pi (`./preload.sh --reference`) ; elle
      sert aussi aux Mac Apple Silicon (même architecture)
