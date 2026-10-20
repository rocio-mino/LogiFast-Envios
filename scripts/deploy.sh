#!/usr/bin/env bash
# =============================================================================
# IE4 — Despliegue en el entorno simulado (Docker Compose).
# Lo usa el pipeline (job "deploy") y también se puede correr en local.
#
#   ./scripts/deploy.sh            # construye la imagen y despliega
#   SKIP_BUILD=1 ./scripts/deploy.sh   # usa una imagen ya existente (pipeline)
#
# Variables: IMAGE_TAG (por defecto: SHA corto del commit), GIT_COMMIT,
#            APP_REPLICAS (por defecto 2), PORT (por defecto 8080).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short=7 HEAD 2>/dev/null || echo local)}"
APP_REPLICAS="${APP_REPLICAS:-2}"
export GIT_COMMIT IMAGE_TAG APP_REPLICAS

echo "==> Desplegando envios-svc"
echo "    commit   : ${GIT_COMMIT}"
echo "    imagen   : ${IMAGE_NAME:-duoc/jv0101-caso17-envios}:${IMAGE_TAG}"
echo "    réplicas : ${APP_REPLICAS}"

build_flag="--build"
if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
  build_flag="--no-build"
fi

# --wait: no termina hasta que todos los servicios estén "healthy" (o falla)
docker compose up -d ${build_flag} --wait --wait-timeout "${WAIT_TIMEOUT:-300}"

echo "==> Estado de los servicios"
docker compose ps
