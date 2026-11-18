#!/usr/bin/env bash
# =============================================================================
# Despliegue del entorno local/simulado con observabilidad EP3 (Docker Compose).
# Lo usa el pipeline (job "deploy") y también se puede correr en local.
#
#   ./scripts/deploy.sh            # construye la imagen y despliega
#   SKIP_BUILD=1 ./scripts/deploy.sh   # usa una imagen ya existente (pipeline)
#
# Variables: IMAGE_TAG (por defecto: SHA corto del commit), GIT_COMMIT,
#            APP_REPLICAS (por defecto 2), PORT (por defecto 8080).
# Publica duración del despliegue y cobertura JaCoCo en Pushgateway.
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

# --wait: no termina hasta que los servicios con healthcheck estén "healthy" (o falla).
start_epoch="$(date +%s)"
docker compose up -d ${build_flag} --wait --wait-timeout "${WAIT_TIMEOUT:-300}"
end_epoch="$(date +%s)"
DEPLOY_DURATION_SECONDS="$((end_epoch - start_epoch))"
export DEPLOY_DURATION_SECONDS

echo "==> Duración de despliegue: ${DEPLOY_DURATION_SECONDS}s"
echo "==> Estado de los servicios"
docker compose ps

# Espera a Pushgateway y publica las métricas reales de despliegue/cobertura.
pushgateway_ready=0
for attempt in $(seq 1 30); do
  if curl --fail --silent "http://127.0.0.1:${PUSHGATEWAY_PORT:-9091}/metrics" >/dev/null 2>&1; then
    pushgateway_ready=1
    break
  fi
  sleep 2
done
if [[ "${pushgateway_ready}" -ne 1 ]]; then
  echo "ERROR: Pushgateway no quedó disponible; no se puede publicar la métrica CI." >&2
  exit 1
fi
bash scripts/publish-ci-metrics.sh
