# Modelo Entidad-Relación (Texto)

## PostgreSQL (transaccional)

- **orders**
  - id (UUID, PK)
  - customer_id (UUID)
  - status (varchar)
  - total_amount (numeric)
  - created_at (timestamp)
  - updated_at (timestamp)

- **payments**
  - id (UUID, PK)
  - order_id (UUID, FK orders.id)
  - status (varchar)
  - amount (numeric)
  - created_at (timestamp)
  - updated_at (timestamp)

## MongoDB (event store / auditoría)

- **order_events**
  - id (ObjectId)
  - orderId (UUID)
  - type (string) – OrderCreated, OrderConfirmed, PaymentProcessed, etc.
  - payload (object/json)
  - createdAt (date)
