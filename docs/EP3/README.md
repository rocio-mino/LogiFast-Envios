
# EP3 — DOY0101 Ingeniería DevOps

Documentación de la tercera evaluación parcial de LogiFast-Envios.

## Alcance del trabajo de Rocío

- IE1: observabilidad, métricas y centralización de logs.
- IE3: dashboard Grafana y métricas de CI/CD.
- IE4: documentación de la integración de observabilidad.
- IE6: validación de calidad y bloqueo ante pruebas fallidas.

La infraestructura cloud y los controles adicionales de cumplimiento corresponden al bloque de Martín.

## Restricción de cuenta AWS estudiante

El trabajo local de Rocío utiliza Docker Compose y herramientas open source. No crea recursos AWS ni genera cargos en la cuenta educativa.

La eventual integración cloud se revisará en el bloque de Martín, verificando previamente créditos, límites y costos.

## Documentos

- 01 — Observabilidad, métricas y logs.
- 02 — Dashboard y métricas CI/CD.
- 03 — Validación de calidad y bloqueo.
- 04 — Integración en el pipeline CI/CD.
- 05 — Evidencias.

## Validaciones realizadas localmente

Fecha: 18 de noviembre de 2026.

### Maven y calidad

- `mvn clean verify`: BUILD SUCCESS.
- JaCoCo: 43 líneas cubiertas de 43.
- Cobertura de líneas: 100%.
- Prueba controlada: 27 pruebas ejecutadas, una falla intencional y BUILD FAILURE.
- Código de salida de Maven ante la falla: 1.
- Prueba temporal eliminada y BUILD SUCCESS posterior.

### Docker y observabilidad

- `docker compose config --quiet`: correcto.
- Diez contenedores levantados y saludables.
- Dos réplicas de `envios-svc` disponibles.
- Cinco objetivos de Prometheus en estado UP.
- Consultas HTTP y error 404 registrados.
- Endpoint público `/actuator/prometheus`: HTTP 404.
- Logs de LogiFast consultables mediante Grafana y Loki.

### Dashboard y métricas CI

- Grafana provisionado con dashboard de observabilidad.
- CPU, memoria, latencia y disponibilidad con datos.
- Cobertura JaCoCo publicada: 100%.
- Duración de despliegue local publicada: 28 segundos.
- Pushgateway respondió HTTP 200.
- Prometheus consultó correctamente ambas métricas.

## Validaciones pendientes

- Demostración del bloqueo en GitHub Actions mediante Pull Request temporal.
- Evidencia del job `deploy` en estado skipped.
- Verificación final de integración automática de métricas CI.
- Revisión final de evidencias y documentación.

## Uso de inteligencia artificial

Se utilizó ChatGPT como apoyo en el análisis de la pauta, revisión de configuraciones, preparación de documentación y diagnóstico de errores.

El equipo debe revisar, comprender y validar todas las soluciones incorporadas y declarar el uso de IA conforme a las instrucciones institucionales.

## Reflexiones individuales

## Reflexión Rocío
Durante la EP3 participé en la ampliación del microservicio LogiFast mediante herramientas de observabilidad y monitoreo.
Implementé la integración de Prometheus, Grafana, Loki y Alloy para visualizar métricas y centralizar los registros.
También trabajé en un dashboard para supervisar solicitudes HTTP, errores, latencia y recursos de los contenedores.
Integré la publicación de métricas de cobertura JaCoCo y duración del despliegue mediante Pushgateway.
Realicé validaciones que permitieron comprobar una cobertura del 100% y un despliegue local de 28 segundos.
Además, ejecuté una prueba controlada que demostró que Maven detiene la construcción cuando falla una prueba.
Durante el proceso aprendí a resolver problemas de configuración e integración entre diferentes herramientas DevOps.
Esta experiencia me permitió comprender la importancia de la observabilidad y de automatizar controles de calidad.
