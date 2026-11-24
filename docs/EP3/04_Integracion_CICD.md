# IE4 — Integración de observabilidad en CI/CD (bloque de Rocío)

## Flujo de trabajo

1. Un `push` o Pull Request activa el workflow `.github/workflows/ci.yml`.
2. `build-and-test` ejecuta `mvn verify` y publica JaCoCo/Surefire/Cucumber como artefactos.
3. `image` construye la imagen Docker usando la versión del `pom.xml` y el SHA de Git.
4. `security` ejecuta los controles Snyk ya configurados.
5. `deploy` descarga la misma imagen y el reporte JaCoCo validado, levanta Compose, mide su duración y publica las métricas a Pushgateway.
6. Prometheus recoge métricas de la aplicación, cAdvisor y Pushgateway. Alloy centraliza los logs en Loki. Grafana presenta métricas y logs en un dashboard provisionado.

## Datos trazables

La cobertura y el tiempo de despliegue se publican con la etiqueta `commit`, asociando la muestra al SHA de la ejecución. El endpoint `/actuator/info` sigue mostrando la versión y el commit que se está ejecutando.

## Decisiones técnicas

- Prometheus/Micrometer se utilizan para métricas numéricas consultables mediante PromQL.
- Loki/Alloy se utilizan para centralizar logs de Docker sin desplegar un agente obsoleto.
- Grafana permite correlacionar errores, latencia, CPU, memoria y logs.
- JaCoCo conserva el control de calidad como condición bloqueante; su porcentaje se publica también para análisis.
- Pushgateway se utiliza únicamente para métricas puntuales generadas por el job efímero CI/CD.

## Precauciones

La etapa de observabilidad de Rocío corre localmente y en el entorno Docker Compose del job de CI. No crea recursos AWS. La persistencia de métricas locales depende de los volúmenes Docker; las métricas de una ejecución de GitHub Actions se guardan también como evidencia del artefacto, porque el runner se destruye al terminar el job.


## Verificación de las métricas de CI

Después de la verificación funcional, el workflow ejecuta `scripts/verify-ep3-metrics.sh`. El script consulta la API HTTP de Prometheus y exige muestras reales para duración del despliegue, cobertura JaCoCo, disponibilidad, solicitudes/errores HTTP, CPU y memoria de las réplicas. Los resultados JSON se guardan como evidencias del job. Así se valida la llegada de las métricas al sistema de observabilidad y no solo la respuesta de Pushgateway.

## Continuación

La integración completa, que suma SonarCloud, la auditoría de cumplimiento, la validación en Kubernetes y el despliegue en AWS EKS, y el uso de cada señal para tomar decisiones, se documentan en `09_Integracion_Pipeline_Decisiones.md`.
