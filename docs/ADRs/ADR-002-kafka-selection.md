# ADR-002: Elección de Kafka como message broker

## Estado
Aceptado

## Contexto
El sistema requiere una arquitectura orientada a eventos para soportar:
- Alto volumen de órdenes en campañas promocionales.
- Integración entre varios microservicios.
- Procesamiento asíncrono y resiliente ante picos.

Se necesita un broker que maneje alto throughput, particiones y retención de mensajes.

## Decisión
Se usa **Apache Kafka** como broker de eventos principal.

Justificación:
- Kafka es estándar de facto para arquitecturas event-driven a gran escala.
- Soporta particiones y replicación nativa, útil para escalar horizontalmente.
- Integración madura con el ecosistema de Spring (Spring Kafka, Kafka Streams).

## Consecuencias

Positivas:
- Base sólida para event sourcing y stream processing futuro.
- Ecosistema de tooling amplio (monitoring, UI de topics, etc.).
- Facilita implementar patrones como Saga y Outbox.

Negativas:
- Operarlo en producción no es trivial (cluster, seguridad, monitoreo).
- Para ambientes muy pequeños podría ser overkill frente a alternativas más simples.

## Alternativas Consideradas

1. **RabbitMQ**  
   Rechazada para esta prueba porque, aunque muy bueno para colas clásicas, Kafka cuadra mejor con el patrón de logs de eventos y retención historial.

2. **Eventos sobre base de datos (polling de tablas)**  
   Rechazada porque acopla fuertemente servicios a la misma base y no soporta de forma natural particiones y alto throughput.
