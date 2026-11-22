# IE6 — Bloqueo automático ante fallas críticas de seguridad (bloque de Martín)

Complementa `03_Validacion_Calidad.md` (Rocío), donde se demostró el bloqueo por calidad (prueba fallida → `build-and-test` en rojo → despliegue omitido).

## Revisión del job de seguridad

| Hallazgo en la revisión | Cambio |
|---|---|
| Snyk Container corría con `continue-on-error: true`: una imagen con vulnerabilidades críticas igual llegaba al despliegue | Ahora bloquea con `--severity-threshold=critical` y falla si falta `SNYK_TOKEN` |
| El despliegue no dependía de un análisis de calidad del código | `deploy` y `deploy-eks` dependen de `SonarCloud (Quality Gate)` |
| No había escaneo de secretos ni auditoría de configuración | Nuevo job `Auditoría de cumplimiento` (Gitleaks + `audit-compliance.py`) |
| El despliegue en la nube no tenía validación previa de los manifiestos | Nuevo job `Kubernetes (validación en kind)`, requerido por `deploy-eks` |
| Pasos con `continue-on-error` restantes | Solo *Snyk Monitor* y la publicación SARIF, que son informativos. La política CMP-06 lo verifica en cada ejecución: si alguien agrega `continue-on-error` a un control, la auditoría falla |

## Matriz de bloqueo

| Falla crítica | Job que falla | Jobs que no se ejecutan |
|---|---|---|
| Dependencia con vulnerabilidad ≥ high | `Seguridad (Snyk)` | `deploy`, `deploy-eks` |
| Código con vulnerabilidad ≥ high (SAST) | `Seguridad (Snyk)` | `deploy`, `deploy-eks` |
| Quality Gate de SonarCloud en `ERROR` | `SonarCloud (Quality Gate)` | `deploy`, `deploy-eks` |
| Imagen con vulnerabilidad critical | `Imagen Docker (build + escaneo)` | `k8s-validate`, `deploy`, `deploy-eks` |
| Secreto en el código o el historial | `Auditoría de cumplimiento` | `deploy`, `deploy-eks` |
| Contenedor privilegiado, root o sin límites | `Auditoría de cumplimiento` (y Pod Security en el clúster) | `deploy`, `deploy-eks` |
| Prueba fallida o cobertura < 100% (Rocío) | `build-and-test` | `image`, `k8s-validate`, `deploy`, `deploy-eks` |

Además, con la protección de ramas, cualquiera de estos checks en rojo impide el merge a `develop` y `main`.

## Prueba controlada de bloqueo por seguridad

Se hace en una rama temporal que **nunca** se integra. Se usan dos casos independientes. Comandos para PowerShell en Windows:

### Caso A — dependencia vulnerable (Snyk Open Source)

1. Crear la rama temporal desde la rama de trabajo actualizada:

   ```powershell
   git switch feature/ep3-martin-cloud-compliance
   git pull
   git switch -c test/ep3-bloqueo-seguridad
   ```

2. En `pom.xml`, dentro de `<dependencies>`, agregar temporalmente Log4j 2.14.1, afectada por Log4Shell (CVE-2021-44228, severidad crítica):

   ```xml
   <!-- TEMPORAL EP3 IE6: prueba de bloqueo por seguridad. NO INTEGRAR. -->
   <dependency>
       <groupId>org.apache.logging.log4j</groupId>
       <artifactId>log4j-core</artifactId>
       <version>2.14.1</version>
   </dependency>
   ```

3. Confirmar, publicar y abrir un PR **hacia `develop`**, sin fusionarlo:

   ```powershell
   git add pom.xml
   git commit -m "test(ci): demuestra bloqueo por vulnerabilidad critica"
   git push -u origin test/ep3-bloqueo-seguridad
   ```

4. Resultado esperado en Actions:
   - `Seguridad (Snyk)` en rojo: Snyk Open Source reporta Log4Shell y el paso termina con código 1.
   - `Deploy (entorno simulado)` aparece como **skipped**.
   - En el PR, el merge queda bloqueado por el check requerido.

### Caso B — contenedor privilegiado (auditoría de cumplimiento)

En la misma rama, en `deploy/k8s/base/postgres.yaml` cambiar `allowPrivilegeEscalation: false` por `privileged: true`, confirmar y publicar. Resultado esperado:
- `Auditoría de cumplimiento` en rojo, con el error `CMP-03 ... incumple: ['privileged', 'allowPrivilegeEscalation=false']`.
- `Deploy (entorno simulado)` aparece como **skipped**.

Verificación previa local (sin GitHub): `python3 scripts/audit-compliance.py` devuelve código 1 con ese cambio.

### Cierre

1. Capturas: run en rojo, job fallido con el mensaje de Snyk o de la auditoría, despliegue `skipped` y PR con merge bloqueado.
2. Cerrar el PR **sin fusionar**.
3. Eliminar la rama temporal y comprobar que la vulnerabilidad no llegó a ninguna rama estable:

   ```powershell
   git switch feature/ep3-martin-cloud-compliance
   git branch -D test/ep3-bloqueo-seguridad
   git push origin --delete test/ep3-bloqueo-seguridad
   git grep -n "log4j-core" -- pom.xml   # no debe devolver nada
   ```

## Evidencias (`evidencias/EP3/IE6-Bloqueos/`)

| Archivo sugerido | Contenido |
|---|---|
| `04-bloqueo-seguridad-snyk.png` | Paso Snyk Open Source con Log4Shell y código de salida 1 |
| `05-bloqueo-seguridad-deploy-skipped.png` | Grafo del workflow: `Seguridad (Snyk)` en rojo y `Deploy` *skipped* |
| `06-bloqueo-auditoria.png` | Job `Auditoría de cumplimiento` con el incumplimiento CMP-03 |
| `07-pr-seguridad-bloqueado.png` | PR con checks en rojo y merge bloqueado |
| `08-pr-seguridad-cerrado.png` | PR cerrado sin fusionar y rama eliminada |
| `09-regresion-calidad.png` | Run normal posterior con todos los checks en verde (el bloqueo por calidad de Rocío sigue funcionando, ver `03_Validacion_Calidad.md`) |
