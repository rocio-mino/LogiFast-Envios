#!/usr/bin/env bash
# =============================================================================
# Reglas de protección de ramas para develop y main (IE5).
# Requiere GitHub CLI autenticado con una cuenta administradora del repositorio
# (gh auth login). En Windows se puede ejecutar desde Git Bash.
#
#   ./scripts/configure-branch-protection.sh apply   # aplica las reglas
#   ./scripts/configure-branch-protection.sh check   # verifica y guarda evidencia
#
# Reglas: Pull Request obligatorio con 1 aprobación, aprobaciones anuladas ante
# nuevos commits, conversaciones resueltas, rama al día con la base, todos los
# controles del pipeline en verde, sin force-push ni borrado, y aplica también
# a administradores.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="${REPO:-rocio-mino/LogiFast-Envios}"
BRANCHES="${BRANCHES:-develop main}"
ACTION="${1:-check}"
EVIDENCE_DIR="${EVIDENCE_DIR:-evidencias/EP3/IE5-Cumplimiento}"

# Nombres de los checks = nombre visible de cada job en .github/workflows/ci.yml
REQUIRED_CHECKS=(
  "build-and-test"
  "Seguridad (Snyk)"
  "SonarCloud (Quality Gate)"
  "Auditoría de cumplimiento"
  "Imagen Docker (build + escaneo)"
  "Kubernetes (validación en kind)"
  "Deploy (entorno simulado)"
)

payload() {
  local checks
  checks="$(printf '%s\n' "${REQUIRED_CHECKS[@]}" | jq -R '{context: .}' | jq -s .)"
  jq -n --argjson checks "${checks}" '{
    required_status_checks: { strict: true, checks: $checks },
    enforce_admins: true,
    required_pull_request_reviews: {
      required_approving_review_count: 1,
      dismiss_stale_reviews: true,
      require_code_owner_reviews: false
    },
    restrictions: null,
    required_conversation_resolution: true,
    allow_force_pushes: false,
    allow_deletions: false
  }'
}

case "${ACTION}" in
  apply)
    for b in ${BRANCHES}; do
      echo "==> Protegiendo ${REPO}:${b}"
      payload | gh api --method PUT "repos/${REPO}/branches/${b}/protection" --input - >/dev/null
      echo "    OK"
    done
    "$0" check
    ;;
  check)
    mkdir -p "${EVIDENCE_DIR}"
    status=0
    for b in ${BRANCHES}; do
      out="${EVIDENCE_DIR}/branch-protection-${b}.json"
      if ! gh api "repos/${REPO}/branches/${b}/protection" > "${out}"; then
        echo "FALLA: ${b} no tiene reglas de protección"; status=1; continue
      fi
      echo "==> ${b}"
      jq -r '"  PR requerido: \(.required_pull_request_reviews != null) (aprobaciones: \(.required_pull_request_reviews.required_approving_review_count // 0))",
             "  checks requeridos: \([.required_status_checks.checks[].context] | join(", "))",
             "  rama al día (strict): \(.required_status_checks.strict)",
             "  admins incluidos: \(.enforce_admins.enabled)",
             "  force-push permitido: \(.allow_force_pushes.enabled) · borrado permitido: \(.allow_deletions.enabled)"' "${out}"
      for c in "${REQUIRED_CHECKS[@]}"; do
        jq -e --arg c "${c}" '[.required_status_checks.checks[].context] | index($c)' "${out}" >/dev/null \
          || { echo "  FALTA el check requerido: ${c}"; status=1; }
      done
    done
    [[ "${status}" -eq 0 ]] && echo "Protección de ramas conforme. Evidencia en ${EVIDENCE_DIR}/"
    exit "${status}"
    ;;
  *)
    echo "Uso: $0 apply|check" >&2
    exit 2
    ;;
esac
