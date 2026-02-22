# ─────────────────────────────────────────────────────────────────────────────
# hash_tool — Dockerfile
#
# Image Alpine légère (~15 Mo) avec b3sum et jq.
# Supporte linux/amd64 et linux/arm64 (NAS Synology, Raspberry Pi, etc.)
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
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1 : téléchargement et vérification du binaire b3sum ────────────────
FROM alpine:3.19 AS fetcher

# Version b3sum — mettre à jour ici lors des nouvelles releases
ARG B3SUM_VERSION=1.5.4

# Détection architecture pour sélectionner le bon binaire musl
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64)  B3SUM_ARCH="linux_amd64_musl"   ;; \
      aarch64) B3SUM_ARCH="linux_aarch64_musl"  ;; \
      armv7l)  B3SUM_ARCH="linux_armv7_musl"    ;; \
      *)       echo "Architecture non supportée : $ARCH" >&2; exit 1 ;; \
    esac; \
    \
    apk add --no-cache wget ca-certificates; \
    \
    BASE_URL="https://github.com/BLAKE3-team/BLAKE3/releases/download/${B3SUM_VERSION}"; \
    wget -q -O /usr/local/bin/b3sum "${BASE_URL}/b3sum_${B3SUM_ARCH}"; \
    wget -q -O /tmp/b3sum.b3        "${BASE_URL}/b3sum_${B3SUM_ARCH}.b3"; \
    \
    chmod +x /usr/local/bin/b3sum; \
    \
    # Auto-vérification : b3sum vérifie sa propre signature de téléchargement
    # On travaille depuis /usr/local/bin pour que le chemin dans le .b3 corresponde
    cd /usr/local/bin && b3sum --check /tmp/b3sum.b3; \
    \
    echo "b3sum ${B3SUM_VERSION} (${B3SUM_ARCH}) installé et vérifié."

# ── Stage 2 : image finale ───────────────────────────────────────────────────
FROM alpine:3.19

LABEL maintainer="hash_tool" \
      description="Vérification d'intégrité BLAKE3 — integrity.sh + runner.sh" \
      org.opencontainers.image.source="https://github.com/hash_tool"

# Dépendances runtime uniquement : jq + outils POSIX (inclus dans busybox Alpine)
# bash est requis (bash >= 4 pour integrity.sh)
RUN apk add --no-cache \
      bash \
      jq \
      coreutils \
      findutils \
    && rm -rf /var/cache/apk/*

# b3sum depuis le stage fetcher
COPY --from=fetcher /usr/local/bin/b3sum /usr/local/bin/b3sum

# ── Copie des scripts ────────────────────────────────────────────────────────

WORKDIR /app

COPY runner.sh           ./runner.sh
COPY src/integrity.sh    ./src/integrity.sh
COPY src/lib/report.sh   ./src/lib/report.sh

RUN chmod +x runner.sh src/integrity.sh src/lib/report.sh

# ── Entrypoint ───────────────────────────────────────────────────────────────

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Volumes ──────────────────────────────────────────────────────────────────
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
