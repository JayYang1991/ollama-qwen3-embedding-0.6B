#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-serve-all}" != "serve-all" ]]; then
  exec "$@"
fi

mkdir -p /qdrant/storage /qdrant/snapshots

OLLAMA_PID=""
QDRANT_PID=""

shutdown() {
  echo "Shutting down Ollama and Qdrant..."
  if [[ -n "${QDRANT_PID}" ]] && kill -0 "${QDRANT_PID}" 2>/dev/null; then
    kill -TERM "${QDRANT_PID}" 2>/dev/null || true
  fi
  if [[ -n "${OLLAMA_PID}" ]] && kill -0 "${OLLAMA_PID}" 2>/dev/null; then
    kill -TERM "${OLLAMA_PID}" 2>/dev/null || true
  fi
  wait "${QDRANT_PID}" 2>/dev/null || true
  wait "${OLLAMA_PID}" 2>/dev/null || true
}

trap shutdown SIGTERM SIGINT

echo "Starting Ollama server on ${OLLAMA_HOST:-0.0.0.0:11434}..."
ollama serve &
OLLAMA_PID=$!

echo "Starting Qdrant server on 0.0.0.0:6333 (HTTP) / 0.0.0.0:6334 (gRPC)..."
(cd /qdrant && exec /qdrant/qdrant) &
QDRANT_PID=$!

# Exit if either process terminates unexpectedly
wait -n "${OLLAMA_PID}" "${QDRANT_PID}"
EXIT_CODE=$?
echo "A service exited with code ${EXIT_CODE}; stopping remaining service..."
shutdown
exit "${EXIT_CODE}"
