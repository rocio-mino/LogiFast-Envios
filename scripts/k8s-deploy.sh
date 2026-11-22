#!/usr/bin/env bash
# =============================================================================
# Despliegue del microservicio y su observabilidad en Kubernetes (IE2).
# Lo usan los jobs "k8s-validate" (kind) y "deploy-eks" (AWS EKS) del pipeline,
# y también se puede ejecutar a mano con un kubeconfig válido.
#
#   K8S_TARGET=kind IMAGE_NAME=duoc/jv0101-caso17-envios IMAGE_TAG=abc1234 \
#   GIT_COMMIT=<sha> ./scripts/k8s-deploy.sh
#
# Variables:
#   K8S_TARGET     overlay a usar: kind | eks                 (obligatoria)
#   IMAGE_NAME     repositorio de la imagen (p. ej. URI de ECR) (obligatoria)
#   IMAGE_TAG      etiqueta inmutable = SHA corto del commit    (obligatoria)
#   GIT_COMMIT     SHA completo (trazabilidad en /actuator/info)
#   APP_VERSION    versión del pom.xml
#   PIPELINE_RUN   URL de la ejecución de GitHub Actions
#   ROLLOUT_TIMEOUT tiempo máximo de espera por Deployment (por defecto 600s)
#
# Escribe DEPLOY_DURATION_SECONDS en $GITHUB_ENV cuando corre en Actions.
# Nunca guarda credenciales en Git: los Secrets se generan aquí si no existen.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

: "${K8S_TARGET:?Define K8S_TARGET (kind o eks)}"
: "${IMAGE_NAME:?Define IMAGE_NAME}"
: "${IMAGE_TAG:?Define IMAGE_TAG}"
GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
APP_VERSION="${APP_VERSION:-1.0.0}"
PIPELINE_RUN="${PIPELINE_RUN:-local}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-600s}"
APP_NS=logifast
OBS_NS=observability
RELEASE_DIR=deploy/k8s/overlays/release

[[ -d "deploy/k8s/overlays/${K8S_TARGET}" ]] || { echo "ERROR: overlay desconocido '${K8S_TARGET}'" >&2; exit 1; }

echo "==> Contexto Kubernetes: $(kubectl config current-context)"
kubectl version 2>/dev/null | sed 's/^/    /' || true
kubectl get nodes -o wide

echo "==> 1. Overlay de release (imagen ${IMAGE_NAME}:${IMAGE_TAG}, commit ${GIT_COMMIT})"
mkdir -p "${RELEASE_DIR}"
cat > "${RELEASE_DIR}/kustomization.yaml" <<EOF
# Generado por scripts/k8s-deploy.sh — no se versiona.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../${K8S_TARGET}
images:
  - name: logifast-envios
    newName: ${IMAGE_NAME}
    newTag: "${IMAGE_TAG}"
configMapGenerator:
  - name: envios-build-info
    namespace: ${APP_NS}
    behavior: merge
    literals:
      - commit=${GIT_COMMIT}
      - version=${APP_VERSION}
      - pipeline-run=${PIPELINE_RUN}
EOF
cat "${RELEASE_DIR}/kustomization.yaml"

echo "==> 2. Namespaces (Pod Security 'restricted')"
kubectl apply -f deploy/k8s/base/namespace.yaml -f deploy/k8s/observability/namespace.yaml

echo "==> 3. Secrets (se crean una sola vez, con valores aleatorios, fuera de Git)"
if ! kubectl -n "${APP_NS}" get secret envios-db >/dev/null 2>&1; then
  kubectl -n "${APP_NS}" create secret generic envios-db \
    --from-literal=username=envios \
    --from-literal=password="$(openssl rand -hex 24)"
  echo "    Secret envios-db creado"
else
  echo "    Secret envios-db ya existe (se conserva)"
fi
if ! kubectl -n "${OBS_NS}" get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n "${OBS_NS}" create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -hex 16)"
  echo "    Secret grafana-admin creado (ver docs/EP3/06_Despliegue_Kubernetes.md para leerlo)"
else
  echo "    Secret grafana-admin ya existe (se conserva)"
fi

echo "==> 4. Aplicando manifiestos"
start_epoch="$(date +%s)"
kubectl apply -k "${RELEASE_DIR}"

echo "==> 5. Esperando rollouts (timeout ${ROLLOUT_TIMEOUT})"
rollout_ok=1
for d in postgres envios-svc; do
  kubectl -n "${APP_NS}" rollout status "deployment/${d}" --timeout="${ROLLOUT_TIMEOUT}" || rollout_ok=0
done
for d in prometheus pushgateway loki alloy grafana; do
  kubectl -n "${OBS_NS}" rollout status "deployment/${d}" --timeout="${ROLLOUT_TIMEOUT}" || rollout_ok=0
done
end_epoch="$(date +%s)"
DEPLOY_DURATION_SECONDS="$((end_epoch - start_epoch))"

if [[ "${rollout_ok}" -ne 1 ]]; then
  echo "ERROR: uno o más Deployments no quedaron disponibles. Diagnóstico:" >&2
  kubectl get pods -A -o wide >&2 || true
  kubectl -n "${APP_NS}" get events --sort-by=.lastTimestamp >&2 || true
  kubectl -n "${OBS_NS}" get events --sort-by=.lastTimestamp >&2 || true
  kubectl -n "${APP_NS}" logs deployment/envios-svc --tail=80 >&2 || true
  exit 1
fi

echo "==> 6. Trazabilidad en el Deployment (kubectl rollout history)"
kubectl -n "${APP_NS}" annotate deployment/envios-svc --overwrite \
  "kubernetes.io/change-cause=commit ${GIT_COMMIT} imagen ${IMAGE_NAME}:${IMAGE_TAG} run ${PIPELINE_RUN}" \
  "logifast.cl/commit=${GIT_COMMIT}" \
  "logifast.cl/image=${IMAGE_NAME}:${IMAGE_TAG}" \
  "logifast.cl/pipeline-run=${PIPELINE_RUN}"
kubectl -n "${APP_NS}" rollout history deployment/envios-svc

echo "==> Duración del despliegue: ${DEPLOY_DURATION_SECONDS}s"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DEPLOY_DURATION_SECONDS=${DEPLOY_DURATION_SECONDS}" >> "${GITHUB_ENV}"
fi
kubectl get pods -n "${APP_NS}" -o wide
kubectl get pods -n "${OBS_NS}" -o wide
echo "DESPLIEGUE KUBERNETES (${K8S_TARGET}) COMPLETADO"
