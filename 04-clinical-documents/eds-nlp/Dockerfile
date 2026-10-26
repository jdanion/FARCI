# FARCI — image du service EDS-NLP (équipe 4, et doublure sur le Pi)
#
# Construite PENDANT LE PRÉCHARGEMENT, avec Internet, sur la machine qui la
# fera tourner (ou une machine de même architecture) :
#   ./preload.sh --only build_eds_nlp
# Contexte de construction : ce dossier (04-clinical-documents/eds-nlp/).
# EDS-NLP n'a pas de paquet précompilé pour ARM (Pi 5, Mac Apple Silicon) :
# ses deux modules Cython sont alors compilés ici, d'où le compilateur.
# EDS-Pseudo n'est pas sur PyPI : le préchargement le clone au commit figé
# dans 04-clinical-documents/eds-nlp/vendor/eds-pseudo/ (hors Git).
ARG PYTHON_IMAGE_TAG
FROM python:${PYTHON_IMAGE_TAG}

ARG EDSNLP_VERSION

WORKDIR /app
COPY requirements.txt /app/requirements.txt
COPY vendor/eds-pseudo /tmp/eds-pseudo
# Compilateur seulement s'il n'existe pas de paquet précompilé d'EDS-NLP pour
# cette architecture (x86 : paquet précompilé ; ARM : compilation).
RUN set -e; compile=0; \
    if ! pip download -q --no-deps --only-binary=:all: -d /tmp/probe "edsnlp==${EDSNLP_VERSION}"; then \
      compile=1; apt-get update; apt-get install -y --no-install-recommends build-essential; \
    fi; \
    pip install --no-cache-dir -r /app/requirements.txt "edsnlp==${EDSNLP_VERSION}"; \
    pip install --no-cache-dir --no-deps /tmp/eds-pseudo; \
    if [ "$compile" = 1 ]; then \
      apt-get purge -y build-essential; apt-get autoremove -y; rm -rf /var/lib/apt/lists/*; \
    fi; \
    rm -rf /tmp/probe /tmp/eds-pseudo; \
    python -c "import edsnlp, eds_pseudo; print('edsnlp', edsnlp.__version__)"

COPY service.py prompt.md exemples.txt /app/

ENV EDS_NLP_LISTEN_PORT=8000 PYTHONUNBUFFERED=1
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=3)"
CMD ["python", "/app/service.py"]
