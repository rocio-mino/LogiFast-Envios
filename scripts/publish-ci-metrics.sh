#!/usr/bin/env bash
# Publica métricas puntuales del pipeline para que Prometheus/Grafana las consulten.
# Requiere que el stack de observabilidad de Docker Compose esté levantado.
set -euo pipefail
cd "$(dirname "$0")/.."

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://127.0.0.1:${PUSHGATEWAY_PORT:-9091}}"
JACOCO_CSV="${JACOCO_CSV:-target/site/jacoco/jacoco.csv}"
DEPLOY_DURATION_SECONDS="${DEPLOY_DURATION_SECONDS:-}"
GIT_COMMIT="${GIT_COMMIT:-local}"
METRICS_INSTANCE="${METRICS_INSTANCE:-local}"

[[ -n "${DEPLOY_DURATION_SECONDS}" ]] || {
  echo "ERROR: define DEPLOY_DURATION_SECONDS con el tiempo medido del despliegue." >&2
  exit 1
}

coverage=""
if [[ -f "${JACOCO_CSV}" ]]; then
  coverage="$(awk -F, 'NR > 1 { missed += $8; covered += $9 } END { total = missed + covered; if (total > 0) printf "%.2f", (covered / total) * 100; else exit 1 }' "${JACOCO_CSV}")"
else
  echo "AVISO: no se encontró ${JACOCO_CSV}; se publicará solo la duración del despliegue." >&2
fi

metrics_file="$(mktemp)"
trap 'rm -f "${metrics_file}"' EXIT
{
  echo '# HELP logifast_deploy_duration_seconds Tiempo de docker compose up hasta que los servicios requeridos quedan healthy.'
  echo '# TYPE logifast_deploy_duration_seconds gauge'
  printf 'logifast_deploy_duration_seconds{environment="docker-compose",commit="%s"} %s\n' "${GIT_COMMIT}" "${DEPLOY_DURATION_SECONDS}"
  if [[ -n "${coverage}" ]]; then
    echo '# HELP logifast_test_coverage_percent Cobertura de líneas JaCoCo del último mvn verify exitoso.'
    echo '# TYPE logifast_test_coverage_percent gauge'
    printf 'logifast_test_coverage_percent{commit="%s"} %s\n' "${GIT_COMMIT}" "${coverage}"
  fi
} > "${metrics_file}"

curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 2 \
  -X PUT --data-binary "@${metrics_file}" \
  "${PUSHGATEWAY_URL%/}/metrics/job/logifast_ep3/instance/${METRICS_INSTANCE}"

echo "Métricas publicadas en Pushgateway: deploy=${DEPLOY_DURATION_SECONDS}s coverage=${coverage:-no-disponible}%"
