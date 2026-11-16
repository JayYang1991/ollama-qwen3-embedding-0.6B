FROM qdrant/qdrant:latest AS qdrant

FROM ollama/ollama:latest

ARG MODEL_NAME=qwen3-embedding:0.6b

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_KEEP_ALIVE=-1 \
    QDRANT__SERVICE__HOST=0.0.0.0 \
    QDRANT__SERVICE__HTTP_PORT=6333 \
    QDRANT__SERVICE__GRPC_PORT=6334 \
    QDRANT__STORAGE__STORAGE_PATH=/qdrant/storage \
    QDRANT__STORAGE__SNAPSHOTS_PATH=/qdrant/snapshots

# Start Ollama daemon temporarily during build to pull and bake the model into the image
RUN set -e; \
    ollama serve & \
    SERVER_PID=$!; \
    trap 'kill "${SERVER_PID}" >/dev/null 2>&1 || true' EXIT; \
    echo "Waiting for Ollama server to start..."; \
    for i in $(seq 1 30); do \
        if ollama list >/dev/null 2>&1; then \
            break; \
        fi; \
        sleep 1; \
    done; \
    ollama pull "${MODEL_NAME}"; \
    ollama list | grep -q "${MODEL_NAME}"; \
    kill "${SERVER_PID}" && wait "${SERVER_PID}" || true

# Install Qdrant runtime dependency (libunwind8) and curl for healthchecks
RUN apt-get update && \
    apt-get install -y --no-install-recommends libunwind8 curl && \
    rm -rf /var/lib/apt/lists/*

# Copy Qdrant binary, config, and Web UI static assets
COPY --from=qdrant /qdrant/qdrant /qdrant/qdrant
COPY --from=qdrant /qdrant/config /qdrant/config
COPY --from=qdrant /qdrant/static /qdrant/static
RUN mkdir -p /qdrant/storage /qdrant/snapshots

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 11434 6333 6334

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ollama list >/dev/null 2>&1 && curl -sf http://127.0.0.1:6333/readyz >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve-all"]
