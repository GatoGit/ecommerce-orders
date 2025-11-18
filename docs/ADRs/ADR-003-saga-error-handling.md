# ADR-003: Estrategia de manejo de errores y compensaciones en la Saga

## Estado
Aceptado

## Contexto
El flujo de una orden involucra varios pasos distribuidos:
- Validar inventario.
- Procesar pago.
- Confirmar orden.
- Notificar cliente.

No se puede usar una transacción distribuida clásica (2PC), así que se requiere una estrategia tipo **Saga** con eventos.

## Decisión
Se implementa una Saga coreografiada (basada en eventos) donde:
- Cada servicio reacciona a eventos de otros (por ejemplo, `OrderConfirmed` → `payment-service` inicia pago).
- En caso de error en el pago (`PaymentFailed`), se publica un evento de compensación que lleva a cancelar la orden (`OrderCancelled`).

La lógica de compensación se concentra en:
- `order-service`: cambio de estado a `FAILED` o `CANCELLED` según el caso.
- (A futuro) un servicio de inventario podría escuchar para liberar stock.

## Consecuencias

Positivas:
- Alta desacoplación entre servicios, cada uno escucha eventos y reacciona.
- Más fácil de escalar y evolucionar sin un "orquestador" central gigantesco.

Negativas:
- La trazabilidad de la saga requiere buen manejo de correlation IDs y logs.
- El orden exacto de ciertos eventos puede complicarse en escenarios extremos.

## Alternativas Consideradas

1. **Saga orquestada con un servicio central**  
   Rechazada para esta prueba porque introduce un componente adicional (el orquestador) y aumenta complejidad, sin tanto beneficio para el tamaño del sistema.

2. **No usar Saga, solo flags en BD**  
   Rechazada porque no resuelve realmente las inconsistencias entre servicios en caso de fallo parcial.
