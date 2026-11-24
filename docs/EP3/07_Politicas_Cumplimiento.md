# IE5 — Políticas de cumplimiento automatizadas

Bloque de Martín. Define qué exige el proyecto para que un cambio pueda integrarse y desplegarse, con qué herramienta se verifica cada exigencia y qué umbral bloquea. Todas las verificaciones corren automáticamente en `.github/workflows/ci.yml`. Ninguna es solo una advertencia.

## Controles vigentes

| # | Control | Herramienta | Job del pipeline | Criterio de bloqueo |
|---|---|---|---|---|
| 1 | Pruebas y cobertura | Maven, JUnit, Cucumber, JaCoCo (Rocío) | `build-and-test` | Cualquier prueba fallida o cobertura de líneas < 100% |
| 2 | Vulnerabilidades en dependencias | Snyk Open Source | `Seguridad (Snyk)` | Severidad ≥ **high** |
| 3 | Análisis estático de seguridad | Snyk Code (SAST) | `Seguridad (Snyk)` | Severidad ≥ **high** |
| 4 | Calidad del código | SonarCloud (SonarQube Cloud) | `SonarCloud (Quality Gate)` | Quality Gate en estado `ERROR` (ver abajo) |
| 5 | Vulnerabilidades de la imagen | Snyk Container | `Imagen Docker (build + escaneo)` | Severidad **critical** (antes era solo advertencia) |
| 6 | Secretos en el código y el historial | Gitleaks 8.30.1 (`.gitleaks.toml`) | `Auditoría de cumplimiento` | 1 hallazgo |
| 7 | Políticas CMP-01 a CMP-08 | `scripts/audit-compliance.py` | `Auditoría de cumplimiento` | 1 control incumplido |
| 8 | Despliegue real en Kubernetes | kind + `scripts/verify-k8s.sh` | `Kubernetes (validación en kind)` | Pods que no arrancan bajo Pod Security `restricted`, health caído, commit distinto, Actuator expuesto, sin métricas o sin logs |
| 9 | Integración controlada | Branch protection de GitHub | `develop` y `main` | Merge sin PR, sin aprobación, con checks en rojo o rama desactualizada |

`deploy` (Compose) depende de los controles 1–7. `deploy-eks` depende además de 8 y del entorno simulado. Si cualquier control falla, el despliegue queda `skipped`.

## Políticas de la auditoría (`scripts/audit-compliance.py`)

El script lee el repositorio (Dockerfile, manifiestos Kubernetes, workflow, `.gitignore`, `.snyk`) y falla con código 1 ante cualquier incumplimiento. También falla si no puede leer un archivo. El reporte se guarda en el artefacto `evidencia-auditoria-<sha>` y en el resumen del job.

| Política | Qué verifica | Referencia |
|---|---|---|
| CMP-01 Secretos fuera del repositorio | `.env` ignorado; sin `.pem`, `.key`, kubeconfig ni credenciales versionadas; Secrets de Kubernetes sin valores en Git; variables `*PASSWORD*`, `*SECRET*` y `*TOKEN*` solo desde `secretKeyRef` | OWASP Top 10 A02/A05 · ISO/IEC 27001:2022 A.8.24 |
| CMP-02 Imagen endurecida | Imágenes base con versión fija; la etapa final corre con UID numérico no root; sin `ADD` de URLs remotas | CIS Docker Benchmark 4.1 · OWASP A08 |
| CMP-03 Workloads Kubernetes endurecidos | `runAsNonRoot`, seccomp `RuntimeDefault`, sin `hostNetwork`/`hostPID`/`hostIPC`/`hostPath`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem`, `drop: [ALL]`, requests y limits de CPU, memoria y almacenamiento, imágenes con versión fija, readiness en todos y liveness/startup en el microservicio | CIS Kubernetes Benchmark §5.2 · Pod Security Standards |
| CMP-04 Aislamiento | Namespaces `logifast` y `observability` con `pod-security.kubernetes.io/enforce: restricted` | Pod Security Admission |
| CMP-05 Exposición mínima | Ningún Service `LoadBalancer`/`NodePort` publica el puerto de administración (8081) | OWASP A05 |
| CMP-06 Controles bloqueantes | Existen todos los jobs de control; `deploy` y `deploy-eks` dependen de todos; ningún job usa `continue-on-error`; en pasos solo se permite en los informativos (*Snyk Monitor*, *Publicar hallazgos*); Snyk declara umbrales; SonarCloud espera el Quality Gate; Gitleaks presente | ISO/IEC 27001:2022 A.8.25 / A.8.32 |
| CMP-07 Excepciones con caducidad | Cada excepción de `.snyk` tiene motivo y fecha de expiración futura | Gestión de riesgo aceptado |
| CMP-08 Trazabilidad | Imagen etiquetada con el SHA y la etiqueta OCI `revision`; el despliegue Kubernetes registra commit, imagen y ejecución | ISO/IEC 27001:2022 A.8.32 |

Ejecución local: `python3 scripts/audit-compliance.py` (requiere `pip install pyyaml`).

## SonarCloud — configuración (una sola vez)

1. Entrar a <https://sonarcloud.io> con la cuenta de GitHub de la dueña del repositorio. *Analyze new project* → importar la organización `rocio-mino` → seleccionar `LogiFast-Envios`.
2. En el proyecto: *Administration* → *Analysis Method* → **desactivar Automatic Analysis**, porque el análisis lo hace el pipeline.
3. *My Account* → *Security* → generar un token y guardarlo en GitHub como secreto `SONAR_TOKEN`, tanto en *Actions* como en *Dependabot*.
4. Si la organización o la clave del proyecto no son `rocio-mino` / `rocio-mino_LogiFast-Envios`, crear las variables de repositorio `SONAR_ORGANIZATION` y `SONAR_PROJECT_KEY`.

El Quality Gate usado es *Sonar way*. Sobre el código nuevo exige:
- Ningún issue nuevo.
- Todos los *security hotspots* revisados.
- Cobertura ≥ 80%.
- Duplicación ≤ 3%.

El pipeline usa `-Dsonar.qualitygate.wait=true`: si el gate queda en `ERROR`, Maven termina con error y el job falla. El JSON con las condiciones y sus valores queda en el artefacto `evidencia-sonarcloud-<sha>`.

**Security hotspots.** Si SonarCloud marca un hotspot (por ejemplo, el token del ServiceAccount que Prometheus y Alloy necesitan para leer la API de Kubernetes), se revisa en *Security Hotspots*. Se marca como *Safe* solo con una justificación escrita, que queda auditada en SonarCloud. Nunca se baja el umbral del gate para aprobar.

## Protección de ramas (`develop` y `main`)

Reglas definidas en `scripts/configure-branch-protection.sh`:

- Pull Request obligatorio, con 1 aprobación. Las aprobaciones se anulan si llegan commits nuevos.
- Checks obligatorios: `build-and-test`, `Seguridad (Snyk)`, `SonarCloud (Quality Gate)`, `Auditoría de cumplimiento`, `Imagen Docker (build + escaneo)`, `Kubernetes (validación en kind)`, `Deploy (entorno simulado)`.
- La rama debe estar al día con la base (*strict*).
- Conversaciones resueltas antes del merge.
- Sin force-push ni borrado de la rama.
- Las reglas aplican también a administradores.

Aplicación (con una cuenta administradora del repositorio, desde Git Bash o CloudShell con `gh auth login`):

```bash
./scripts/configure-branch-protection.sh apply   # aplica y verifica
./scripts/configure-branch-protection.sh check   # guarda evidencia JSON en evidencias/EP3/IE5-Cumplimiento/
```

Alternativa manual: *Settings* → *Branches* → *Add branch protection rule* con las mismas opciones. Los checks solo aparecen en el buscador después de haberse ejecutado al menos una vez.

## Gestión de excepciones

- **Vulnerabilidades sin corrección:** se registran en `.snyk` con motivo, fecha de creación y expiración. CMP-07 bloquea si la fecha vence.
- **Falsos positivos de secretos:** se agregan en `.gitleaks.toml` solo para valores de ejemplo documentados. Hoy son las contraseñas locales de `docker-compose.yml` y `.env.example`, que en CI y Kubernetes se reemplazan por valores aleatorios.
- **Hotspots de SonarCloud:** se revisan en SonarCloud con justificación.

## Evidencias (`evidencias/EP3/IE5-Cumplimiento/`)

| Archivo sugerido | Contenido |
|---|---|
| `01-sonarcloud-quality-gate.png` | Log del job SonarCloud: `QUALITY GATE STATUS: PASSED` para el PR #34 |
| `01b-sonarcloud-condiciones.png` | Condiciones del Quality Gate con umbral y valor real (seguridad, mantenibilidad, duplicación, hotspots revisados) |
| `02-auditoria-cumplimiento.png` | Resumen del job `Auditoría de cumplimiento` (tabla CMP-01..08 + Gitleaks) |
| `03-branch-protection-develop.png`, `04-branch-protection-main.png` | Reglas configuradas en GitHub |
| `branch-protection-develop.json`, `branch-protection-main.json` | Generados por `configure-branch-protection.sh check` |
| `05-pr-checks-obligatorios.png` | PR con los checks requeridos y el botón de merge bloqueado hasta aprobar |
| `06-snyk-resumen.png` | Resumen del job de seguridad con umbrales y resultados |
