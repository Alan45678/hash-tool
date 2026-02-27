FROM alpine:3.19

LABEL maintainer="hash_tool" \
      description="Vérification d'intégrité BLAKE3 - integrity.sh + runner.sh" \
      org.opencontainers.image.source="https://github.com/hash_tool"

# On installe 'grep' (GNU) pour le support de -z (indisponible dans BusyBox)
RUN apk add --no-cache \
      bash \
      jq \
      b3sum \
      coreutils \
      findutils \
      grep \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copie des sources et du runner
COPY src/ ./src/
COPY runner.sh ./runner.sh

# Permissions récursives pour garantir l'exécution
RUN chmod +x /app/runner.sh /app/src/integrity.sh

# Entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Volumes
VOLUME ["/data", "/bases", "/pipelines", "/resultats"]
ENV RESULTATS_DIR=/resultats

ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]