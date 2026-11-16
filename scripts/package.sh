#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ollama-qwen3-embedding-0.6b}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
OUT_DIR="${OUT_DIR:-dist}"
CHUNK_SIZE="${CHUNK_SIZE:-1800M}"
ARCHIVE_PREFIX="${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"

mkdir -p "${OUT_DIR}"
rm -f "${OUT_DIR}/${ARCHIVE_PREFIX}"* "${OUT_DIR}/SHA256SUMS"

COMPRESSOR="gzip"
if command -v pigz >/dev/null 2>&1; then
  COMPRESSOR="pigz"
fi

echo "Exporting ${IMAGE_NAME}:${IMAGE_TAG} using ${COMPRESSOR} and splitting into ${CHUNK_SIZE} parts..."
docker save "${IMAGE_NAME}:${IMAGE_TAG}" \
  | "${COMPRESSOR}" -c \
  | split -b "${CHUNK_SIZE}" -d -a 2 - "${OUT_DIR}/${ARCHIVE_PREFIX}.part."

echo "Generating SHA256SUMS..."
(
  cd "${OUT_DIR}"
  sha256sum "${ARCHIVE_PREFIX}.part."* > SHA256SUMS
)

echo "Package created in ${OUT_DIR}/:"
ls -lh "${OUT_DIR}"
