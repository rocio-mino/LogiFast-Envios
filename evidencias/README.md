# Evidencias EP2 — IE3, IE4 e IE5

Guardar las capturas en la carpeta de cada indicador con el nombre indicado.
Los logs que genera el pipeline se descargan del run (sección *Artifacts*) y se
copian aquí.

## IE3 — Seguridad y escalabilidad

| # | Archivo | Qué capturar |
|---|---|---|
| 1 | `IE3/01-dependabot-config.png` | *Insights → Dependency graph → Dependabot*: los 4 ecosistemas (maven, github-actions, docker, docker-compose) activos |
| 2 | `IE3/02-dependabot-pr.png` | Un PR abierto por Dependabot con sus checks |
| 2b | `IE3/02b-snyk-bloqueo-real.png` + `IE3/02b-snyk-bloqueo-real.txt` | **Bloqueo real del primer análisis**: run con Snyk en rojo (27 vulnerabilidades, 3 críticas), **Deploy skipped**, y el log del paso Snyk Open Source copiado al `.txt`. Es la mejor evidencia del control bloqueante |
| 3 | `IE3/03-snyk-verde.png` | Run con el job **Seguridad (Snyk)** en verde y su resumen |
| 4 | `IE3/04-snyk-bloqueo.png` | Run de la rama `test/bloqueo-seguridad`: Snyk en rojo y **Deploy skipped** ([procedimiento](../docs/07_CICD_Despliegue.md#5-prueba-del-bloqueo-de-seguridad)) |
| 5 | `IE3/05-snyk-detalle.png` | Log del paso Snyk Open Source mostrando la vulnerabilidad crítica de log4j |
| 6 | `IE3/06-snyk-dashboard.png` | Proyecto `logifast-envios` en app.snyk.io |
| 7 | `IE3/07-branch-protection.png` | Reglas de `main`/`develop` con los checks requeridos |
| 8 | `IE3/08-limites-recursos.txt` | Paso 5 de `02-verificacion.log` (CPU, memoria, pids, usuario, read_only por réplica) |

## IE4 — Despliegue automático y trazabilidad

| # | Archivo | Qué capturar |
|---|---|---|
| 1 | `IE4/01-pipeline-completo.png` | Grafo del run con los 4 jobs en verde (`build-and-test` → `image` / `security` → `deploy`) |
| 2 | `IE4/02-resumen-deploy.png` | *Summary* del run: tabla con commit, imagen `:<sha7>`, image ID |
| 3 | `IE4/03-deployments.png` | Pestaña *Deployments* del repositorio (entorno `simulado`) |
| 4 | `IE4/00-registro-despliegue.json` | Del artefacto `evidencia-deploy-<sha7>` |
| 5 | `IE4/01-deploy.log` | Del artefacto: salida de `docker compose up --wait` |
| 6 | `IE4/02-verificacion.log` | Del artefacto: health, commit verificado, CRUD por el balanceador |
| 7 | `IE4/04-actuator-info.png` | `curl http://localhost:8080/actuator/info` en local mostrando versión y commit |

## IE5 — Orquestación

| # | Archivo | Qué capturar |
|---|---|---|
| 1 | `IE5/01-compose-ps.png` | `docker compose ps` en local: `lb`, 2× `envios-svc` y `db` en estado *healthy* |
| 2 | `IE5/02-healthcheck.png` | `docker inspect --format '{{json .State.Health}}' <contenedor>` de una réplica |
| 3 | `IE5/03-escalado.log` | Del artefacto: salida de `test-scaling.sh` (3 réplicas, reparto, 20/20 durante la caída, reinicio) |
| 4 | `IE5/04-docker-stats.png` | `docker stats --no-stream` con 3 réplicas: consumo frente a los límites |
| 5 | `IE5/05-balanceo.png` | Varias llamadas `curl -i http://localhost:8080/api/envios` mostrando distintos `X-Served-By` |
| 6 | `IE5/06-compose-down.png` | `docker compose down` deteniendo el entorno |
