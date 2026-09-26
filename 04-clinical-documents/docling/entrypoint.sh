#!/usr/bin/env bash
# FARCI — entrypoint Docling
# Configure les options de conversion avant de démarrer.

set -euo pipefail

export DOCLING_DO_OCR="${DOCLING_DO_OCR:-false}"
export DOCLING_DO_TABLE_STRUCTURE="${DOCLING_DO_TABLE_STRUCTURE:-true}"
export DOCLING_TABLE_STRUCTURE_MODE="${DOCLING_TABLE_STRUCTURE_MODE:-fast}"
export DOCLING_USE_V2="${DOCLING_USE_V2:-true}"

exec docling-serve run
