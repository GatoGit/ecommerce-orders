-- Tabla de órdenes 
CREATE TABLE IF NOT EXISTS orders (
    id           UUID PRIMARY KEY,
    customer_id  UUID        NOT NULL,
    status       VARCHAR(50) NOT NULL,  -- PENDING, CONFIRMED, PAYMENT_PROCESSING, PAID, SHIPPED, DELIVERED, CANCELLED, FAILED
    total_amount NUMERIC(19,2) NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL
);

-- Índices útiles para queries por cliente y estado
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);
