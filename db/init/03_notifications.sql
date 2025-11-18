-- Tabla de notificaciones (Notification Service)
CREATE TABLE IF NOT EXISTS notifications (
    id           UUID PRIMARY KEY,
    order_id     UUID,
    channel      VARCHAR(50)  NOT NULL, -- EMAIL, SMS, WHATSAPP, PUSH, etc.
    type         VARCHAR(100) NOT NULL, -- ORDER_CREATED, ORDER_CONFIRMED, PAYMENT_FAILED, etc.
    payload      JSONB,
    status       VARCHAR(50)  NOT NULL, -- SENT, FAILED, RETRYING, etc.
    created_at   TIMESTAMPTZ  NOT NULL
);

-- Igual que arriba: sin IF NOT EXISTS
ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_order
    FOREIGN KEY (order_id)
    REFERENCES orders(id)
    ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_order_id
    ON notifications (order_id);

CREATE INDEX IF NOT EXISTS idx_notifications_type
    ON notifications (type);

CREATE INDEX IF NOT EXISTS idx_notifications_status
    ON notifications (status);
