#!/usr/bin/env bash
# =============================================================================
# Verificación post-despliegue en Kubernetes (IE2 + IE1/IE3 en el clúster).
# Falla (exit 1) si cualquier control no se cumple.
#
#   EXPECTED_COMMIT=<sha> IMAGE_TAG=<sha7> ./scripts/verify-k8s.sh
#
# Variables opcionales:
#   PUBLIC_SERVICE   Service LoadBalancer a probar desde Internet (EKS: envios-svc-public)
#   DEPLOY_DURATION_SECONDS / JACOCO_CSV  métricas CI a publicar en el Pushgateway del clúster
#   DEPLOY_ENVIRONMENT  etiqueta de entorno de la métrica (kind | eks)
#   EVIDENCE_DIR     carpeta donde guardar evidencias (por defecto evidencias-k8s)
# Requiere: kubectl, curl, jq
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NS=logifast
OBS_NS=observability
EXPECTED_COMMIT="${EXPECTED_COMMIT:-}"
IMAGE_TAG="${IMAGE_TAG:-}"
PUBLIC_SERVICE="${PUBLIC_SERVICE:-}"
EVIDENCE_DIR="${EVIDENCE_DIR:-evidencias-k8s}"
MIN_REPLICAS="${MIN_REPLICAS:-2}"
mkdir -p "${EVIDENCE_DIR}"

fail() { echo "FALLO: $*" >&2; exit 1; }
ok()   { echo "  OK  $*"; }

pf_pids=()
cleanup() { for p in "${pf_pids[@]:-}"; do [[ -n "${p}" ]] && kill "${p}" 2>/dev/null || true; done; }
trap cleanup EXIT

port_forward() {   # namespace recurso puerto_local:puerto_remoto
  kubectl -n "$1" port-forward "$2" "$3" >/dev/null 2>&1 &
  pf_pids+=("$!")
}
wait_http() {      # url
  for _ in $(seq 1 30); do
    curl -s -o /dev/null "$1" && return 0
    sleep 1
  done
  fail "no responde $1"
}

port_forward "${APP_NS}" svc/envios-svc 18080:8080
port_forward "${APP_NS}" svc/envios-svc 18081:8081
port_forward "${OBS_NS}" svc/prometheus 19090:9090
port_forward "${OBS_NS}" svc/pushgateway 19091:9091
port_forward "${OBS_NS}" svc/loki 13100:3100
API=http://127.0.0.1:18080
MGMT=http://127.0.0.1:18081
wait_http "${API}/api/envios"
wait_http "${MGMT}/actuator/health"
wait_http "http://127.0.0.1:19090/-/ready"
wait_http "http://127.0.0.1:19091/-/ready"
wait_http "http://127.0.0.1:13100/ready"

echo "==> 1. Health, liveness y readiness (puerto interno de administración)"
for path in health health/liveness health/readiness; do
  s="$(curl -fsS "${MGMT}/actuator/${path}" | jq -r .status)"
  [[ "${s}" == "UP" ]] || fail "/actuator/${path} = ${s}"
  ok "/actuator/${path} = UP"
done

echo "==> 2. Trazabilidad commit -> imagen -> pod"
info="$(curl -fsS "${MGMT}/actuator/info")"
echo "${info}" | jq . | tee "${EVIDENCE_DIR}/actuator-info.json"
running_commit="$(jq -r .app.commit <<<"${info}")"
if [[ -n "${EXPECTED_COMMIT}" ]]; then
  [[ "${running_commit}" == "${EXPECTED_COMMIT}" ]] || fail "corre ${running_commit}, se esperaba ${EXPECTED_COMMIT}"
  ok "el pod corre el commit ${EXPECTED_COMMIT}"
fi
kubectl -n "${APP_NS}" get pods -l app.kubernetes.io/name=envios-svc \
  -o custom-columns='POD:.metadata.name,NODO:.spec.nodeName,IMAGEN:.spec.containers[0].image,LISTO:.status.containerStatuses[0].ready,REINICIOS:.status.containerStatuses[0].restartCount' \
  | tee "${EVIDENCE_DIR}/pods-envios.txt"
if [[ -n "${IMAGE_TAG}" ]]; then
  for img in $(kubectl -n "${APP_NS}" get pods -l app.kubernetes.io/name=envios-svc -o jsonpath='{.items[*].spec.containers[0].image}'); do
    [[ "${img}" == *":${IMAGE_TAG}" ]] || fail "pod con imagen ${img}; se esperaba la etiqueta ${IMAGE_TAG}"
  done
  ok "todas las réplicas usan la imagen :${IMAGE_TAG}"
fi

echo "==> 3. Disponibilidad"
ready="$(kubectl -n "${APP_NS}" get deployment envios-svc -o jsonpath='{.status.readyReplicas}')"
[[ "${ready:-0}" -ge "${MIN_REPLICAS}" ]] || fail "solo ${ready:-0} réplicas listas (mínimo ${MIN_REPLICAS})"
ok "${ready} réplicas listas; HPA y PDB:"
kubectl -n "${APP_NS}" get hpa,pdb

echo "==> 4. Seguridad de los pods (Pod Security 'restricted')"
for ns in "${APP_NS}" "${OBS_NS}"; do
  level="$(kubectl get namespace "${ns}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')"
  [[ "${level}" == "restricted" ]] || fail "namespace ${ns} sin Pod Security restricted"
done
ok "namespaces ${APP_NS} y ${OBS_NS} con Pod Security 'restricted' (el clúster rechaza pods inseguros)"
kubectl -n "${APP_NS}" get pods -o jsonpath='{range .items[*]}{.metadata.name}{" runAsNonRoot="}{.spec.securityContext.runAsNonRoot}{" uid="}{.spec.securityContext.runAsUser}{"\n"}{end}'

echo "==> 5. API de negocio (CRUD)"
body='{"nombre":"Envio smoke test k8s","origen":"Santiago","pesoKg":2.5}'
resp="$(curl -sS -w '\n%{http_code}' -X POST "${API}/api/envios" -H 'Content-Type: application/json' -d "${body}")"
code="$(tail -n 1 <<<"${resp}")"
[[ "${code}" == "201" ]] || fail "POST /api/envios -> ${code}"
id="$(sed '$d' <<<"${resp}" | jq -r .id)"
ok "POST /api/envios -> 201 (id=${id})"
code="$(curl -s -o /dev/null -w '%{http_code}' "${API}/api/envios/${id}")"
[[ "${code}" == "200" ]] || fail "GET /api/envios/${id} -> ${code}"
ok "GET /api/envios/${id} -> 200"
code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "${API}/api/envios/${id}")"
[[ "${code}" == "204" ]] || fail "DELETE -> ${code}"
code="$(curl -s -o /dev/null -w '%{http_code}' "${API}/api/envios/${id}")"
[[ "${code}" == "404" ]] || fail "GET tras borrar -> ${code}"
ok "DELETE -> 204 y GET posterior -> 404 (genera error 4xx observable)"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "${API}/api/envios" -H 'Content-Type: application/json' -d '{"origen":"sin nombre"}')"
[[ "${code}" == "400" ]] || fail "POST inválido -> ${code}"
ok "POST inválido -> 400"

echo "==> 6. Exposición: Actuator no accesible por el puerto del API"
for path in /actuator/prometheus /actuator/env /actuator/health /h2-console; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${API}${path}")"
  [[ "${code}" == "404" ]] || fail "${path} accesible por el puerto público (${code})"
done
ok "/actuator/* y /h2-console -> 404 en el puerto del API"

if [[ -n "${PUBLIC_SERVICE}" ]]; then
  echo "==> 7. Acceso público por el balanceador de AWS (${PUBLIC_SERVICE})"
  host=""
  for _ in $(seq 1 60); do
    host="$(kubectl -n "${APP_NS}" get svc "${PUBLIC_SERVICE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{.status.loadBalancer.ingress[0].ip}')"
    [[ -n "${host}" ]] && break
    sleep 5
  done
  [[ -n "${host}" ]] || fail "el Service ${PUBLIC_SERVICE} no obtuvo dirección pública"
  code=""
  for _ in $(seq 1 60); do   # el DNS del NLB tarda unos minutos en propagarse
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${host}/api/envios" || true)"
    [[ "${code}" == "200" ]] && break
    sleep 10
  done
  [[ "${code}" == "200" ]] || fail "http://${host}/api/envios -> ${code}"
  ok "http://${host}/api/envios -> 200"
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${host}/actuator/prometheus" || true)"
  [[ "${code}" == "404" ]] || fail "métricas expuestas públicamente (${code})"
  ok "http://${host}/actuator/prometheus -> 404"
  echo "http://${host}" > "${EVIDENCE_DIR}/url-publica.txt"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "public_url=http://${host}" >> "${GITHUB_OUTPUT}"
  fi
fi

echo "==> 8. Métricas CI hacia el Pushgateway del clúster"
if [[ -n "${DEPLOY_DURATION_SECONDS:-}" ]]; then
  PUSHGATEWAY_URL=http://127.0.0.1:19091 GIT_COMMIT="${EXPECTED_COMMIT:-local}" \
    METRICS_INSTANCE="${DEPLOY_ENVIRONMENT:-k8s}" DEPLOY_ENVIRONMENT="${DEPLOY_ENVIRONMENT:-k8s}" \
    bash scripts/publish-ci-metrics.sh
else
  echo "  (sin DEPLOY_DURATION_SECONDS: se omite la publicación)"
fi

echo "==> 9. Prometheus: targets, métricas de la app, CPU/memoria por pod y métricas CI"
curl -fsS http://127.0.0.1:19090/api/v1/targets \
  | jq '[.data.activeTargets[] | {job: .labels.job, pod: .labels.pod, health}]' \
  | tee "${EVIDENCE_DIR}/prometheus-targets.json"
PROMETHEUS_URL=http://127.0.0.1:19090 EVIDENCE_DIR="${EVIDENCE_DIR}" MAX_ATTEMPTS=45 \
  CONTAINER_SELECTOR='namespace="logifast",container="envios-svc"' \
  bash scripts/verify-ep3-metrics.sh

echo "==> 10. Loki: logs de los pods centralizados por Alloy"
count=0
for _ in $(seq 1 30); do
  count="$(curl -fsS --get --data-urlencode 'query={project="logifast-envios",container="envios-svc"}' \
    --data-urlencode "start=$(( $(date +%s) - 1800 ))000000000" --data-urlencode 'limit=20' \
    http://127.0.0.1:13100/loki/api/v1/query_range 2>/dev/null \
    | tee "${EVIDENCE_DIR}/loki-logs.json" | jq '[.data.result[].values[]] | length' 2>/dev/null || echo 0)"
  [[ "${count}" =~ ^[0-9]+$ ]] && (( count > 0 )) && break
  sleep 4
done
(( count > 0 )) || fail "Loki no tiene logs de envios-svc"
ok "Loki devolvió ${count} líneas de log de envios-svc"

echo
echo "VERIFICACIÓN KUBERNETES EXITOSA"
