# FARCI — façade `make`.
#
# POURQUOI CE FICHIER EST SI COURT
# Toute la logique vit dans scripts/cmd/*.sh. Cette Makefile se contente de
# transformer chaque ligne de scripts/targets.def en cible. Conséquences :
#   1. `make help` et `./bin/farci help` affichent la MÊME liste (une seule
#      source de vérité : scripts/targets.def) ;
#   2. le dépôt reste utilisable sans make, ce qui compte en mode air-gap ;
#   3. ajouter une commande = ajouter une ligne dans targets.def + un script.
#
# Pour la liste complète :  make help

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Doit-on être à la racine du dépôt ? (évite les surprises avec make -C)
ifneq ($(wildcard scripts/targets.def),)
else
$(error Exécutez make depuis la racine du dépôt (ou utilisez : make -C /chemin/vers/farci <cible>))
endif

FARCI := ./bin/farci
DEFINITIONS := scripts/targets.def

# Liste des cibles, hors commentaire et hors "help" (traité ci-dessous).
TARGETS := $(shell awk -F'\t' 'NF>=4 && $$1 != "help" && $$1 !~ /^#/ {print $$1}' $(DEFINITIONS))

.PHONY: help $(TARGETS)

help:
	@$(FARCI) help

# Une règle par cible : délègue au script correspondant.
define FARCI_RULE
$(1):
	$(FARCI) $(1)
endef
$(foreach target,$(TARGETS),$(eval $(call FARCI_RULE,$(target))))
