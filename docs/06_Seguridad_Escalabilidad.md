# Envios — Seguridad y escalabilidad en el pipeline (IE3)

## 1. Controles de seguridad

| Control | Herramienta | Dónde | Qué revisa | ¿Bloquea? |
|---|---|---|---|---|
| Escaneo y actualización de dependencias | **Dependabot** | `.github/dependabot.yml` | `pom.xml` (Maven), acciones de GitHub, imágenes base del `Dockerfile` y de `docker-compose.yml` | Abre PR semanal hacia `develop`; el PR pasa por todo el pipeline |
| Vulnerabilidades en dependencias (SCA) | **Snyk Open Source** (`snyk test`) | job `security` | Árbol completo de dependencias Maven, incluidas las transitivas | **Sí**, severidad ≥ `high` |
| Análisis estático del código (SAST) | **Snyk Code** (`snyk code test`) | job `security` | Código Java del microservicio | **Sí**, severidad ≥ `high` |
| Vulnerabilidades de la imagen | **Snyk Container** (`snyk container test`) | job `image` | Paquetes del sistema operativo base y el JAR dentro de la imagen | No: **alerta** (warning en el run + reporte) |
| Monitoreo continuo | **Snyk Monitor** | job `security` (solo `push`) | Registra el proyecto en Snyk por rama | No: Snyk envía correo si aparece una vulnerabilidad nueva |
| Falta de credenciales de análisis | Paso "Verificar que existe SNYK_TOKEN" | job `security` | Que el análisis realmente se ejecute | **Sí** (no se despliega sin análisis) |

### Política de bloqueo

1. El job **`deploy`** declara `needs: [build-and-test, security, image]`. Si
   `security` falla, GitHub Actions marca el deploy como **skipped**: ningún
   cambio con vulnerabilidades `high` o `critical` llega al entorno desplegado.
2. Umbral: `--severity-threshold=high`. Las severidades `low` y `medium` se
   reportan (artefacto `reportes-snyk-<sha>` y pestaña *Security*), pero no
   detienen la entrega. Se eligió `high` porque es el nivel que la industria
   suele tratar como "no desplegable", sin bloquear por hallazgos menores que se
   corrigen en el ciclo normal de Dependabot.
3. Snyk Container se deja como **alerta** porque las vulnerabilidades del sistema
   operativo base no siempre tienen corrección disponible; bloquear por ellas
   detendría la entrega sin que el equipo pueda hacer nada. Se mitigan con
   Dependabot (`package-ecosystem: docker`), que propone la imagen base nueva.
4. A nivel de repositorio, las reglas de protección de `main` y `develop` exigen
   que los checks `build-and-test`, `Seguridad (Snyk)`, `Imagen Docker (build + escaneo)`
   y `Deploy (entorno simulado)` estén en verde antes de permitir el merge
   (ver [Configuración en GitHub](#4-configuración-necesaria-en-github)).
5. Excepciones: si una vulnerabilidad no tiene corrección y el riesgo se acepta,
   se registra en el archivo [`.snyk`](../.snyk) con motivo, fecha de creación y
   fecha de expiración (`snyk ignore --id=<ID> --expiry=<fecha> --reason="..."`).
   Queda versionada y auditada en Git, y al expirar Snyk vuelve a bloquear.

### Remediación aplicada (primer análisis)

El primer run del job `security` **bloqueó el deploy** con 27 vulnerabilidades
(24 high y 3 critical) en dependencias transitivas de Spring Boot 3.5. Tras migrar a
Boot 4, el segundo run volvió a bloquear con 4 vulnerabilidades de Jackson 3. Acciones:

| Hallazgo | Corrección |
|---|---|
| Spring Framework 6.2.19 (`spring-webmvc`, `spring-web`, `spring-beans`, `spring-expression`): 1 critical + 6 high, sin corrección gratuita en 6.2 | Migración a **Spring Boot 4.0.8** (Spring Framework 7.0.9) |
| Tomcat 10.1.55: 2 critical + 5 high | Boot 4 + `tomcat.version` = 11.0.27 (Boot 4.0.8 trae 11.0.24, aún afectada) |
| Jackson 2 (`jackson-core`/`jackson-databind` 2.21.4): 5 high | `jackson-2-bom.version` = 2.21.8 (lo usa springdoc/swagger) |
| Jackson 3 (`tools.jackson` 3.1.5, que trae Boot 4.0.8): 4 high — detectado en el segundo análisis, tras migrar | `jackson-bom.version` = 3.1.8 |
| Logback 1.5.34, Micrometer 1.15.12 | Versiones de Boot 4.0.8 (1.5.38 y 1.16.7) |
| PostgreSQL JDBC 42.7.11: 2 high | `postgresql.version` = 42.7.14 |
| commons-lang3 3.17.0 (vía springdoc) | Versión gestionada por Boot 4.0.8 (3.19.0) |
| JAXB `jaxb-core` 4.0.9 (vía Hibernate): XXE sin versión corregida | Excepción en `.snyk` hasta 2027-01-31: Hibernate solo lee mapeos XML internos y la API no acepta XML |

La migración a Boot 4 obligó a ajustar las pruebas: `@MockBean` → `@MockitoBean`,
nuevos paquetes de `@AutoConfigureMockMvc` y `TestRestTemplate`, Jackson 3
(`tools.jackson`) y `@AutoConfigureTestRestTemplate` en Cucumber.


### Endurecimiento del despliegue (`docker-compose.yml`)

| Parámetro | Valor | Motivo |
|---|---|---|
| Usuario | `app` (definido en el `Dockerfile`, IE1) | El proceso Java no corre como `root`; `verify-deploy.sh` muestra el usuario de cada réplica |
| `read_only` | `true` (+ `tmpfs /tmp` de 64 MB) | Nadie puede modificar el sistema de archivos del contenedor |
| `cap_drop` | `ALL` | Se eliminan todas las capacidades de Linux |
| `security_opt` | `no-new-privileges:true` | Impide escalar privilegios con binarios setuid |
| Red `backend` | `internal: true` | PostgreSQL no es accesible desde fuera ni tiene salida a Internet |
| Puertos publicados | solo el balanceador (`8080`) | Las réplicas y la base no se exponen |
| Actuator | solo `health` e `info`, `show-details: never` | Mínima información expuesta (se verifica que `/actuator/env` da 404) |
| Consola H2 | deshabilitada en el despliegue | Se verifica que `/h2-console` da 404 |
| Clave de la base | aleatoria por despliegue en el pipeline (`openssl rand`) y enmascarada | No hay credenciales reales en el repositorio |

## 2. Parámetros de escalabilidad

| Parámetro | Valor | Justificación |
|---|---|---|
| Réplicas de `envios-svc` | `2` (`APP_REPLICAS`), probado hasta `3` | Alta disponibilidad mínima: si cae una, la otra atiende. Simula el mínimo de 2 tareas Fargate del diseño (RNF-01) |
| Límite CPU por réplica | `0.75` CPU | Suficiente para el arranque de Spring Boot sin que una réplica acapare el host |
| Reserva CPU | `0.25` CPU | Garantiza un mínimo de CPU aun con el host cargado |
| Límite memoria por réplica | `512M` | Spring Boot + Hibernate usan ~200–300 MB; deja margen sin desperdiciar memoria |
| Reserva memoria | `256M` | Mínimo para que la JVM arranque |
| Heap JVM | `-XX:MaxRAMPercentage=60` (~307 MB) | La JVM respeta el límite del contenedor y deja espacio para metaspace e hilos; con `ExitOnOutOfMemoryError` una réplica sin memoria se reinicia en vez de quedar colgada |
| Límite de procesos | `pids: 512` | Evita que un fallo cree hilos sin control |
| Hilos de Tomcat | `100` (`TOMCAT_MAX_THREADS`) | Acota la concurrencia por réplica de acuerdo con su CPU |
| Pool de conexiones Hikari | `10` por réplica (`DB_POOL_SIZE`) | 2 réplicas × 10 = 20 conexiones, holgado frente al máximo de 100 de PostgreSQL; al escalar a 3 quedan 30 |
| PostgreSQL | `0.50` CPU / `256M` | Base compartida por todas las réplicas |
| Balanceador nginx | `0.25` CPU / `64M` | Proceso liviano |
| Logs | `json-file`, `10m` × 3 archivos | Los logs no llenan el disco del host |
| Apagado | `server.shutdown: graceful`, 20 s por fase, `stop_grace_period: 30s` | Al escalar hacia abajo o redeplegar, las peticiones en curso terminan bien |

Para escalar sin tocar archivos: `APP_REPLICAS=3 ./scripts/deploy.sh` o
`docker compose up -d --scale envios-svc=3`.

## 3. Evidencias a guardar

- Run en verde del job **Seguridad (Snyk)** con su resumen (tabla de resultados).
- Run **bloqueado**: ver [docs/07_CICD_Despliegue.md](07_CICD_Despliegue.md#prueba-del-bloqueo-de-seguridad).
- Pestaña *Insights → Dependency graph → Dependabot* con los ecosistemas activos y algún PR de Dependabot.
- Proyecto `logifast-envios` en el panel de Snyk (app.snyk.io).
- Salida de `docker inspect` / paso 5 de `verify-deploy.sh` con los límites aplicados.

## 4. Configuración necesaria en GitHub

1. Crear cuenta gratuita en [snyk.io](https://snyk.io) (se puede entrar con GitHub).
   En *Settings → Snyk Code* activar **Snyk Code**. Copiar el token en
   *Account settings → Auth Token*.
2. En el repositorio: *Settings → Secrets and variables → Actions →
   New repository secret* → `SNYK_TOKEN`.
3. Repetir en *Settings → Secrets and variables → **Dependabot*** con el mismo
   nombre (los PR de Dependabot no leen los secretos de Actions).
4. *Settings → Code security*: activar **Dependency graph**, **Dependabot alerts**
   y **Dependabot security updates**.
5. *Settings → Branches* (o *Rules → Rulesets*) para `main` y `develop`: exigir
   Pull Request con 1 aprobación y los checks `build-and-test`,
   `Seguridad (Snyk)`, `Imagen Docker (build + escaneo)` y `Deploy (entorno simulado)`.
