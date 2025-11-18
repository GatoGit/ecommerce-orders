# ADR-001: Uso de Clean / Hexagonal Architecture

## Estado
Aceptado

## Contexto
El sistema debe ser fácil de mantener y extender en el tiempo, con varios microservicios y múltiples integraciones (Kafka, Postgres, Mongo, Redis). Se quiere evitar que el dominio dependa de detalles de infraestructura o frameworks específicos.

## Decisión
Se adopta una arquitectura estilo Clean/Hexagonal con:
- Capa `domain` sin dependencias de Spring ni librerías externas.
- Capa `application` orquestando casos de uso (CQRS: comandos/queries).
- Capa `infrastructure` implementando adaptadores (REST, Kafka, repositorios, etc.).

Esta estructura se refleja en los paquetes de cada servicio:
- `com.example.orders.domain.*`
- `com.example.orders.application.*`
- `com.example.orders.infrastructure.*`

## Consecuencias

Positivas:
- El dominio se mantiene limpio y enfocado en reglas de negocio.
- Facilita testing de dominio sin levantar Spring ni contexto pesado.
- Permite cambiar detalles de infraestructura (por ejemplo Kafka por otro broker) con impacto acotado.

Negativas:
- Más capas y paquetes, por lo que la curva de entrada para devs nuevos es un poquito mayor.
- No todo el mundo está acostumbrado a esta separación, puede generar discusión inicial en el equipo.

## Alternativas Consideradas

1. **Arquitectura en capas clásica (controller → service → repository)**  
   Rechazada porque mezcla conceptos de aplicación y dominio, y tiende a meter lógica de negocio en donde no debería ("services" anémicos).

2. **Arquitectura completamente anémica centrada en DTOs**  
   Rechazada porque diluye las reglas de negocio en servicios utilitarios y hace más difícil razonar sobre el core del dominio.
