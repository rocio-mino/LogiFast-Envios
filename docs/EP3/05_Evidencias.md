# IE1, IE3, IE4 e IE6 — Evidencias de Rocío

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
