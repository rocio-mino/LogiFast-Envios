#!/usr/bin/env bash
# Verifica que las métricas reales del pipeline llegaron a Prometheus.
# Genera JSON de evidencia para IE3/IE4. Requiere curl y jq.
set -euo pipefail
cd "$(dirname "$0")/.."

PROMETHEUS_URL="${PROMETHEUS_URL:-http://127.0.0.1:${PROMETHEUS_PORT:-9090}}"
EVIDENCE_DIR="${EVIDENCE_DIR:-evidencias-ci}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"
mkdir -p "${EVIDENCE_DIR}"

query_metric() {
  local metric="$1"
  local output="$2"
  local response=""
  local count=0

  echo "==> Consultando ${metric} en Prometheus"
  for _ in $(seq 1 "${MAX_ATTEMPTS}"); do
    response="$(curl --fail --silent --show-error --get \
      --data-urlencode "query=${metric}" \
      "${PROMETHEUS_URL%/}/api/v1/query" 2>/dev/null || true)"
    count="$(jq -r 'if .status == "success" then (.data.result | length) else 0 end' \
      <<<"${response}" 2>/dev/null || echo 0)"
    if [[ "${count}" =~ ^[0-9]+$ ]] && (( count > 0 )); then
      printf '%s\n' "${response}" > "${EVIDENCE_DIR}/${output}"
      jq -r '.data.result[] | "  valor=\(.value[1]) labels=\(.metric)"' <<<"${response}"
      return 0
    fi
    sleep "${SLEEP_SECONDS}"
  done

  echo "ERROR: Prometheus no devolvió muestras para ${metric} después de $((MAX_ATTEMPTS * SLEEP_SECONDS)) segundos." >&2
  [[ -z "${response}" ]] || printf '%s\n' "${response}" >&2
  return 1
}

query_metric 'logifast_deploy_duration_seconds' '08-deploy-duration.json'
query_metric 'logifast_test_coverage_percent' '09-test-coverage.json'
query_metric 'up{job="logifast-envios"} == 1' '10-availability.json'
query_metric 'http_server_requests_seconds_count{application="envios-svc"}' '11-http-requests.json'
query_metric 'http_server_requests_seconds_count{application="envios-svc",status=~"4..|5.."} > 0' '12-http-errors.json'
query_metric 'container_cpu_usage_seconds_total{container_label_com_docker_compose_service="envios-svc"}' '13-cpu-containers.json'
query_metric 'container_memory_working_set_bytes{container_label_com_docker_compose_service="envios-svc"}' '14-memory-containers.json'

echo "OK: métricas CI, disponibilidad, solicitudes, errores, CPU y memoria fueron consultadas desde Prometheus."
