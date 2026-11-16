#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${1:-.}"

if [[ -f "${DIST_DIR}/SHA256SUMS" ]]; then
  echo "[1/2] Verifying SHA256 checksums..."
  (cd "${DIST_DIR}" && sha256sum -c SHA256SUMS)
else
  echo "[1/2] SHA256SUMS not found, skipping verification."
fi

PARTS=("${DIST_DIR}"/*.tar.gz.part.*)
if [[ ! -e "${PARTS[0]}" ]]; then
  echo "Error: No *.tar.gz.part.* files found in ${DIST_DIR}" >&2
  exit 1
fi

echo "[2/2] Loading Docker image from ${#PARTS[@]} parts..."
cat "${DIST_DIR}"/*.tar.gz.part.* | docker load

echo "Done! Loaded image:"
docker images ollama-qwen3-embedding-0.6b
