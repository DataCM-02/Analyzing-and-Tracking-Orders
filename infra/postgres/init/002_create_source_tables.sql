CREATE TABLE IF NOT EXISTS ecommerce.customers (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(160) NOT NULL,
    segment VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    region VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT chk_customers_segment
        CHECK (segment IN ('small', 'medium', 'enterprise')),
    CONSTRAINT chk_customers_status
        CHECK (status IN ('active', 'inactive', 'blocked')),
    CONSTRAINT chk_customers_state
        CHECK (state ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_customers_dates
        CHECK (updated_at >= created_at)
);

CREATE TABLE IF NOT EXISTS ecommerce.products (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(160) NOT NULL,
    category VARCHAR(60) NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    weight_kg NUMERIC(10, 3) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT chk_products_price
        CHECK (unit_price > 0),
    CONSTRAINT chk_products_weight
        CHECK (weight_kg > 0),
    CONSTRAINT chk_products_status
        CHECK (status IN ('active', 'inactive')),
    CONSTRAINT chk_products_dates
        CHECK (updated_at >= created_at)
);

CREATE TABLE IF NOT EXISTS ecommerce.warehouses (
    warehouse_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    warehouse_code VARCHAR(20) NOT NULL UNIQUE,
    warehouse_name VARCHAR(120) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state CHAR(2) NOT NULL,
    region VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT chk_warehouses_state
        CHECK (state ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_warehouses_status
        CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS ecommerce.carriers (
    carrier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    carrier_code VARCHAR(20) NOT NULL UNIQUE,
    carrier_name VARCHAR(120) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',

    CONSTRAINT chk_carriers_status
        CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS ecommerce.orders (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id BIGINT NOT NULL,
    warehouse_id BIGINT,
    order_status VARCHAR(30) NOT NULL,
    service_level VARCHAR(20) NOT NULL,
    promised_delivery_at TIMESTAMPTZ NOT NULL,
    subtotal_amount NUMERIC(14, 2) NOT NULL,
    discount_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    shipping_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(14, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason VARCHAR(120),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES ecommerce.customers (customer_id),
    CONSTRAINT fk_orders_warehouse
        FOREIGN KEY (warehouse_id)
        REFERENCES ecommerce.warehouses (warehouse_id),
    CONSTRAINT chk_orders_status
        CHECK (
            order_status IN (
                'created',
                'payment_pending',
                'paid',
                'allocated',
                'picking',
                'picked',
                'packed',
                'shipped',
                'in_transit',
                'delivered',
                'cancelled'
            )
        ),
    CONSTRAINT chk_orders_service_level
        CHECK (service_level IN ('standard', 'express', 'priority')),
    CONSTRAINT chk_orders_amounts
        CHECK (
            subtotal_amount >= 0
            AND discount_amount >= 0
            AND discount_amount <= subtotal_amount
            AND shipping_amount >= 0
            AND tax_amount >= 0
            AND total_amount = (
                subtotal_amount
                - discount_amount
                + shipping_amount
                + tax_amount
            )
        ),
    CONSTRAINT chk_orders_dates
        CHECK (
            updated_at >= created_at
            AND promised_delivery_at >= created_at
            AND (
                cancelled_at IS NULL
                OR cancelled_at >= created_at
            )
        ),
    CONSTRAINT chk_orders_cancellation
        CHECK (
            (
                order_status = 'cancelled'
                AND cancelled_at IS NOT NULL
            )
            OR (
                order_status <> 'cancelled'
                AND cancelled_at IS NULL
            )
        )
);

CREATE TABLE IF NOT EXISTS ecommerce.order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12, 2) NOT NULL,
    discount_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES ecommerce.orders (order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES ecommerce.products (product_id),
    CONSTRAINT uq_order_items_product
        UNIQUE (order_id, product_id),
    CONSTRAINT chk_order_items_quantity
        CHECK (quantity > 0),
    CONSTRAINT chk_order_items_amounts
        CHECK (
            unit_price > 0
            AND discount_amount >= 0
            AND discount_amount <= quantity * unit_price
        )
);

CREATE TABLE IF NOT EXISTS ecommerce.payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_reference VARCHAR(40) NOT NULL UNIQUE,
    order_id BIGINT NOT NULL,
    attempt_number SMALLINT NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    approved_at TIMESTAMPTZ,

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES ecommerce.orders (order_id),
    CONSTRAINT uq_payments_attempt
        UNIQUE (order_id, attempt_number),
    CONSTRAINT chk_payments_attempt
        CHECK (attempt_number > 0),
    CONSTRAINT chk_payments_status
        CHECK (
            payment_status IN (
                'pending',
                'approved',
                'declined',
                'refunded'
            )
        ),
    CONSTRAINT chk_payments_method
        CHECK (
            payment_method IN (
                'credit_card',
                'bank_transfer',
                'invoice'
            )
        ),
    CONSTRAINT chk_payments_amount
        CHECK (amount > 0),
    CONSTRAINT chk_payments_dates
        CHECK (
            approved_at IS NULL
            OR approved_at >= created_at
        ),
    CONSTRAINT chk_payments_approval
        CHECK (
            payment_status <> 'approved'
            OR approved_at IS NOT NULL
        )
);

CREATE TABLE IF NOT EXISTS ecommerce.shipments (
    shipment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_number VARCHAR(30) NOT NULL UNIQUE,
    order_id BIGINT NOT NULL,
    carrier_id BIGINT NOT NULL,
    shipment_status VARCHAR(20) NOT NULL,
    delivery_attempts SMALLINT NOT NULL DEFAULT 0,
    shipped_at TIMESTAMPTZ,
    in_transit_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,

    CONSTRAINT fk_shipments_order
        FOREIGN KEY (order_id)
        REFERENCES ecommerce.orders (order_id),
    CONSTRAINT fk_shipments_carrier
        FOREIGN KEY (carrier_id)
        REFERENCES ecommerce.carriers (carrier_id),
    CONSTRAINT chk_shipments_status
        CHECK (
            shipment_status IN (
                'created',
                'shipped',
                'in_transit',
                'delivered',
                'failed'
            )
        ),
    CONSTRAINT chk_shipments_attempts
        CHECK (delivery_attempts >= 0),
    CONSTRAINT chk_shipments_dates
        CHECK (
            (
                in_transit_at IS NULL
                OR shipped_at IS NULL
                OR in_transit_at >= shipped_at
            )
            AND (
                delivered_at IS NULL
                OR shipped_at IS NULL
                OR delivered_at >= shipped_at
            )
        ),
    CONSTRAINT chk_shipments_delivery
        CHECK (
            shipment_status <> 'delivered'
            OR delivered_at IS NOT NULL
        )
);

CREATE TABLE IF NOT EXISTS ecommerce.shipment_items (
    shipment_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_id BIGINT NOT NULL,
    order_item_id BIGINT NOT NULL,
    quantity_shipped INTEGER NOT NULL,
    quantity_delivered INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT fk_shipment_items_shipment
        FOREIGN KEY (shipment_id)
        REFERENCES ecommerce.shipments (shipment_id),
    CONSTRAINT fk_shipment_items_order_item
        FOREIGN KEY (order_item_id)
        REFERENCES ecommerce.order_items (order_item_id),
    CONSTRAINT uq_shipment_items_order_item
        UNIQUE (shipment_id, order_item_id),
    CONSTRAINT chk_shipment_items_quantities
        CHECK (
            quantity_shipped > 0
            AND quantity_delivered >= 0
            AND quantity_delivered <= quantity_shipped
        )
);

CREATE TABLE IF NOT EXISTS ecommerce.order_events (
    event_record_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id UUID NOT NULL,
    order_id BIGINT NOT NULL,
    event_type VARCHAR(40) NOT NULL,
    event_time TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL,
    source_system VARCHAR(20) NOT NULL,
    event_payload JSONB NOT NULL DEFAULT '{}'::JSONB,

    CONSTRAINT chk_order_events_type
        CHECK (
            event_type IN (
                'order_created',
                'payment_approved',
                'order_allocated',
                'picking_started',
                'picking_completed',
                'order_packed',
                'order_shipped',
                'in_transit',
                'delivery_attempted',
                'order_delivered',
                'order_cancelled'
            )
        ),
    CONSTRAINT chk_order_events_source
        CHECK (
            source_system IN ('erp', 'payment', 'wms', 'tms')
        )
);

CREATE INDEX IF NOT EXISTS idx_orders_customer
    ON ecommerce.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_warehouse
    ON ecommerce.orders (warehouse_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
    ON ecommerce.orders (order_status);

CREATE INDEX IF NOT EXISTS idx_order_items_order
    ON ecommerce.order_items (order_id);

CREATE INDEX IF NOT EXISTS idx_payments_order
    ON ecommerce.payments (order_id);

CREATE INDEX IF NOT EXISTS idx_shipments_order
    ON ecommerce.shipments (order_id);

CREATE INDEX IF NOT EXISTS idx_order_events_order_time
    ON ecommerce.order_events (order_id, event_time);

CREATE INDEX IF NOT EXISTS idx_order_events_event_id
    ON ecommerce.order_events (event_id);