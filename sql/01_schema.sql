-- ============================================================
-- Blinkit BI Project — MySQL Warehouse Schema
-- ============================================================
CREATE DATABASE IF NOT EXISTS blinkit_bi;
USE blinkit_bi;

CREATE TABLE customers (
    customer_id        BIGINT PRIMARY KEY,
    customer_name       VARCHAR(150),
    email               VARCHAR(150),
    phone               VARCHAR(20),
    address             VARCHAR(255),
    area                VARCHAR(100),
    pincode             VARCHAR(10),
    registration_date   DATE,
    customer_segment    VARCHAR(30),
    total_orders        INT,
    avg_order_value     DECIMAL(10,2)
);

CREATE TABLE products (
    product_id          BIGINT PRIMARY KEY,
    product_name         VARCHAR(150),
    category             VARCHAR(100),
    brand                VARCHAR(150),
    price                DECIMAL(10,2),
    mrp                  DECIMAL(10,2),
    margin_percentage    DECIMAL(5,2),
    shelf_life_days      INT,
    min_stock_level      INT,
    max_stock_level      INT
);

CREATE TABLE orders (
    order_id                 BIGINT PRIMARY KEY,
    customer_id              BIGINT,
    order_date               DATETIME,
    promised_delivery_time   DATETIME,
    actual_delivery_time     DATETIME,
    delivery_status          VARCHAR(30),
    order_total              DECIMAL(10,2),
    payment_method           VARCHAR(20),
    delivery_partner_id      BIGINT,
    store_id                 BIGINT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id     BIGINT,
    product_id   BIGINT,
    quantity     INT,
    unit_price   DECIMAL(10,2),
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE delivery_performance (
    order_id               BIGINT PRIMARY KEY,
    delivery_partner_id    BIGINT,
    promised_time          DATETIME,
    actual_time             DATETIME,
    delivery_time_minutes  DECIMAL(6,1),
    distance_km            DECIMAL(5,2),
    delivery_status        VARCHAR(30),
    reasons_if_delayed     VARCHAR(100),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE customer_feedback (
    feedback_id         BIGINT PRIMARY KEY,
    order_id            BIGINT,
    customer_id         BIGINT,
    rating              TINYINT,
    feedback_text        TEXT,
    feedback_category   VARCHAR(50),
    sentiment           VARCHAR(20),
    feedback_date       DATE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE marketing_performance (
    campaign_id         BIGINT PRIMARY KEY,
    campaign_name        VARCHAR(150),
    campaign_date        DATE,
    target_audience      VARCHAR(50),
    channel              VARCHAR(50),
    impressions          INT,
    clicks                INT,
    conversions           INT,
    spend                 DECIMAL(10,2),
    revenue_generated     DECIMAL(10,2),
    roas                  DECIMAL(6,2)
);

CREATE TABLE inventory_reconciled (
    inventory_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id        BIGINT,
    stock_date        DATE,
    stock_received    INT,
    damaged_stock     INT,
    source_feed       VARCHAR(20),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Helpful indexes for the dashboard's most common filters
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE INDEX idx_feedback_sentiment ON customer_feedback(sentiment);
CREATE INDEX idx_inventory_product_date ON inventory_reconciled(product_id, stock_date);
