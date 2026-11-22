#!/usr/bin/env bash
# =============================================================================
# Crear, consultar o eliminar el clúster EKS del proyecto (AWS Academy).
# Pensado para AWS CloudShell o una terminal con AWS CLI + eksctl + kubectl
# y las credenciales del Learner Lab cargadas.
#
#   ./scripts/eks-cluster.sh create   # ~15-20 min
#   ./scripts/eks-cluster.sh status
#   ./scripts/eks-cluster.sh delete   # borra balanceador, clúster y repositorio ECR
#
# Variables: AWS_REGION (us-east-1), EKS_CLUSTER_NAME (logifast-eks),
#            ECR_REPOSITORY (logifast-envios), KEEP_ECR=1 para conservar las imágenes.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:-status}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-logifast-eks}"
ECR_REPOSITORY="${ECR_REPOSITORY:-logifast-envios}"

for tool in aws eksctl kubectl; do
  command -v "${tool}" >/dev/null || { echo "ERROR: falta '${tool}' (ver docs/EP3/06_Despliegue_Kubernetes.md)" >&2; exit 1; }
done

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)" \
  || { echo "ERROR: credenciales AWS inválidas o expiradas (inicia el Learner Lab)" >&2; exit 1; }
export AWS_ACCOUNT_ID
echo "Cuenta ${AWS_ACCOUNT_ID} · región ${AWS_REGION} · clúster ${EKS_CLUSTER_NAME}"

render_config() {
  local out
  out="$(mktemp --suffix=.yaml)"
  sed -e "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" \
      -e "s/\${AWS_REGION}/${AWS_REGION}/g" \
      -e "s/\${EKS_CLUSTER_NAME}/${EKS_CLUSTER_NAME}/g" \
      deploy/eks/cluster.yaml.tpl > "${out}"
  echo "${out}"
}

case "${ACTION}" in
  create)
    cfg="$(render_config)"
    echo "==> Configuración generada (${cfg}):"
    cat "${cfg}"
    eksctl create cluster -f "${cfg}"
    aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}"
    kubectl get nodes -o wide
    echo
    echo "Clúster listo. Siguiente paso: configurar secretos/variables en GitHub"
    echo "y ejecutar el workflow (docs/EP3/06_Despliegue_Kubernetes.md)."
    ;;
  status)
    eksctl get cluster --region "${AWS_REGION}" || true
    if aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" >/dev/null 2>&1; then
      aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null
      kubectl get nodes -o wide
      kubectl get pods,svc,hpa -n logifast -o wide || true
      kubectl get pods -n observability || true
    fi
    ;;
  delete)
    if aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" >/dev/null 2>&1; then
      aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null
      echo "==> 1. Eliminando namespaces (libera el Network Load Balancer creado por el Service)"
      kubectl delete namespace logifast observability --ignore-not-found --wait=true --timeout=10m || true
      echo "==> 2. Eliminando el clúster y su VPC (CloudFormation)"
      cfg="$(render_config)"
      eksctl delete cluster -f "${cfg}" --wait --disable-nodegroup-eviction
    else
      echo "El clúster ${EKS_CLUSTER_NAME} no existe."
    fi
    if [[ "${KEEP_ECR:-0}" != "1" ]]; then
      echo "==> 3. Eliminando el repositorio ECR ${ECR_REPOSITORY}"
      aws ecr delete-repository --repository-name "${ECR_REPOSITORY}" --force >/dev/null 2>&1 || true
    fi
    echo "==> Verificación de recursos remanentes"
    aws eks list-clusters --output table
    aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName' --output table || true
    echo "Recuerda poner CLOUD_DEPLOY_ENABLED=false en las variables del repositorio."
    ;;
  *)
    echo "Uso: $0 create|status|delete" >&2
    exit 2
    ;;
esac
