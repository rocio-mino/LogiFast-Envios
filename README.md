# Envios — Microservicio de Envíos

Microservicio correspondiente al **caso17 — LogiFast**, una plataforma de transporte y logística de última milla, desarrollado para la Evaluación Parcial N°1.

|                |                                                                              |
| -------------- | ---------------------------------------------------------------------------- |
| **Asignatura** | JVY0101 — Java: Diseño y Construcción de Soluciones Nativas en Nube          |
| **Stack**      | Spring Boot 3.3 · Java 21 · Maven · Spring Data JPA · H2 · springdoc-openapi |
| **Calidad**    | JaCoCo cobertura LINE 100% · Cucumber (BDD) alineado a endpoints REST        |
| **Entrega**    | Docker / Docker Compose                                                      |

## Responsabilidad (SRP)

Este microservicio administra los datos y la lógica del dominio de **Envíos** del caso17 — LogiFast.

Utiliza una base de datos **H2 en memoria**, manteniendo una base de datos independiente para el microservicio y cumpliendo con el aislamiento de datos por dominio.

## Página de presentación

Al ejecutar el servicio, la página principal estará disponible en:

`http://localhost:8080/`

Esta página presenta información del microservicio y proporciona enlaces a:

* **Swagger UI:** `/swagger-ui/index.html`
* **OpenAPI (YAML):** `/v3/api-docs.yaml`
* **ReDoc:** `/redoc.html`
* **H2 Console:** `/h2-console`

## Endpoints

| Método | Ruta               | Descripción               |
| ------ | ------------------ | ------------------------- |
| GET    | `/api/envios`      | Lista todos los recursos  |
| GET    | `/api/envios/{id}` | Obtiene un recurso por ID |
| POST   | `/api/envios`      | Crea un recurso           |
| PUT    | `/api/envios/{id}` | Actualiza un recurso      |
| DELETE | `/api/envios/{id}` | Elimina un recurso        |

## Documentación del proyecto

La documentación completa se encuentra en la carpeta [`docs/`](docs/):

* [`docs/00_Resumen.md`](docs/00_Resumen.md) — propósito, responsabilidad y tecnologías.
* [`docs/01_Arquitectura.md`](docs/01_Arquitectura.md) — componentes, arquitectura y patrones.
* [`docs/02_API.md`](docs/02_API.md) — contrato REST y ejemplos con `curl`.
* [`docs/03_Pruebas.md`](docs/03_Pruebas.md) — pruebas unitarias, cobertura y Cucumber.
* [`docs/04_Despliegue.md`](docs/04_Despliegue.md) — instrucciones de despliegue.
* [`docs/05_Justificacion.md`](docs/05_Justificacion.md) — justificación del servicio, RF/RNF/seguridad, stack tecnológico y tecnologías AWS.
* [`docs/diagramas/`](docs/diagramas/) — diagramas C4 (contexto, contenedores y componentes), secuencia e infraestructura AWS, además de Docker, Docker Compose e integración.

## Estructura del proyecto

```text
envios/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── ...
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
├── Dockerfile
├── docker-compose.yml
├── pom.xml
├── README.md
└── .gitignore
```

## Cómo ejecutar localmente

Para ejecutar el microservicio directamente con Maven:

```bash
mvn spring-boot:run
```

Una vez iniciado, estará disponible en:

`http://localhost:8080`

## Cómo ejecutar con Docker

Para construir la imagen y ejecutar el servicio mediante Docker Compose:

```bash
docker compose up --build
```

Una vez iniciado, estará disponible en:

`http://localhost:8080`

Para detener los servicios:

```bash
docker compose down
```

## Cómo ejecutar las pruebas

Para ejecutar las pruebas unitarias y de comportamiento con Cucumber:

```bash
mvn test
```

Para ejecutar las pruebas junto con la verificación de cobertura mediante JaCoCo:

```bash
mvn verify
```

El proyecto considera una cobertura **LINE del 100%** y la validación de cobertura se realiza mediante JaCoCo.

## Estrategia de ramificación

Este repositorio utiliza **GitFlow** como modelo de ramificación.

Se eligió GitFlow porque:

* El equipo trabaja en pareja y necesita ramas separadas para desarrollar y probar cambios (`feature/*`) sin afectar el código estable de `develop` o `main`.
* Permite corregir errores urgentes mediante ramas `hotfix/*` sin interferir directamente con nuevas funcionalidades.
* `main` representa el código estable y desplegable, mientras que `develop` concentra el trabajo integrado antes de pasar a producción.
* Permite mantener una trazabilidad clara de los cambios realizados durante la evaluación.
* Para un equipo de dos personas y un solo microservicio, GitFlow proporciona una estructura sencilla de seguir y auditar.

Trunk-based development puede ser más conveniente para equipos grandes con despliegues muy frecuentes. Para este proyecto, GitFlow permite organizar de mejor manera el trabajo paralelo del equipo.

### Comparación con otros modelos

Además de GitFlow, existen otros modelos de ramificación utilizados en equipos de desarrollo colaborativo:

| Modelo | Característica | Aplicabilidad |
|---|---|---|
| GitFlow | Utiliza ramas permanentes como `main` y `develop`, además de ramas `feature` y `hotfix`. | Adecuado para proyectos que requieren separar desarrollo, integración y versiones estables. |
| GitHub Flow | Utiliza una rama principal y ramas de trabajo que se integran mediante Pull Requests. | Adecuado para equipos que realizan cambios frecuentes y buscan un flujo más simple. |
| Trunk-Based Development | Los cambios se integran frecuentemente en una rama principal mediante modificaciones pequeñas. | Adecuado para equipos con integración continua y despliegues frecuentes. |

Para esta evaluación se selecciona GitFlow debido a que el encargo solicita explícitamente las ramas `main`, `develop`, `feature/<nombre>` y `hotfix/<nombre>`. Además, permite demostrar de manera clara el trabajo colaborativo, la revisión mediante Pull Requests y la trazabilidad de los cambios.

### Ramas del repositorio

| Rama               | Propósito                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `main`             | Código estable y listo para desplegar.                                                               |
| `develop`          | Integración del trabajo en curso antes de pasar a `main`.                                            |
| `feature/<nombre>` | Desarrollo de una nueva funcionalidad. Nace de `develop` y vuelve a `develop` mediante Pull Request. |
| `hotfix/<nombre>`  | Corrección urgente. Nace de `main` y se integra a `main` y `develop` mediante Pull Request.          |

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
hotfix/corregir-validacion-envio
```

### Convención de mensajes de commit

Se utiliza el formato **Conventional Commits**:

```text
feat: agrega nueva funcionalidad
fix: corrige un error
docs: cambios de documentación
chore: tareas de mantenimiento, configuración o dependencias
ci: cambios relacionados con integración continua
test: cambios relacionados con pruebas
refactor: cambios internos que no modifican el comportamiento
```

Ejemplos:

```text
feat: agrega pie de pagina con version del servicio
fix: corrige titulo de la pagina
docs: actualiza documentacion de despliegue
```

### Flujo de merge y revisión

1. Toda rama `feature/*` y `hotfix/*` se integra mediante **Pull Request**, evitando el push directo a `main` o `develop`.
2. Cada Pull Request debe ser revisado por el otro integrante de la pareja antes del merge.
3. Las ramas `feature/*` se integran a `develop`.
4. Las ramas `hotfix/*` se integran a `main` y posteriormente se replican en `develop`.
5. Después de integrar una rama, esta se elimina para mantener el repositorio organizado.

## Control de versiones

El código fuente se administra mediante **Git y GitHub**.

Se mantiene una separación entre las ramas principales:

* `main`: código estable.
* `develop`: integración de cambios.
* `feature/*`: desarrollo de funcionalidades.
* `hotfix/*`: correcciones urgentes.

Cada modificación queda asociada a un commit identificable y, cuando corresponde, a un Pull Request.

### Buenas prácticas

- No realizar `push` directo a `main`.
- No realizar `push` directo a `develop`.
- Utilizar ramas `feature/*` para nuevas funcionalidades.
- Utilizar ramas `hotfix/*` para correcciones urgentes.
- Mantener los commits pequeños y relacionados con un único objetivo.
- Utilizar mensajes de commit descriptivos.
- Revisar los Pull Requests antes del merge.
- Ejecutar las pruebas antes de solicitar un Pull Request.
- No almacenar credenciales ni información sensible en el repositorio.
- Mantener actualizado el código local mediante `git pull`.
- Eliminar las ramas de trabajo después de completar su integración.

## Integración continua y CI/CD

El repositorio utiliza **GitHub Actions** como herramienta de automatización.

El flujo de integración continua tiene como objetivo validar automáticamente los cambios mediante la compilación del proyecto, la ejecución de las pruebas automatizadas y la verificación de la cobertura.

El workflow se ejecutará:

* Ante un `push` a `develop`.
* Ante un Pull Request dirigido a `main`.

El pipeline utilizará Maven para realizar las validaciones necesarias del proyecto y ejecutar las pruebas automatizadas.

## Uso de herramientas de IA

Durante el desarrollo de esta evaluación se utilizaron herramientas de Inteligencia Artificial como apoyo para la revisión de documentación, organización del trabajo y resolución de dudas técnicas relacionadas con Git, GitHub, GitHub Actions y buenas prácticas DevOps.

El uso de estas herramientas se realizó como apoyo al proceso de desarrollo, manteniendo la responsabilidad sobre las decisiones técnicas y la implementación final del proyecto.

## Reflexiones individuales

### Rocio

Durante el desarrollo de la evaluación pude aprender y reforzar el uso de Git y GitHub junto a mi copmpañero. Mi aporte fue realizar la  documentación y la organización del README y posteriormente la realización del hotfix para actualizar la configuración de GitHub Actions. También aprendí a trabajar mediante ramas y Pull Requests, realizando revisiones y aprobaciones de los cambios de mi compañero antes de integrarlos a develop o main, cosa que antes no hacia, ya que solo hacia merge sin revisar, sin tomar en cuenta la importancia de recisar antes de aceptar.

Una de las cosas que más me ayudó fue entender mejor el flujo de GitFlow y la importancia de mantener separadas las ramas de desarrollo y las ramas estables. También pude comprender mejor cómo los Pull Requests permiten mantener un registro de los cambios y revisar el trabajo antes de incorporarlo al proyecto.

Considero que esta actividad me permitió mejorar mi forma de trabajar en equipo a la hora de utilizar gitflow y tener una visión más clara de cómo GitHub Actions puede automatizar la validación de un proyecto.

### Martin

Durante esta evaluación mi principal aporte estuvo relacionado con la configuración y validación del flujo de CI mediante GitHub Actions. Trabajé con Java 21 y Maven, configuré el workflow para ejecutar las pruebas y la verificación del proyecto, y comprobé que el proceso funcionara tanto con cambios en develop como mediante Pull Requests hacia main.

También pude reforzar el uso de Git en un contexto colaborativo, especialmente la creación de ramas, commits, push, pull, Pull Requests y merges. Trabajar junto a Rocio me permitió entender mejor la importancia de revisar los cambios antes de integrarlos y de mantener una separación entre las ramas de trabajo, develop y main.

Uno de los aprendizajes más importantes fue comprender mejor el propósito de CI/CD y cómo una herramienta como GitHub Actions puede automatizar tareas que antes tendrían que realizarse manualmente. También aprendí la importancia de mantener el repositorio ordenado y de utilizar convenciones de nombres y mensajes de commit para facilitar la trazabilidad de los cambios.