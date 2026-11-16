#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ollama-qwen3-embedding-0.6b}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
MODEL_NAME="${MODEL_NAME:-qwen3-embedding:0.6b}"

echo "[1/2] Pulling latest base images (ollama/ollama:latest & qdrant/qdrant:latest)..."
docker pull ollama/ollama:latest
docker pull qdrant/qdrant:latest

echo "[2/2] Building ${IMAGE_NAME}:${IMAGE_TAG} with baked model ${MODEL_NAME} ..."
docker build \
  --build-arg MODEL_NAME="${MODEL_NAME}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

echo "Done! Built ${IMAGE_NAME}:${IMAGE_TAG}"
docker images "${IMAGE_NAME}:${IMAGE_TAG}"
