# =============================================================================
# hash_tool - Dockerfile
#
# Image Alpine légère (~15 Mo) avec b3sum et jq.
# Supporte linux/amd64 et linux/arm64 (NAS Synology, Raspberry Pi, etc.)
#
# b3sum est installé depuis les packages Alpine (community) - plus fiable
# que le téléchargement manuel depuis GitHub Releases.
#
# Build :
#   docker build -t hash_tool .
#   docker build --platform linux/arm64 -t hash_tool:arm64 .
#
# Utilisation :
#   docker run --rm -v /mes/donnees:/data hash_tool verify /data/base.b3
#   docker run --rm -v /mes/donnees:/data -v /mes/bases:/bases hash_tool compute /data /bases/hashes.b3
#   docker run --rm -v /chemin/pipeline.json:/pipelines/pipeline.json \
#              -v /mes/donnees:/data -v /mes/bases:/bases -v /mes/resultats:/resultats \
#              hash_tool runner /pipelines/pipeline.json
# =============================================================================

FROM alpine:3.19

LABEL maintainer="hash_tool" \
      description="Vérification d'intégrité BLAKE3 - integrity.sh + runner.sh" \
      org.opencontainers.image.source="https://github.com/hash_tool"

# Toutes les dépendances depuis apk - pas de wget, pas de binaire externe
# b3sum est dans Alpine community depuis v3.15
RUN apk add --no-cache \
      bash \
      jq \
      b3sum \
      coreutils \
      findutils \
    && rm -rf /var/cache/apk/*

# == Copie des scripts ========================================================

WORKDIR /app

COPY runner.sh           ./runner.sh
COPY src/integrity.sh    ./src/integrity.sh
COPY src/lib/report.sh   ./src/lib/report.sh

RUN chmod +x runner.sh src/integrity.sh src/lib/report.sh

# == Entrypoint ===============================================================

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# == Volumes ==================================================================
#
# /data       → données à hacher (montage en lecture seule recommandé)
# /bases      → fichiers .b3 (lecture/écriture)
# /pipelines  → fichiers pipeline.json
# /resultats  → résultats compare/verify
#
VOLUME ["/data", "/bases", "/pipelines", "/resultats"]

# RESULTATS_DIR par défaut redirigé vers /resultats (volume monté)
ENV RESULTATS_DIR=/resultats

ENTRYPOINT ["/entrypoint.sh"]
CMD ["help"]