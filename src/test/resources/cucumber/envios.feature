# language: es
Característica: Servicio Envios (microservicio envios del caso caso17)
  Los escenarios validan el contrato REST del microservicio alineado a sus endpoints.

  Escenario: el listado del recurso responde 200
    Dado el servicio "Envios" está disponible
    Cuando consulto el listado de "envios"
    Entonces el listado responde con código 200

  Escenario: ciclo de vida completo del recurso
    Dado un nuevo "envio" con nombre "hola-cucumber"
    Cuando consulto el "envio" recién creado
    Entonces el recurso tiene nombre "hola-cucumber" y código 200
    Cuando actualizo el "envio" con nombre "cucumber-actualizado"
    Entonces el recurso queda con nombre "cucumber-actualizado" y código 200
    Cuando elimino el "envio"
    Entonces la eliminación responde con código 204
    Y al consultar el "envio" eliminado responde 404
