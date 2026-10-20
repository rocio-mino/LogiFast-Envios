#!/usr/bin/env bash
# =============================================================================
# IE4 — Verificación post-despliegue.
# Falla (exit 1) si cualquiera de los chequeos no se cumple; en el pipeline eso
# marca el despliegue como fallido.
#
#   ./scripts/verify-deploy.sh
#   EXPECTED_COMMIT=<sha> ./scripts/verify-deploy.sh   # exige que corra ese commit
#
# Requiere: docker, curl, jq
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_URL="${BASE_URL:-http://localhost:${PORT:-8080}}"
APP_REPLICAS="${APP_REPLICAS:-2}"
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"

fail() { echo "FALLO: $*" >&2; exit 1; }
ok()   { echo "  OK  $*"; }

echo "==> 1. Endpoint de salud (${BASE_URL}/actuator/health)"
status=""
for _ in $(seq 1 30); do
  status="$(curl -fsS "${BASE_URL}/actuator/health" 2>/dev/null | jq -r .status 2>/dev/null || true)"
  [[ "${status}" == "UP" ]] && break
  sleep 2
done
[[ "${status}" == "UP" ]] || fail "health no responde UP (último estado: '${status}')"
ok "health = UP"
for probe in liveness readiness; do
  s="$(curl -fsS "${BASE_URL}/actuator/health/${probe}" | jq -r .status)"
  [[ "${s}" == "UP" ]] || fail "${probe} = ${s}"
  ok "${probe} = UP"
done

echo "==> 2. Trazabilidad: versión y commit en ejecución (/actuator/info)"
info="$(curl -fsS "${BASE_URL}/actuator/info")"
echo "${info}" | jq .
running_commit="$(echo "${info}" | jq -r .app.commit)"
if [[ -n "${EXPECTED_COMMIT}" ]]; then
  [[ "${running_commit}" == "${EXPECTED_COMMIT}" ]] \
    || fail "corre el commit ${running_commit}, se esperaba ${EXPECTED_COMMIT}"
  ok "el servicio corre el commit esperado ${EXPECTED_COMMIT}"
else
  ok "commit en ejecución: ${running_commit}"
fi

echo "==> 3. Imagen desplegada"
docker compose images envios-svc
if [[ -n "${IMAGE_TAG:-}" ]]; then
  for c in $(docker compose ps -q envios-svc); do
    img="$(docker inspect -f '{{.Config.Image}}' "${c}")"
    [[ "${img}" == *":${IMAGE_TAG}" ]] || fail "el contenedor ${c} usa ${img}, se esperaba la etiqueta ${IMAGE_TAG}"
  done
  ok "todas las réplicas usan la etiqueta ${IMAGE_TAG}"
fi

echo "==> 4. Réplicas sanas"
healthy=0
for c in $(docker compose ps -q envios-svc); do
  h="$(docker inspect -f '{{.State.Health.Status}}' "${c}")"
  echo "  $(docker inspect -f '{{.Name}}' "${c}") -> ${h}"
  [[ "${h}" == "healthy" ]] && healthy=$((healthy + 1))
done
[[ "${healthy}" -ge "${APP_REPLICAS}" ]] || fail "solo ${healthy}/${APP_REPLICAS} réplicas sanas"
ok "${healthy}/${APP_REPLICAS} réplicas healthy"

echo "==> 5. Límites de recursos aplicados"
for c in $(docker compose ps -q envios-svc); do
  read -r name cpus mem pids user ro <<<"$(docker inspect -f '{{.Name}} {{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.PidsLimit}} {{.Config.User}} {{.HostConfig.ReadonlyRootfs}}' "${c}")"
  [[ "${cpus}" -gt 0 && "${mem}" -gt 0 ]] || fail "${name} no tiene límites de CPU/memoria"
  echo "  ${name}: cpus=$(awk "BEGIN{print ${cpus}/1e9}") memoria=$((mem / 1024 / 1024))MiB pids=${pids} user=${user} read_only=${ro}"
done
ok "límites de CPU y memoria presentes en todas las réplicas"

echo "==> 6. Prueba funcional del API a través del balanceador (CRUD)"
body='{"nombre":"Envio smoke test","origen":"Santiago","pesoKg":2.5}'
resp="$(curl -sS -w '\n%{http_code}' -X POST "${BASE_URL}/api/envios" -H 'Content-Type: application/json' -d "${body}")"
code="$(tail -n 1 <<<"${resp}")"
created="$(sed '$d' <<<"${resp}")"
[[ "${code}" == "201" ]] || fail "POST /api/envios -> ${code} (se esperaba 201)"
id="$(echo "${created}" | jq -r .id)"
[[ "${id}" =~ ^[0-9]+$ ]] || fail "POST no devolvió un id (${created})"
ok "POST /api/envios -> 201 (id=${id})"
# Se consulta varias veces: cada petición puede caer en una réplica distinta y
# todas deben ver el mismo dato porque comparten la base de datos.
for _ in 1 2 3 4; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/api/envios/${id}")"
  [[ "${code}" == "200" ]] || fail "GET /api/envios/${id} -> ${code}"
done
ok "GET /api/envios/${id} -> 200 en todas las réplicas"
code="$(curl -s -o /dev/null -w '%{http_code}' -X PUT "${BASE_URL}/api/envios/${id}" -H 'Content-Type: application/json' -d '{"nombre":"Envio actualizado","origen":"Valparaiso","pesoKg":3}')"
[[ "${code}" == "200" ]] || fail "PUT -> ${code}"
ok "PUT /api/envios/${id} -> 200"
code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "${BASE_URL}/api/envios/${id}")"
[[ "${code}" == "204" ]] || fail "DELETE -> ${code}"
ok "DELETE /api/envios/${id} -> 204"
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/api/envios/${id}")"
[[ "${code}" == "404" ]] || fail "GET después de borrar -> ${code}"
ok "GET /api/envios/${id} -> 404 tras eliminar"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${BASE_URL}/api/envios" -H 'Content-Type: application/json' -d '{"origen":"sin nombre"}')"
[[ "${code}" == "400" ]] || fail "POST inválido -> ${code} (se esperaba 400)"
ok "POST inválido -> 400 (validación activa)"

echo "==> 7. Seguridad del despliegue"
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/actuator/env")"
[[ "${code}" == "404" ]] || fail "/actuator/env expuesto (${code})"
ok "/actuator/env no expuesto (404)"
code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/h2-console")"
[[ "${code}" == "404" ]] || fail "/h2-console expuesta (${code})"
ok "consola H2 deshabilitada (404)"

echo
echo "VERIFICACIÓN POST-DEPLOY EXITOSA"
