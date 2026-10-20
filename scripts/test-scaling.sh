#!/usr/bin/env bash
# =============================================================================
# IE5 — Prueba de escalado horizontal, balanceo y autorrecuperación.
#
#   1. Escala envios-svc a SCALE_TO réplicas (por defecto 3) sin cortar el servicio.
#   2. Comprueba que el balanceador reparte peticiones entre todas.
#   3. Simula la caída de una réplica y verifica que el servicio sigue respondiendo.
#   4. Verifica que la réplica caída se reinicia sola (restart: unless-stopped).
#   5. Vuelve al número de réplicas base (APP_REPLICAS).
#
# Requiere: docker, curl, jq. Se ejecuta con el entorno ya desplegado.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_URL="${BASE_URL:-http://localhost:${PORT:-8080}}"
APP_REPLICAS="${APP_REPLICAS:-2}"
SCALE_TO="${SCALE_TO:-3}"
export APP_REPLICAS

fail() { echo "FALLO: $*" >&2; exit 1; }
ok()   { echo "  OK  $*"; }

count_healthy() {
  local n=0
  for c in $(docker compose ps -q envios-svc); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "${c}")" == "healthy" ]] && n=$((n + 1))
  done
  echo "${n}"
}

wait_healthy() {
  local want="$1" timeout="${2:-180}" waited=0
  until [[ "$(count_healthy)" -ge "${want}" ]]; do
    sleep 3; waited=$((waited + 3))
    [[ "${waited}" -lt "${timeout}" ]] || fail "no se alcanzaron ${want} réplicas sanas en ${timeout}s"
  done
}

distinct_instances() {
  # Cuenta cuántas réplicas distintas responden en N peticiones
  for _ in $(seq 1 "$1"); do
    curl -fsS "${BASE_URL}/actuator/info" | jq -r .app.instance
  done | sort -u
}

echo "==> 1. Escalado horizontal: ${APP_REPLICAS} -> ${SCALE_TO} réplicas"
docker compose up -d --no-build --no-recreate --scale "envios-svc=${SCALE_TO}" --wait --wait-timeout 240
wait_healthy "${SCALE_TO}"
docker compose ps envios-svc
ok "${SCALE_TO} réplicas healthy"

echo "==> 2. Balanceo de carga entre réplicas"
sleep 6   # el balanceador vuelve a resolver el DNS cada 5 s
instances="$(distinct_instances $((SCALE_TO * 4)))"
while read -r i; do echo "  respondió: ${i}"; done <<<"${instances}"
n="$(echo "${instances}" | grep -c .)"
[[ "${n}" -ge "${SCALE_TO}" ]] || fail "solo ${n} de ${SCALE_TO} réplicas recibieron tráfico"
ok "el tráfico se reparte entre ${n} réplicas"

echo "==> 3. Tolerancia a fallos: se detiene el proceso Java de una réplica"
victim="$(docker compose ps -q envios-svc | head -n 1)"
victim_name="$(docker inspect -f '{{.Name}}' "${victim}")"
restarts_before="$(docker inspect -f '{{.RestartCount}}' "${victim}")"
docker exec "${victim}" sh -c 'kill 1' || true
echo "  réplica afectada: ${victim_name}"
ok_count=0; total=20
for _ in $(seq 1 "${total}"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/api/envios")"
  [[ "${code}" == "200" ]] && ok_count=$((ok_count + 1))
  sleep 0.3
done
echo "  ${ok_count}/${total} peticiones exitosas durante la caída"
[[ "${ok_count}" -eq "${total}" ]] || fail "el servicio perdió peticiones durante la caída de una réplica"
ok "el servicio siguió respondiendo con una réplica caída"

echo "==> 4. Autorrecuperación (restart: unless-stopped + healthcheck)"
waited=0
until [[ "$(docker inspect -f '{{.RestartCount}}' "${victim}")" -gt "${restarts_before}" ]]; do
  sleep 2; waited=$((waited + 2))
  [[ "${waited}" -lt 90 ]] || fail "Docker no reinició la réplica ${victim_name}"
done
restarts_after="$(docker inspect -f '{{.RestartCount}}' "${victim}")"
echo "  ${victim_name}: reinicios ${restarts_before} -> ${restarts_after}"
sleep 5
wait_healthy "${SCALE_TO}" 240
ok "la réplica se reinició sola y volvió a estar healthy"

echo "==> 5. Uso de recursos con ${SCALE_TO} réplicas"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}'

echo "==> 6. Vuelta a ${APP_REPLICAS} réplicas"
docker compose up -d --no-build --no-recreate --scale "envios-svc=${APP_REPLICAS}" --wait --wait-timeout 240
docker compose ps envios-svc
ok "escalado hacia abajo completado"

echo
echo "PRUEBA DE ESCALADO Y AUTORRECUPERACIÓN EXITOSA"
