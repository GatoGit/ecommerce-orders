# Autoevaluación – Prueba Técnica Líder Técnico Java

## 1. Funcionalidades completadas

### Order Service (core de órdenes)

- **Crear orden (POST `/api/v1/orders`)**
  - API reactiva con Spring WebFlux.
  - Valida `customerId` (UUID) y que el monto sea > 0.
  - Crea la orden desde el dominio (`Order.create`), con:
    - `id` (UUID) generado en el dominio.
    - Estado inicial `PENDING`.
    - `createdAt` y `updatedAt` seteados en el dominio.

- **Consultar orden por ID (GET `/api/v1/orders/{id}`)**
  - Busca en Postgres vía R2DBC.
  - Si no existe, responde `404` con mensaje claro (`Orden no encontrada`).

- **Listar órdenes por cliente (GET `/api/v1/orders?customerId=...`)**
  - Soporta paginación con `page` y `size`.
  - Si no se envía `customerId`, devuelve todas las órdenes (modo demo / exploración).

- **Cancelar orden (PATCH `/api/v1/orders/{id}/cancel`)**
  - Solo permite cancelar si la orden está en `PENDING` o `CONFIRMED`.
  - Si el estado no se puede cancelar, devuelve `409 CONFLICT` con mensaje descriptivo.
  - Si no existe la orden, devuelve `404`.

- **Historial de eventos (GET `/api/v1/orders/{id}/events`)**
  - Lee el event store en MongoDB.
  - Devuelve la secuencia de eventos de la orden ordenados por fecha.
  - Útil para auditoría y trazabilidad.

### Procesamiento asíncrono y eventos

- **Publicación de `OrderCreated` en Kafka**
  - Cada vez que se crea una orden, se:
    - Persiste en Postgres.
    - Intenta guardar el evento en Mongo.
    - Publica `OrderCreatedEvent` en el topico `orders` con la `orderId` como key.
  - Maneja errores al enviar a Kafka con logs claros.

- **Payment Service**
  - Expone:
    - `GET /api/v1/payments/{orderId}` → devuelve el estado actual del pago (simulado).
    - `POST /api/v1/payments/{orderId}/retry` → dispara un reintento asíncrono (simulado).
  - Preparado para reaccionar a eventos de Kafka (ej: `OrderConfirmed`, `PaymentProcessed`), aunque la lógica está simplificada para la prueba.

- **Notification Service**
  - Expone:
    - `GET /api/v1/notifications?orderId=...` → devuelve notificaciones asociadas a la orden (respuestas dummy para la demo).
  - Pensado para consumir eventos y registrar notificaciones enviadas.

### Arquitectura / Diseño

- **Clean / Hexagonal-ish**
  - Separación clara:
    - `domain`: entidades, estados y reglas de negocio.
    - `application`: comandos, casos de uso y orquestación.
    - `infrastructure`: controllers WebFlux, repositorios R2DBC/Mongo, Kafka, config.
  - El dominio no depende de Spring ni de infraestructura.

- **CQRS**
  - Commands:
    - `CreateOrderCommand`, `CancelOrderCommand`.
  - Queries:
    - Lectura de órdenes y eventos con repos específicos (R2DBC / Mongo).
  - La separación no es religiosa, pero sí clara para crecer el diseño.

- **Event Sourcing (a nivel auditoría)**
  - Cada acción relevante genera un `OrderEventDocument` en Mongo.
  - Sirve para reconstruir la historia de lo que le ha pasado a una orden.

### Infraestructura

- `docker-compose` que levanta:

  - **Postgres** (R2DBC) → estado transaccional de órdenes y pagos.
  - **MongoDB** → event store / auditoría.
  - **Kafka + Zookeeper** → bus de eventos.
  - **Redis** → listo para usar como caché reactivo (no explotado al 100% por tiempo).
  - **order-service**, **payment-service**, **notification-service** con perfil `docker`.

- `.env.example` con variables de entorno clave para que sea fácil configurarlo.

### Testing y observabilidad

- **Tests**
  - Tests de dominio para:
    - Reglas de transición de estado (`PENDING`, `CONFIRMED`, `CANCELLED`, etc.).
    - Validación de cancelación solo en estados permitidos.
  - Tests reactivos con `StepVerifier` en casos de uso principales.

- **Observabilidad**
  - Spring Boot Actuator:
    - `/actuator/health`, `/actuator/info`, `/actuator/metrics` básicos.
  - Logs pensados para ser parseados como JSON (campos clave bien estructurados).
  - Correlation ID:
    - Propagado a través de headers y trazado en logs (a un nivel básico, listo para extender).

---

## 2. Funcionalidades pendientes o simplificadas

- **Inventario real**
  - No se implementó un `Inventory Service` completo.
  - La validación de inventario está simplificada; en un escenario real habría otro microservicio con su propio modelo y eventos.

- **Saga completa**
  - Hay esqueleto de eventos (`OrderCreated`, `PaymentProcessed`, `PaymentFailed`), pero:
    - No se modeló toda la saga “perfecta” con todos los casos raros de reintento, tiempo de espera, etc.
    - El flujo de compensaciones está simplificado para la prueba.

- **Idempotencia en todos los consumidores**
  - Se empieza a manejar la idea (por ejemplo, con el uso de `orderId` como clave de mensaje y un `eventId` en Mongo), pero:
    - No se implementó una tabla/colección dedicada a “mensajes procesados”.
    - En un entorno productivo habría un diseño más agresivo para evitar procesar dos veces el mismo mensaje.

**Motivo principal:**  
Entre todo lo que pedía la prueba, preferí asegurarme de que el core de órdenes quedara consistente, bien estructurado y defendible en una conversación técnica, en lugar de dejar muchos servicios a medias.

---

## 3. Qué haría distinto con 2 semanas más

Si tuviera más tiempo, el roadmap técnico sería algo así:

1. **Outbox Pattern bien montado**
   - Tabla outbox en Postgres por servicio.
   - Publicación a Kafka desacoplada de la transacción principal.
   - Worker reactivo leyendo outbox y enviando a Kafka con confirmación.

2. **Saga más robusta**
   - Manejo de reintentos con backoff para pagos.
   - Tiempos máximos de espera para transiciones (ej: si pago nunca responde, marcar orden como `FAILED` o `EXPIRED`).
   - Integración más realista con Notification Service (email/SMS/WhatsApp simulado).

3. **Seguridad y API Gateway**
   - Spring Cloud Gateway al frente.
   - JWT con roles por servicio (ej: solo ciertos clientes pueden cancelar una orden).
   - Rate limiting por API key / cliente.

4. **Más testing de integración**
   - Testcontainers para levantar Postgres, Mongo y Kafka en los tests.
   - Flujos end-to-end completos:
     - Crear orden → publicar evento → simular pago → actualizar estado → notificar.
   - Cobertura objetivo > 80% en dominio + application.

5. **Preparar despliegue productivo**
   - Manifests de Kubernetes (Deployments, Services, ConfigMaps, Secrets).
   - Pipeline CI/CD (GitHub Actions o GitLab CI) con:
     - build + tests
     - análisis estático
     - empaquetado Docker
     - despliegue a un entorno de prueba.

---

## 4. Retos que me encontré

**Trabajar todo de forma reactiva**  
  Usar WebFlux, R2DBC y Mongo reactivo cambia la forma “normal” de programar. Toca pensar en flujos, backpressure y manejo de errores sin bloquear hilos.  
  Para eso me apoyé bastante en `StepVerifier` y en pruebas manuales de los endpoints, validando que el flujo se comportara bien y que los controladores siguieran siendo no bloqueantes.

---

## 5. Trade-offs que tomé

- **Preferí un flujo core fácil de leer y explicar**
  - En vez de cubrir todos los escenarios raros del universo, me enfoqué en que el flujo principal de una orden (crear, consultar, cancelar, ver eventos) quedara ordenado y entendible.
  - La idea es que cualquier dev que llegue al repo pueda seguir el camino de la orden sin sufrir.

- **Saga sencilla, sin pasarme de diseño**
  - Usé eventos entre servicios en lugar de un orquestador gigante.
  - Es más fácil de mantener y crece mejor en un e-commerce real, donde a futuro podés sumar más servicios (ej: facturación, puntos de fidelidad, etc.) sin romper todo.

- **Event sourcing “light”**
  - La verdad oficial de la orden vive en Postgres.
  - Mongo se usa para guardar la historia de eventos y tener auditoría.
  - Es un punto medio: ya tengo trazabilidad y puedo mostrar el historial completo, pero sin obligarme a reconstruir el estado solo desde eventos (lo cual mete bastante complejidad extra).
