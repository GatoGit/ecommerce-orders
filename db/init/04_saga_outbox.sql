-- Outbox table para coordinar Sagas / eventos a Kafka
CREATE TABLE IF NOT EXISTS saga_outbox (
    id             BIGSERIAL PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL, -- ORDER, PAYMENT, etc.
    aggregate_id   UUID         NOT NULL, -- ID de la orden/pago, etc.
    event_type     VARCHAR(150) NOT NULL, -- OrderCreated, OrderConfirmed, PaymentProcessed, etc.
    payload        JSONB        NOT NULL, -- Evento de dominio serializado
    status         VARCHAR(30)  NOT NULL, -- PENDING, PUBLISHED, FAILED
    created_at     TIMESTAMPTZ  NOT NULL,
    published_at   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_saga_outbox_status_created_at
    ON saga_outbox (status, created_at);

CREATE INDEX IF NOT EXISTS idx_saga_outbox_aggregate
    ON saga_outbox (aggregate_type, aggregate_id);
