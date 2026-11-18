# IE6 — Validación automática de calidad (bloque de Rocío)

## Controles de calidad ya existentes

El proyecto ya ejecuta `mvn verify` en el job `build-and-test`. JaCoCo tiene un umbral de 100% de cobertura de líneas a nivel bundle y hace fallar la fase `verify` si no se alcanza. El job `deploy` depende de `build-and-test`, `security` e `image`, por lo que no debe ejecutarse si falla la validación previa.

## Comportamiento esperado

| Condición | Job que debe fallar | Resultado esperado |
|---|---|---|
| Una prueba JUnit/Cucumber falla | `build-and-test` | `deploy` no se ejecuta |
| Cobertura de líneas JaCoCo inferior a 100% | `build-and-test` | `deploy` no se ejecuta |

## Prueba controlada de calidad

La prueba se hace en una rama temporal que nunca se integra a `develop` ni a `main`. El cambio intencional se limita a un test nuevo y se elimina al cerrar la demostración.

1. Partir de `develop` actualizado y crear la rama temporal:

   ```bash
   git switch develop
   git pull --ff-only origin develop
   git switch -c test/ep3-bloqueo-calidad
   ```

2. Crear temporalmente `src/test/java/cl/duoc/jv0101/caso17/envios/FalloIntencionalEP3Test.java` con este contenido:

   ```java
   package cl.duoc.jv0101.caso17.envios;

   import org.junit.jupiter.api.Test;
   import static org.junit.jupiter.api.Assertions.assertTrue;

   class FalloIntencionalEP3Test {
       @Test
       void debeBloquearElPipelineCuandoFallaUnaPrueba() {
           assertTrue(false, "Falla intencional para demostrar el bloqueo EP3");
       }
   }
   ```

3. Confirmar y publicar únicamente la rama temporal:

   ```bash
   git add src/test/java/cl/duoc/jv0101/caso17/envios/FalloIntencionalEP3Test.java
   git commit -m "test(ci): demuestra bloqueo por falla de calidad"
   git push -u origin test/ep3-bloqueo-calidad
   ```

4. Abrir un Pull Request con destino `develop`. El workflow debe mostrar `build-and-test` en rojo, `image` sin ejecutarse y `deploy` como `skipped`. Guardar capturas del run y cerrar el Pull Request sin fusionarlo.

5. Eliminar el archivo temporal y la rama de prueba (local y remota). La rama `develop` no debe recibir el test fallido.

No se debe deshabilitar JaCoCo ni bajar el umbral para conseguir un pipeline verde. La evidencia debe proceder de la ejecución real de GitHub Actions.

## Alcance del bloque de Rocío

El bloqueo por fallas de seguridad (Snyk/Quality Gate) y los controles de SonarQube quedan para el bloque de Martín, que debe completar IE5 e IE6 en su dimensión de seguridad y cumplimiento.
