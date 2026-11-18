# IE1 — Observabilidad, métricas y logs

## Objetivo

Observar el microservicio `envios-svc` mediante métricas de aplicación, métricas de contenedores y logs centralizados, permitiendo revisar uso, errores y disponibilidad.

## Componentes

| Componente | Función | Origen de datos |
|---|---|---|
| Spring Boot Actuator + Micrometer | Expone métricas JVM y HTTP | `/actuator/prometheus` |
| Prometheus | Consulta y conserva series temporales | Actuator, cAdvisor y Pushgateway |
| cAdvisor | Expone CPU y memoria por contenedor | Docker Engine / cgroups |
| Grafana Alloy | Descubre contenedores y recolecta sus logs | Socket Docker |
| Loki | Almacena y consulta logs | Alloy |
| Grafana | Visualiza métricas y logs | Prometheus y Loki |
| Pushgateway | Recibe métricas puntuales de tareas CI/CD | Script `publish-ci-metrics.sh` |

## Endpoints

| Ruta | Acceso | Propósito |
|---|---|---|
| `/actuator/health` | Health check | Estado general del servicio |
| `/actuator/health/liveness` | Health check | Vida del proceso |
| `/actuator/health/readiness` | Health check | Preparación y acceso a base de datos |
| `/actuator/info` | Interno/diagnóstico | Versión, commit e instancia |
| `/actuator/prometheus` | Red interna Docker | Métricas exportadas a Prometheus |

El endpoint `/actuator/prometheus` no se publica por un `ports` del servicio `envios-svc`. Además, nginx responde `404` para esa ruta cuando se consulta desde el balanceador. Prometheus se conecta directamente a las IP privadas de `envios-svc` mediante DNS discovery dentro de la red Docker `frontend`. `scripts/verify-deploy.sh` valida que el endpoint no sea accesible por el balanceador.

## Logs

Alloy usa `discovery.docker` y `loki.source.docker` para detectar contenedores y leer sus registros, luego los envía a Loki. Se agregan etiquetas de proyecto, nombre de servicio y servicio Compose para filtrar por servicio en Grafana. Loki conserva los logs durante 168 horas (siete días), mediante el Compactor y almacenamiento local en filesystem. El socket Docker entrega a Alloy acceso al API del daemon. Montarlo como `:ro` protege el punto de montaje, pero no convierte el API en solo lectura ni limita por sí mismo las operaciones que un cliente puede solicitar. Por ello, esta configuración debe mantenerse únicamente en un equipo local de desarrollo de confianza; no debe copiarse a un host compartido o productivo sin interponer un proxy del socket con endpoints permitidos y revisar sus permisos.

## Métricas observadas

- Solicitudes HTTP por segundo.
- Respuestas HTTP 4xx y 5xx por segundo.
- Latencia HTTP p95.
- CPU y memoria de las réplicas `envios-svc`.
- Disponibilidad de cada target de Prometheus.
- Cobertura de líneas JaCoCo y duración de despliegue publicadas por CI/CD.

## Ejecución local

1. Copiar `.env.example` a `.env` y reemplazar `GRAFANA_ADMIN_PASSWORD` por una contraseña local propia.
2. Ejecutar `mvn verify` para generar `target/site/jacoco/jacoco.csv`.
3. Ejecutar `docker compose up --build -d --wait`.
4. Abrir Grafana en `http://localhost:3000`, iniciar sesión con las credenciales locales del `.env` y abrir el dashboard `LogiFast - Observabilidad EP3`.
5. Generar tráfico con solicitudes REST a `http://localhost:8080/api/envios` y revisar métricas y logs.

Para revisar los targets de Prometheus: `http://localhost:9090/targets`. Para consultar Pushgateway: `http://localhost:9091/metrics`.

## Limitaciones y seguridad

- Esta pila es local y simulada; no equivale a un despliegue AWS ni sustituye la configuración cloud de IE2.
- La imagen de cAdvisor necesita acceso a métricas del host Docker/cgroups. En Windows con Docker Desktop, los indicadores disponibles corresponden al entorno Linux de Docker Desktop y pueden variar respecto al consumo del host Windows.
- Grafana, Prometheus y Pushgateway se publican solamente en `127.0.0.1`. Loki no publica puertos al host. Prometheus solo puede consultar las métricas del microservicio por la red interna; nginx bloquea esa ruta desde el puerto público.
- cAdvisor se ejecuta con privilegios y Alloy accede al API del socket Docker para obtener logs. Ambos son permisos potentes; están limitados aquí a una pila de desarrollo local y no deben copiarse sin revisión a un entorno compartido o productivo. El sufijo `:ro` del montaje no restringe los métodos HTTP que se pueden invocar sobre el socket.
- Las credenciales de Grafana de ejemplo son exclusivamente para desarrollo local y deben cambiarse.
