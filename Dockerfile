FROM alpine:3.19

LABEL maintainer="hash_tool" \
      description="Vérification d'intégrité BLAKE3 - integrity.sh + runner.sh"

RUN apk add --no-cache \
      bash \
      jq \
      b3sum \
      coreutils \
      findutils \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Correction : On copie TOUS les scripts nécessaires
COPY src/ ./src/
COPY runner.sh ./runner.sh
# On s'assure que tout est exécutable dans /app
RUN chmod +x /app/runner.sh /app/src/integrity.sh

# Entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/data", "/bases", "/pipelines", "/resultats"]
ENV RESULTATS_DIR=/resultats

ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]