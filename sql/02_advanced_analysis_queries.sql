-- ============================================================
-- Blinkit BI Project — Advanced SQL Analysis Queries
-- (window functions, CTEs, RFM segmentation, cohort logic)
-- ============================================================
USE blinkit_bi;

-- 1. MONTHLY REVENUE TREND + MoM GROWTH -----------------------------
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m-01') AS month,
           SUM(order_total) AS revenue,
           COUNT(*) AS orders
    FROM orders
    GROUP BY month
)
SELECT month, revenue, orders,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100, 2) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- 2. CUSTOMER RFM SEGMENTATION ---------------------------------------
WITH rfm_base AS (
    SELECT c.customer_id,
           DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS recency_days,
           COUNT(o.order_id) AS frequency,
           SUM(o.order_total) AS monetary
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
),
scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(4) OVER (ORDER BY frequency ASC)     AS f_score,
           NTILE(4) OVER (ORDER BY monetary ASC)      AS m_score
    FROM rfm_base
)
SELECT customer_id, recency_days, frequency, monetary,
       (r_score + f_score + m_score) AS rfm_total,
       CASE
           WHEN (r_score + f_score + m_score) >= 10 THEN 'Champions'
           WHEN (r_score + f_score + m_score) >= 7  THEN 'Loyal'
           WHEN (r_score + f_score + m_score) >= 5  THEN 'At Risk'
           ELSE 'Dormant'
       END AS rfm_segment
FROM scored
ORDER BY rfm_total DESC;

-- 3. DELIVERY SLA PERFORMANCE BY PARTNER -----------------------------
SELECT delivery_partner_id,
       COUNT(*) AS total_deliveries,
       ROUND(AVG(delivery_time_minutes), 1) AS avg_delivery_min,
       SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) AS on_time_count,
       ROUND(SUM(CASE WHEN delivery_status = 'On Time' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS on_time_pct
FROM delivery_performance
GROUP BY delivery_partner_id
HAVING total_deliveries >= 10
ORDER BY on_time_pct DESC;

-- 4. TOP PRODUCTS BY CATEGORY (rank within group) ---------------------
WITH product_sales AS (
    SELECT p.category, p.product_name,
           SUM(oi.quantity * oi.unit_price) AS revenue,
           SUM(oi.quantity) AS units_sold
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_sales
)
SELECT category, product_name, revenue, units_sold
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- 5. MARKETING CHANNEL ROI SUMMARY -------------------------------------
SELECT channel,
       SUM(spend) AS total_spend,
       SUM(revenue_generated) AS total_revenue,
       ROUND(SUM(revenue_generated) / NULLIF(SUM(spend), 0), 2) AS blended_roas,
       ROUND(SUM(conversions) * 100.0 / NULLIF(SUM(clicks), 0), 2) AS conversion_rate_pct
FROM marketing_performance
GROUP BY channel
ORDER BY blended_roas DESC;

-- 6. INVENTORY DAMAGE RATE BY PRODUCT (reconciled feed) -----------------
SELECT p.product_name, p.category,
       SUM(ir.stock_received) AS total_received,
       SUM(ir.damaged_stock) AS total_damaged,
       ROUND(SUM(ir.damaged_stock) * 100.0 / NULLIF(SUM(ir.stock_received), 0), 2) AS damage_rate_pct
FROM inventory_reconciled ir
JOIN products p ON p.product_id = ir.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY damage_rate_pct DESC
LIMIT 20;

-- 7. CUSTOMER SATISFACTION vs DELIVERY DELAY (correlation view) ---------
SELECT o.is_delayed_flag,
       ROUND(AVG(f.rating), 2) AS avg_rating,
       COUNT(*) AS feedback_count
FROM customer_feedback f
JOIN (
    SELECT order_id,
           CASE WHEN delivery_status = 'On Time' THEN 'On Time' ELSE 'Delayed' END AS is_delayed_flag
    FROM orders
) o ON o.order_id = f.order_id
GROUP BY o.is_delayed_flag;
