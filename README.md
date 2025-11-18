# Sistema de Órdenes E-commerce – Prueba Técnica Líder Técnico Java

Este repo es la implementación de la prueba técnica de **Sistema de Gestión de Órdenes E-commerce con arquitectura orientada a eventos**, usando:
- Java 17  
- Spring Boot 3.x  
- WebFlux (reactivo full, nada bloqueante)  
- Kafka  
- PostgreSQL (R2DBC)  
- MongoDB reactivo (event store / auditoría)  
- Docker & Docker Compose  

---

## 1. Descripción general

El sistema modela el flujo principal de una orden de compra en un e-commerce:

text
OrderCreated → ValidateInventory → ProcessPayment → ConfirmOrder → NotifyCustomer → UpdateInventory


Se divide en tres microservicios principales:

- **order-service (8080)**  
  Maneja todo el dominio de órdenes (crear, consultar, cancelar) y publica eventos en Kafka.

- **payment-service (8081)**  
  Simula el procesamiento de pagos, expone APIs para consultar y reintentar pagos y puede reaccionar a eventos de órdenes.

- **notification-service (8082)**  
  Consume eventos relevantes y registra "notificaciones" enviadas, con endpoint para consultar por orden.

Arquitectura de alto nivel (C4 simplificado):

mermaid
C4Context
    Person(customer, "Customer", "Cliente que compra en el e-commerce")
    System_Boundary(ecom, "E-commerce Orders System") {
        Container(orderService, "Order Service", "Spring Boot WebFlux", "Expone APIs reactivas y publica eventos")
        Container(paymentService, "Payment Service", "Spring Boot WebFlux", "Procesa pagos basados en eventos")
        Container(notificationService, "Notification Service", "Spring Boot WebFlux", "Registra notificaciones")
        ContainerDb(pg, "PostgreSQL (R2DBC)", "DB relacional", "Persistencia transaccional")
        ContainerDb(mongo, "MongoDB", "Event Store", "Auditoría y eventos")
        Container(kafka, "Kafka", "Message Broker", "Topics de integración")
    }

    Rel(customer, orderService, "HTTP REST")
    Rel(orderService, kafka, "Publica eventos")
    Rel(paymentService, kafka, "Consume/produce eventos")
    Rel(notificationService, kafka, "Consume eventos")
    Rel(orderService, pg, "R2DBC")
    Rel(paymentService, pg, "R2DBC")
    Rel(orderService, mongo, "Mongo Reactive")
    Rel(notificationService, mongo, "Mongo Reactive")


---

## 2. Decisiones técnicas principales (resumen rápido)

- **Clean / Hexagonal Architecture**  
  - Dominio aislado de frameworks (paquete domain sin anotaciones de Spring).  
  - Capas separadas: domain, application, infrastructure.  
  - El dominio define el lenguaje y las reglas; la infraestructura se encarga de DB, Kafka, HTTP, etc.

- **Event-Driven + Kafka**  
  - Eventos de dominio como OrderCreatedEvent, PaymentProcessedEvent, PaymentFailedEvent.  
  - Topics separados por responsabilidad (orders, payments, notifications).  
  - Servicios desacoplados: se hablan por eventos, no por REST entre ellos.

- **CQRS**  
  - Comandos para escribir: CreateOrderCommand, CancelOrderCommand, etc.  
  - Queries separadas para lectura: GetOrderByIdQuery, GetOrdersByCustomerQuery (en la capa de aplicación).

- **Event Sourcing (modo auditoría)**  
  - Cada evento relevante de la orden se persiste en Mongo como OrderEventDocument.  
  - El estado “en vivo” de la orden está en Postgres; la historia completa vive en Mongo.

- **Saga Pattern (simplificado)**  
  - El flujo de negocio se orquesta vía eventos.  
  - Si el pago falla, se emite un evento de fallo y la orden se puede compensar (por ejemplo, cancelación / rollback lógico).

Más detalle técnico está escrito en los ADRs bajo docs/ADRs/ (si el reviewer quiere ver el “por qué” de las decisiones).

---

## 3. Prerrequisitos

Para correr esto sin pelear:

- **Docker** y **Docker Compose** instalados (Docker Desktop está bien).  
- **Java 17** (por si querés correr algún servicio local sin Docker).  
- **Maven 3.9+** (para ejecutar mvn test en cada microservicio si querés revisarlo por separado).

---

## 4. Instrucciones de instalación y ejecución

1. Clonar el repo monorepo:

bash
git https://github.com/GatoGit/ecommerce-orders ecommerce-orders
cd ecommerce-orders


2. Copiar el archivo de variables de entorno base:

bash
cp .env.example .env


3. Levantar todo el ecosistema con Docker (infra + microservicios):

bash
docker-compose up --build


Esto levanta:

- PostgreSQL  
- MongoDB  
- Redis  
- Kafka + Zookeeper  
- **order-service** en http://localhost:8080  
- **payment-service** en http://localhost:8081  
- **notification-service** en http://localhost:8082  

4. Verificar health checks:

- http://localhost:8080/actuator/health  
- http://localhost:8081/actuator/health  
- http://localhost:8082/actuator/health  

Si todo responde {"status":"UP"}, ya quedaste listo para probar las APIs.

---

## 5. Endpoints disponibles (vista rápida)

### 5.1 Order Service (8080)

- **Crear orden**

http
POST http://localhost:8080/api/v1/orders
Content-Type: application/json

{
  "customerId": "11111111-1111-1111-1111-111111111111",
  "totalAmount": 149900
}


Respuesta (201 Created):

json
{
  "id": "2e5796bc-5ed5-444c-8f10-79dd163865a5",
  "customerId": "11111111-1111-1111-1111-111111111111",
  "status": "PENDING",
  "totalAmount": 149900.0,
  "createdAt": "2025-11-18T04:20:24.427963146Z",
  "updatedAt": "2025-11-18T04:20:24.427963146Z"
}


- **Obtener orden por ID**

http
GET http://localhost:8080/api/v1/orders/{orderId}


- **Listar órdenes por cliente**

http
GET http://localhost:8080/api/v1/orders?customerId={customerId}&page=0&size=10


- **Cancelar orden**

http
PATCH http://localhost:8080/api/v1/orders/{orderId}/cancel


Reglas:
- Solo se puede cancelar si la orden está en PENDING o CONFIRMED.  
- Si se intenta cancelar en otro estado, responde 409 CONFLICT con mensaje de negocio.

- **Historial de eventos de la orden**

http
GET http://localhost:8080/api/v1/orders/{orderId}/events


Devuelve los eventos de Mongo en orden cronológico (event sourcing de auditoría).

---

### 5.2 Payment Service (8081)

- **Consultar estado de pago de una orden**

http
GET http://localhost:8081/api/v1/payments/{orderId}


Respuesta ejemplo:

json
{
  "orderId": "2e5796bc-5ed5-444c-8f10-79dd163865a5",
  "status": "PENDING"
}


- **Reintentar pago**

http
POST http://localhost:8081/api/v1/payments/{orderId}/retry


Respuesta:

- 202 ACCEPTED → se encola el reintento (en un caso real podría publicar un evento PaymentRetryRequested).

---

### 5.3 Notification Service (8082)

- **Consultar notificaciones por orden**

http
GET http://localhost:8082/api/v1/notifications?orderId={orderId}


Respuesta ejemplo:

json
[
  {
    "orderId": "2e5796bc-5ed5-444c-8f10-79dd163865a5",
    "channel": "EMAIL",
    "message": "Notificación dummy para orden 2e5796bc-5ed5-444c-8f10-79dd163865a5",
    "createdAt": "2025-11-18T04:25:10Z"
  }
]


---

## 6. Repositorios Git y script para separarlos

Para esta prueba armé primero un **monorepo** (ecommerce-orders) con todo:
- Infraestructura compartida (docker-compose.yml, .env.example, docs, ADRs).  
- Código de los tres servicios en carpetas:
  - order-service/
  - payment-service/
  - notification-service/

La idea es poder trabajar cómodo en local con todo junto, pero al mismo tiempo tener la opción de que **cada microservicio viva en su propio repo Git** si la empresa lo quiere así.

### 6.1 Estructura planteada

- Repo raíz: ecommerce-orders
  - Contiene:
    - docker-compose.yml
    - docs (/docs, ADRs, diagramas)
    - scripts de apoyo (/scripts)
    - subcarpetas con el código de cada servicio:
      - order-service/
      - payment-service/
      - notification-service/

- Repos individuales sugeridos:
  - order-service
  - payment-service
  - notification-service

Con esto se puede:

- Trabajar desde el monorepo cuando se necesita levantar todo el entorno rápido.  
- Tener pipelines, issues y releases independientes por servicio en repos separados.  
- Incluso usar los repos de cada microservicio como submódulos del monorepo si se quiere formalizar esa relación.


## 7. Ejecución de tests

Dentro de cada microservicio (order-service/, payment-service/, notification-service/):

bash
mvn test


Para ver los reportes de cobertura (JaCoCo):

- Después de mvn test, abrir en el navegador:  
  target/site/jacoco/index.html de cada servicio.

Hay tests de dominio (reglas de negocio) y algunos tests reactivos usando StepVerifier.

---

## 8. Mejoras futuras

Si hubiera más tiempo, las cosas que se podrían meter encima de esta base:

- Autenticación y autorización con Spring Security + JWT/OAuth2.  
- API Gateway centralizado con Spring Cloud Gateway.  
- Outbox Pattern completo para garantizar consistencia entre Postgres y Kafka.  
- Manifests de Kubernetes (Deployments, Services, ConfigMaps, Secrets) y pipeline CI/CD en GitHub Actions.  
- Métricas de negocio (SLIs/SLOs) y dashboards para monitorear conversión, errores de pago, tiempos de respuesta, etc.

---
