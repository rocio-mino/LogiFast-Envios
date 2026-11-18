# IE3 — Dashboard personalizado y métricas CI/CD

## Dashboard provisionado

El dashboard `LogiFast - Observabilidad EP3` se provisiona desde `deploy/observability/grafana/dashboards/logifast-ep3.json`. Las fuentes de datos Prometheus y Loki se cargan desde `grafana/provisioning/datasources/datasources.yml`.

| Panel | Métrica / consulta | Interpretación |
|---|---|---|
| Solicitudes HTTP por segundo | `rate(http_server_requests_seconds_count[5m])` | Volumen de solicitudes atendidas |
| Errores HTTP 4xx/5xx | `status=~"4..|5.."` | Errores del cliente y del servidor |
| Latencia p95 | `histogram_quantile(0.95, ...)` | Latencia por debajo de la cual responde el 95% de solicitudes |
| CPU por contenedor | `100 * rate(container_cpu_usage_seconds_total) / 0.75` | Porcentaje del límite de 0.75 cores configurado por réplica en Compose |
| Memoria por contenedor | `container_memory_working_set_bytes` | Memoria activa de cada réplica frente al límite de 512 MiB |
| Cobertura JaCoCo | `logifast_test_coverage_percent` | Porcentaje real de líneas cubiertas |
| Duración de despliegue | `logifast_deploy_duration_seconds` | Segundos desde el inicio de `docker compose up` hasta que termina `--wait` |
| Disponibilidad | `up{job="logifast-envios"}` | Targets del microservicio que responden al scrape |
| Logs | `{project="logifast-envios"}` | Registros de los contenedores del proyecto |

## Métricas del proceso CI/CD

El script `scripts/publish-ci-metrics.sh` lee `target/site/jacoco/jacoco.csv`, suma líneas cubiertas y no cubiertas, y calcula el porcentaje. La duración se mide alrededor del comando `docker compose up -d --wait` en `scripts/deploy.sh`. Ambos valores se envían por HTTP PUT a Pushgateway, desde donde Prometheus los consulta.

El valor de cobertura es una métrica del último `mvn verify` cuyo reporte se encuentra disponible en `target/site/jacoco/jacoco.csv`; el tiempo es la duración del despliegue de Compose medida en segundos. No se deben ingresar valores manuales ni fabricar muestras.

## Cómo generar actividad para observar

```bash
curl -i http://localhost:8080/api/envios
curl -i -X POST http://localhost:8080/api/envios `
  -H "Content-Type: application/json" `
  -d '{"nombre":"Prueba de observabilidad","origen":"Santiago","pesoKg":1.25}'
curl -i http://localhost:8080/api/envios/999999
```

La última solicitud puede generar una respuesta 404 y debe poder observarse en las métricas HTTP y en los logs.

## Criterios de interpretación

- Aumento de latencia p95: revisar logs, carga de CPU y base de datos.
- Crecimiento de respuestas 5xx: revisar stack traces y disponibilidad de dependencias.
- CPU sostenida alta: revisar carga de solicitudes y límites del contenedor.
- Memoria creciente: revisar uso de heap y comportamiento de la JVM.
- Cobertura bajo el umbral configurado: corregir o ampliar pruebas antes de integrar.
- Duración de despliegue creciente: revisar salud, tiempos de inicio y recursos disponibles.

La visualización es una ayuda para decidir; un panel no sustituye los controles bloqueantes del pipeline.


El panel de CPU normaliza el consumo observado por cAdvisor respecto del límite `0.75` CPU asignado a cada réplica `envios-svc` en `docker-compose.yml`; por tanto, el porcentaje representa uso del límite del contenedor, no porcentaje total de CPU física del computador. La memoria se visualiza en bytes (Grafana la escala automáticamente) y el límite de referencia por réplica es 512 MiB.
