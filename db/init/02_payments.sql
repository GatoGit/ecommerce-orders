-- Tabla de pagos asociada a órdenes (Payment Service)
CREATE TABLE IF NOT EXISTS payments (
    id                UUID PRIMARY KEY,
    order_id          UUID        NOT NULL,
    status            VARCHAR(50) NOT NULL, -- PENDING, PROCESSING, PAID, FAILED, REFUNDED
    amount            NUMERIC(19,2) NOT NULL,
    provider          VARCHAR(100),         -- Ej: "FAKE_GATEWAY", "STRIPE", etc.
    external_ref      VARCHAR(150),         -- ID externo del gateway
    error_code        VARCHAR(100),
    error_message     TEXT,
    created_at        TIMESTAMPTZ NOT NULL,
    updated_at        TIMESTAMPTZ NOT NULL
);

-- OJO: Postgres no soporta "ADD CONSTRAINT IF NOT EXISTS"
-- Como estos scripts solo corren la PRIMERA vez que se crea la BD,
-- podemos usar un ALTER TABLE normal sin IF NOT EXISTS.

ALTER TABLE payments
    ADD CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id)
    REFERENCES orders(id)
    ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_payments_order_id
    ON payments (order_id);

CREATE INDEX IF NOT EXISTS idx_payments_status
    ON payments (status);
