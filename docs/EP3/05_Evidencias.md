# Evidencias EP3 (Rocío y Martín)

## IE1, IE3, IE4 e IE6 — Evidencias de Rocío

Guardar capturas reales y salidas de comandos. No usar imágenes de ejemplo ni datos simulados como evidencia de funcionamiento.

| Indicador | Evidencia | Qué debe demostrar |
|---|---|---|
| IE1 | `IE1-Monitoreo/01-prometheus-targets.png` | Target(s) `logifast-envios` en estado UP |
| IE1 | `IE1-Monitoreo/02-actuator-prometheus.txt` | El endpoint interno devuelve métricas Micrometer |
| IE1 | `IE1-Monitoreo/03-logs-grafana.png` | Logs reales de `envios-svc` visibles en Grafana/Loki |
| IE1 | `IE1-Monitoreo/04-disponibilidad.png` | Health/availability de los targets |
| IE3 | `IE3-Dashboard/01-dashboard-completo.png` | Dashboard provisionado con los paneles principales |
| IE3 | `IE3-Dashboard/02-cobertura-y-despliegue.png` | Cobertura y duración publicadas a Pushgateway |
| IE3 | `IE3-Dashboard/03-cpu-memoria-errores.png` | Métricas de recursos y errores con actividad real |
| IE3 / IE4 | Artefacto CI `evidencia-deploy-<sha>`: `08` a `14-*.json` | JSON consultados desde Prometheus: duración, cobertura, disponibilidad, HTTP, CPU y memoria |
| IE4 | `IE4-Documentacion/01-pipeline-observabilidad.png` | Workflow y artefactos de JaCoCo/CI |
| IE4 | `IE4-Documentacion/02-metricas-ci.prom` | Métricas de CI obtenidas desde una ejecución real |
| IE6 | `IE6-Bloqueos/01-bloqueo-calidad.png` | Falla de prueba/cobertura que detiene `build-and-test` y omite deploy |
| IE6 | `IE6-Bloqueos/02-deploy-skipped.png` | Job deploy aparece `skipped` |
| IE6 | `IE6-Bloqueos/03-pr-temporal-cerrado.png` | PR de prueba cerrado sin fusionar el test fallido |

Las evidencias de bloqueo deben capturarse de una rama temporal que no se integre a las ramas estables.

## IE2, IE4, IE5 e IE6 — Evidencias de Martín

Cada archivo debe venir de una ejecución real (GitHub Actions, AWS o SonarCloud). Además de las capturas, se conservan los artefactos de cada run: `evidencia-k8s-kind-<sha7>`, `evidencia-eks-<sha7>`, `evidencia-sonarcloud-<sha>` y `evidencia-auditoria-<sha>`.

| Indicador | Evidencia | Qué debe demostrar |
|---|---|---|
| IE2 | `IE2-Despliegue/01-eks-cluster-consola.png`, `01b`, `01c`, `01d` | Clúster `logifast-eks` activo, 2 nodos *Ready* y su creación con eksctl |
| IE2 | `IE2-Despliegue/03-api-publica.png`, `03b-actuator-no-expuesto.png` | API respondiendo por el NLB público; `/actuator/prometheus` en 404 |
| IE2 | `IE2-Despliegue/04-pipeline-deploy-eks.png`, `04b-resumen-deploy-eks.png` | Job `Deploy cloud (AWS EKS)` en verde y su resumen de trazabilidad |
| IE2 | `IE2-Despliegue/05-ecr-imagen-sha.png` | Imágenes en ECR con etiqueta = SHA del commit |
| IE2 | `IE2-Despliegue/06-grafana-eks.png`, `06a-grafana-eks-trafico.png` | Dashboard Kubernetes con métricas del clúster EKS |
| IE2 | `IE2-Despliegue/07-rollout-history-y-recursos.png`, `07-rollout-history.txt` | Revisiones del Deployment asociadas a commit e imagen |
| IE2 | `IE2-Despliegue/08-kind-validacion.png` | Job `Kubernetes (validación en kind)` en verde |
| IE2 | `IE2-Despliegue/09-recursos-eliminados.txt` | Clúster, NLB y ECR eliminados al terminar |
| IE4 | `IE4-Documentacion/03-pipeline-completo.png` | Grafo del workflow con todos los controles y despliegues |
| IE5 | `IE5-Cumplimiento/01-sonarcloud-quality-gate.png`, `01b-sonarcloud-condiciones.png` | Quality Gate *Passed* y condiciones con su valor real |
| IE5 | `IE5-Cumplimiento/02-auditoria-cumplimiento.png` | Resumen CMP-01..08 y Gitleaks sin hallazgos |
| IE5 | `IE5-Cumplimiento/03-branch-protection-develop.png`, `04-branch-protection-main.png` | Reglas de protección configuradas |
| IE5 | `IE5-Cumplimiento/branch-protection-*.json` | Salida de `scripts/configure-branch-protection.sh check` |
| IE5 | `IE5-Cumplimiento/05-pr-checks-obligatorios.png` | PR con checks requeridos |
| IE6 | `IE6-Bloqueos/04-bloqueo-seguridad-snyk.png` | Snyk detecta la dependencia vulnerable y falla |
| IE6 | `IE6-Bloqueos/05-bloqueo-seguridad-deploy-skipped.png` | Despliegue omitido tras la falla de seguridad |
| IE6 | `IE6-Bloqueos/06-bloqueo-auditoria.png` | Auditoría rechaza un contenedor privilegiado |
| IE6 | `IE6-Bloqueos/07-pr-seguridad-bloqueado.png`, `08-pr-seguridad-cerrado.png` | PR bloqueado y cerrado sin fusionar |
