# Envios — Contrato de la API REST

## Base

- **Base path**: /api/envios
- **Formato**: JSON — **Puerto**: 8080 (configurable con `PORT`)

## Recursos

| Método | Ruta | Códigos de estado | Descripción |
|--------|------|-------------------|-------------|
| GET | /api/envios | 200 | Lista todos los recursos |
| GET | /api/envios/{id} | 200 / 404 | Obtiene un recurso por id |
| POST | /api/envios | 201 / 400 | Crea un recurso |
| PUT | /api/envios/{id} | 200 / 404 / 400 | Actualiza un recurso |
| DELETE | /api/envios/{id} | 204 / 404 | Elimina un recurso |

## Atributos de un recurso

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| id | Long | - | Identificador autogenerado |
| nombre | String | Sí | Nombre del recurso |

| origen | String | No | Ciudad o punto de origen |
| pesoKg | BigDecimal | No | Peso del paquete en kilos |

## Ejemplos con curl

```bash
# Listar
curl http://localhost:8080/api/envios

# Crear
curl -X POST http://localhost:8080/api/envios \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Mi recurso"}'

# Obtener por id
curl http://localhost:8080/api/envios/1

# Actualizar
curl -X PUT http://localhost:8080/api/envios/1 \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Recurso actualizado"}'

# Eliminar
curl -X DELETE http://localhost:8080/api/envios/1
```
