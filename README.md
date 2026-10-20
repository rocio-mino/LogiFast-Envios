# LogiFast-Envios — Microservicio de Envíos

Microservicio correspondiente al **caso 17 — LogiFast**, una plataforma de transporte y logística de última milla. Este repositorio contiene el servicio de envíos desarrollado con Spring Boot y preparado para su construcción, ejecución y validación mediante herramientas de desarrollo Cloud Native.

| | |
|---|---|
| **Asignatura** | JVY0101 — Java: Diseño y Construcción de Soluciones Nativas en Nube |
| **Stack** | Spring Boot 3.3.5, Java 21, Maven, Spring Data JPA, H2 y springdoc-openapi |
| **Calidad** | Pruebas automatizadas, Cucumber y JaCoCo |
| **Contenedores** | Docker y Docker Compose |
| **Integración continua** | GitHub Actions |

## Responsabilidad del microservicio (SRP)

Este microservicio administra los datos y la lógica del dominio de **Envíos** de LogiFast.

Utiliza una base de datos **H2 en memoria**, manteniendo los datos aislados dentro del dominio del servicio.

Al ser una base de datos en memoria, los datos no deben considerarse persistentes después de reiniciar la aplicación.

## Página de presentación y documentación de la API

Al ejecutar el servicio en el puerto 8080, la página principal estará disponible en:

`http://localhost:8080/`

La página presenta información del microservicio y proporciona enlaces a las siguientes herramientas:

- **Swagger UI:** `http://localhost:8080/swagger-ui/index.html`
- **OpenAPI (YAML):** `http://localhost:8080/v3/api-docs.yaml`
- **ReDoc:** `http://localhost:8080/redoc.html`
- **Consola H2:** `http://localhost:8080/h2-console`

## Endpoints REST

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/envios` | Lista todos los envíos. |
| GET | `/api/envios/{id}` | Obtiene un envío por su identificador. |
| POST | `/api/envios` | Crea un envío. |
| PUT | `/api/envios/{id}` | Actualiza un envío existente. |
| DELETE | `/api/envios/{id}` | Elimina un envío. |

### Ejemplo de creación

```bash
curl -i -X POST http://localhost:8080/api/envios \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Envio de prueba EP2"}'
```

La respuesta concreta depende de las validaciones y de la implementación del servicio.

## Monitoreo y estado del servicio

El proyecto incorpora **Spring Boot Actuator** para consultar el estado de salud de la aplicación.

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/actuator/health` | Consulta el estado de salud del servicio. |

Para comprobar el endpoint cuando la aplicación se encuentra ejecutándose localmente en el puerto 8080:

```bash
curl -i http://localhost:8080/actuator/health
```

Una respuesta satisfactoria devuelve HTTP 200 y un JSON similar a:

```json
{
  "status": "UP"
}
```

**Validación realizada:** el endpoint respondió HTTP 200 con `{"status":"UP"}` durante la prueba de la imagen Docker `logifast-envios:ep2`, utilizando el puerto 8081 del equipo para evitar interferir con otros servicios.

El estado `UP` confirma que la aplicación reporta un estado operativo; no implica por sí solo que se hayan comprobado todas las dependencias externas.

## Documentación del proyecto

La documentación complementaria se encuentra en la carpeta [`docs/`](docs/):

- [`docs/00_Resumen.md`](docs/00_Resumen.md): propósito, responsabilidad y tecnologías.
- [`docs/01_Arquitectura.md`](docs/01_Arquitectura.md): componentes, arquitectura y patrones.
- [`docs/02_API.md`](docs/02_API.md): contrato REST y ejemplos con `curl`.
- [`docs/03_Pruebas.md`](docs/03_Pruebas.md): pruebas unitarias, cobertura y Cucumber.
- [`docs/04_Despliegue.md`](docs/04_Despliegue.md): instrucciones de despliegue.
- [`docs/05_Justificacion.md`](docs/05_Justificacion.md): justificación del servicio, RF/RNF, seguridad, stack tecnológico y tecnologías AWS.
- [`docs/diagramas/`](docs/diagramas/): diagramas C4 de contexto, contenedores y componentes, secuencia e infraestructura AWS, además de diagramas de Docker, Docker Compose e integración.

## Estructura del proyecto

```text
LogiFast-Envios/
├── src/
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   └── test/
│       ├── java/
│       └── resources/
├── docs/
│   ├── 00_Resumen.md
│   ├── 01_Arquitectura.md
│   ├── 02_API.md
│   ├── 03_Pruebas.md
│   ├── 04_Despliegue.md
│   ├── 05_Justificacion.md
│   └── diagramas/
├── .github/
│   └── workflows/
│       └── ci.yml
├── Dockerfile
├── docker-compose.yml
├── pom.xml
├── README.md
└── .gitignore
```

## Cómo ejecutar localmente

La ejecución directa con Maven requiere tener Java 21 y Maven instalados.

Para iniciar el microservicio:

```bash
mvn spring-boot:run
```

Una vez iniciado, estará disponible en:

`http://localhost:8080`

## Cómo ejecutar con Docker

El proyecto utiliza un Dockerfile multi-stage para separar la construcción de la aplicación de su ejecución.

### Características del Dockerfile

**Etapa de construcción:**

- Utiliza Maven 3.9 y Eclipse Temurin 21.
- Descarga las dependencias.
- Compila y empaqueta la aplicación Spring Boot.

**Etapa de ejecución:**

- Utiliza una imagen Eclipse Temurin 21 JRE.
- Copia el artefacto JAR generado en la etapa de construcción.
- Ejecuta la aplicación con el usuario sin privilegios `app`.
- Expone el puerto 8080 del contenedor.

Este enfoque evita incluir Maven y todas las herramientas de compilación en la imagen final y permite ejecutar la aplicación sin utilizar el usuario `root`.

### Construir y levantar el servicio

Desde la raíz del repositorio:

```bash
docker compose up --build -d
```

Consultar el estado de los servicios:

```bash
docker compose ps
```

Consultar los registros del microservicio:

```bash
docker compose logs -f envios-svc
```

Probar la aplicación:

```bash
curl -i http://localhost:8080/
```

Comprobar el estado de salud:

```bash
curl -i http://localhost:8080/actuator/health
```

Detener los servicios:

```bash
docker compose down
```

Este último comando detiene y elimina los contenedores administrados por ese archivo Compose, pero no elimina los volúmenes nombrados.

### Configuración del puerto

El servicio utiliza el puerto 8080 del contenedor y publica el puerto del equipo mediante la variable `PORT`.

En `docker-compose.yml`:

```yaml
ports:
  - "${PORT:-8080}:8080"
```

Si no se define `PORT`, se utiliza el puerto 8080 del equipo.

### Etiquetas de las imágenes Docker

El repositorio utiliza distintas etiquetas según el procedimiento de construcción:

- **Docker Compose:** `duoc/jv0101-caso17-envios:1.0.0`.
- **Pruebas locales de la EP2:** `logifast-envios:ep2`.
- **Construcción de CI:** `logifast-envios:ci`.

Estas etiquetas identifican imágenes diferentes. La imagen `logifast-envios:ep2` se construyó correctamente durante las pruebas locales y presentó un uso en disco de 564 MB y un tamaño de contenido de 166 MB en el entorno donde se midió. Estos valores pueden variar según la versión de Docker y la plataforma.

## Pruebas automatizadas y cobertura

El proyecto incorpora pruebas automatizadas para validar el comportamiento de la aplicación y verificar la cobertura del código.

### Ejecutar las pruebas

Para ejecutar las pruebas unitarias y de comportamiento con Cucumber:

```bash
mvn test
```

Para ejecutar las pruebas y las verificaciones configuradas:

```bash
mvn verify
```

El objetivo `verify` permite ejecutar las fases anteriores del ciclo de Maven y comprobar los umbrales de cobertura configurados mediante JaCoCo.

### Ejecución mediante Docker

Si Maven no está instalado directamente en Windows, se puede utilizar un contenedor Maven para ejecutar la verificación desde la raíz del proyecto.

En **CMD de Windows**:

```cmd
docker run --rm -v "%cd%:/app" -w /app maven:3.9-eclipse-temurin-21 mvn verify
```

En PowerShell, la ruta del volumen puede expresarse de esta forma:

```powershell
docker run --rm -v "${PWD}:/app" -w /app maven:3.9-eclipse-temurin-21 mvn verify
```

### Evidencia de ejecución

Durante la validación de la EP2, `mvn verify` finalizó con:

```text
BUILD SUCCESS
All coverage checks have been met.
```

JaCoCo informó que analizó cuatro clases y que se cumplieron todos los umbrales configurados.

En el reporte de cobertura generado durante esa ejecución se registró un 100 % en las métricas de instrucciones, ramas, líneas y métodos para el conjunto analizado. Este resultado corresponde al alcance del análisis de JaCoCo y no garantiza por sí solo la ausencia de defectos.

El reporte HTML se genera en:

```text
target/site/jacoco/index.html
```

## Integración continua y CI/CD

El repositorio utiliza **GitHub Actions** para automatizar la validación de los cambios.

El workflow se encuentra en `.github/workflows/ci.yml`.

### Eventos que activan el workflow

Según la configuración actual, la integración continua se ejecuta ante:

- Un `push` a la rama `develop`.
- Un Pull Request dirigido a la rama `develop`.

### Etapas del pipeline

1. **Descarga del repositorio:** utiliza `actions/checkout@v5`.
2. **Configuración de Java:** prepara Java 21 con Eclipse Temurin mediante `actions/setup-java@v5` y habilita la caché de Maven.
3. **Pruebas y cobertura:** ejecuta `mvn verify`, incluyendo las pruebas automatizadas y los controles de cobertura configurados con JaCoCo.
4. **Construcción de la imagen Docker:** ejecuta `docker build -t logifast-envios:ci .`.

### Resultado validado

El workflow completó correctamente las etapas de pruebas, verificación de cobertura y construcción de la imagen Docker.

La integración mediante Pull Requests permite comprobar los cambios antes de incorporarlos a `develop`.

**Nota:** la configuración documentada corresponde al workflow actual. No debe interpretarse como una ejecución automática de despliegue a producción, ya que el pipeline descrito realiza validaciones y construcción de la imagen.

## Estrategia de ramificación

Este repositorio utiliza **GitFlow** como modelo de ramificación.

Se eligió este modelo porque el equipo trabaja en pareja y necesita ramas separadas para desarrollar y probar cambios sin afectar directamente las ramas principales.

GitFlow permite:

- Mantener `main` como rama estable.
- Integrar los cambios en `develop`.
- Desarrollar funcionalidades mediante ramas `feature/*`.
- Corregir problemas urgentes mediante ramas `hotfix/*`.
- Mantener trazabilidad mediante commits y Pull Requests.

Trunk-Based Development puede ser conveniente para equipos con integración muy frecuente y despliegues continuos. Para este proyecto, GitFlow permite demostrar el trabajo colaborativo, la revisión de cambios y la separación entre desarrollo y código estable.

### Comparación con otros modelos

| Modelo | Característica | Aplicabilidad |
|---|---|---|
| GitFlow | Utiliza ramas como `main` y `develop`, además de ramas `feature` y `hotfix`. | Adecuado cuando se necesita separar desarrollo, integración y versiones estables. |
| GitHub Flow | Utiliza una rama principal y ramas de trabajo integradas mediante Pull Requests. | Adecuado para equipos que realizan cambios frecuentes y buscan un flujo más simple. |
| Trunk-Based Development | Integra cambios pequeños y frecuentes en una rama principal. | Adecuado para equipos con integración continua y despliegues frecuentes. |

Para esta evaluación se utiliza GitFlow, de acuerdo con la organización de ramas establecida para el proyecto.

### Ramas del repositorio

| Rama | Propósito |
|---|---|
| `main` | Código estable y preparado para la entrega o despliegue. |
| `develop` | Integración del trabajo en curso antes de pasar a `main`. |
| `feature/<nombre>` | Desarrollo de nuevas funcionalidades. Nace de `develop` y vuelve a `develop` mediante Pull Request. |
| `hotfix/<nombre>` | Corrección urgente. Según el flujo definido para el proyecto, nace de `main` y se integra a `main` y `develop` mediante Pull Requests. |

### Convención de nombres de ramas

Se utiliza el siguiente formato:

```text
feature/nombre-corto-en-minusculas
hotfix/nombre-corto-en-minusculas
```

Ejemplos:

```text
feature/rocio-documentacion
feature/martin-ci
feature/ep2-healthcheck
hotfix/corregir-validacion-envio
```

### Convención de mensajes de commit

Se utiliza el formato **Conventional Commits**:

```text
feat: agrega nueva funcionalidad
fix: corrige un error
docs: actualiza la documentación
chore: realiza tareas de mantenimiento
ci: modifica la integración continua
test: agrega o modifica pruebas
refactor: reorganiza el código sin cambiar su comportamiento
```

### Flujo de merge y revisión

1. Las ramas `feature/*` y `hotfix/*` se integran mediante Pull Requests, evitando el push directo a las ramas principales.
2. Cada Pull Request debe ser revisado por el otro integrante antes del merge.
3. Las ramas `feature/*` se integran a `develop`.
4. Las ramas `hotfix/*` siguen el flujo definido para su integración en `main` y `develop`.
5. Después de integrar una rama, se puede eliminar para mantener el repositorio organizado.

## Control de versiones

El código fuente se administra mediante **Git y GitHub**.

Se mantiene una separación entre las ramas principales:

- `main`: código estable.
- `develop`: integración de cambios.
- `feature/*`: desarrollo de funcionalidades.
- `hotfix/*`: correcciones urgentes.

Cada modificación queda asociada a un commit identificable y, cuando corresponde, a un Pull Request.

### Buenas prácticas

- No realizar `push` directo a `main` ni a `develop`.
- Utilizar ramas `feature/*` para nuevas funcionalidades.
- Utilizar ramas `hotfix/*` para correcciones urgentes.
- Mantener los commits pequeños y relacionados con un único objetivo.
- Utilizar mensajes de commit descriptivos.
- Revisar los Pull Requests antes del merge.
- Ejecutar las pruebas antes de solicitar un Pull Request.
- No almacenar credenciales ni información sensible en el repositorio.
- Mantener actualizado el código local mediante `git pull`.
- Eliminar las ramas de trabajo después de completar su integración.

## Uso de herramientas de Inteligencia Artificial

Durante el desarrollo de esta evaluación se utilizó ChatGPT como herramienta de apoyo para resolver dudas técnicas, revisar configuraciones de Docker y GitHub Actions, interpretar resultados de pruebas y organizar la documentación.

Las decisiones finales, la comprobación de los comandos y la validación del funcionamiento del proyecto se realizaron contrastando las sugerencias con el repositorio y los resultados obtenidos.

## Reflexiones individuales

### Rocío
Durante el proyecto LogiFast, lo que más me costó fue identificar qué pasos debía agregar al workflow de GitHub Actions. Ejecutar el pipeline me ayudó a comprender mejor cómo se automatizan las pruebas con Maven y la construcción de la imagen Docker. Aunque aprendí más sobre su funcionamiento, todavía necesito practicar para poder configurar un workflow desde cero de forma autónoma.

### Martín


## Estado de la entrega

Este README documenta los aspectos verificados del microservicio de envíos, su contenedorización, las pruebas automatizadas y la integración continua.

Los demás indicadores de la evaluación deben documentarse conforme se implementen, integren y validen sus respectivas soluciones.