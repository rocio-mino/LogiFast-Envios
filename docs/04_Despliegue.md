# Envios — Despliegue y operación

## Requisitos

- Java 21, Maven 3.9 (build local)
- Docker + Docker Compose (despliegue)

## Ejecución local

```bash
mvn spring-boot:run
```

URLs en `http://localhost:8080`:

| Recurso | URL |
|---------|-----|
| Página de presentación | `/` |
| Swagger UI | `/swagger-ui/index.html` |
| OpenAPI yaml | `/v3/api-docs.yaml` |
| ReDoc | `/redoc.html` |
| H2 Console | `/h2-console` |
| API base | /api/envios |

## Docker

```bash
docker build -t duoc/jv0101-caso17-envios:1.0.0 .
docker run -p 8080:8080 duoc/jv0101-caso17-envios:1.0.0
```

## Docker Compose (entorno orquestado)

```bash
docker compose up -d --build --wait   # lb (nginx) + 2 réplicas + PostgreSQL
PORT=9090 docker compose up -d --build --wait   # cambiar puerto host
docker compose down                   # detener
```

En Compose el servicio corre detrás de un balanceador, con 2 réplicas, límites de
recursos, healthchecks y PostgreSQL compartido; la consola H2 queda deshabilitada.
Detalle de comandos, escalado y verificación en [08_Orquestacion.md](08_Orquestacion.md);
despliegue automático y trazabilidad en [07_CICD_Despliegue.md](07_CICD_Despliegue.md).

## Base de datos

Local (`mvn spring-boot:run`) y pruebas: H2 en memoria (se pierde al detener la aplicación), configurable en `src/main/resources/application.yml`. Consola web en `/h2-console` (JDBC URL, usuario `sa`, sin clave).

## Variables de entorno

| Variable | Defecto | Descripción |
|----------|---------|-------------|
| `PORT` | `8080` | Puerto del servidor (local) / puerto publicado por el balanceador (Compose) |
| `APP_REPLICAS` | `2` | Réplicas de `envios-svc` en Compose |
| `IMAGE_TAG` | `1.0.0` | Etiqueta de la imagen (en el pipeline: SHA corto del commit) |
| `GIT_COMMIT` | `local` | Commit informado en `/actuator/info` |
| `DB_PASSWORD` | `envios_local_dev` | Clave de PostgreSQL en Compose (aleatoria en el pipeline) |
| `DB_POOL_SIZE` / `TOMCAT_MAX_THREADS` | `10` / `100` | Parámetros de escalabilidad por réplica |

Lista completa en [`.env.example`](../.env.example).
