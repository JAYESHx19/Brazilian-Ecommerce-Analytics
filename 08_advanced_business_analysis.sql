-- ============================================================
-- 08_advanced_business_analysis.sql
-- Brazilian E-Commerce Advanced Business Analysis
-- Dataset: Olist Brazilian E-Commerce
-- SQL Engine: SQLite
-- ============================================================

-- PURPOSE
-- Combine sales, customers, products, sellers, logistics, payments,
-- and reviews into business-focused analyses.
--
-- NOTE:
-- * Revenue/sales value here refers to product price and/or price + freight.
-- * The dataset does not contain product cost, so PROFIT is not calculated.
-- * customer_unique_id is used for repeat-customer analysis.
-- * Product category is obtained through products, not order_items.
-- ============================================================


-- ============================================================
-- SECTION 01 — ORDER-LEVEL SALES DATASET
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS product_sales,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_sales_value,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    os.product_sales,
    os.freight_value,
    os.total_sales_value,
    os.item_count
FROM orders o
LEFT JOIN order_sales os
    ON o.order_id = os.order_id;


-- ============================================================
-- SECTION 02 — ORDER VALUE SEGMENTATION
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    CASE
        WHEN total_sales_value < 50 THEN '< R$50'
        WHEN total_sales_value < 100 THEN 'R$50-R$99'
        WHEN total_sales_value < 250 THEN 'R$100-R$249'
        WHEN total_sales_value < 500 THEN 'R$250-R$499'
        ELSE 'R$500+'
    END AS order_value_segment,
    COUNT(*) AS order_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(AVG(total_sales_value), 2) AS average_order_value
FROM order_sales
GROUP BY order_value_segment
ORDER BY
    CASE order_value_segment
        WHEN '< R$50' THEN 1
        WHEN 'R$50-R$99' THEN 2
        WHEN 'R$100-R$249' THEN 3
        WHEN 'R$250-R$499' THEN 4
        WHEN 'R$500+' THEN 5
    END;


-- ============================================================
-- SECTION 03 — CUSTOMER LIFETIME VALUE (OBSERVED)
-- ============================================================
-- Observed customer value = total product sales across their orders.
-- This is not a forecasted CLV model.

WITH customer_sales AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(oi.price) AS product_sales
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN product_sales < 100 THEN '< R$100'
        WHEN product_sales < 250 THEN 'R$100-R$249'
        WHEN product_sales < 500 THEN 'R$250-R$499'
        WHEN product_sales < 1000 THEN 'R$500-R$999'
        ELSE 'R$1000+'
    END AS customer_value_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(product_sales), 2) AS total_product_sales,
    ROUND(AVG(product_sales), 2) AS average_customer_value,
    ROUND(AVG(order_count), 2) AS average_orders_per_customer
FROM customer_sales
GROUP BY customer_value_segment
ORDER BY average_customer_value DESC;


-- ============================================================
-- SECTION 04 — TOP CUSTOMERS BY OBSERVED VALUE
-- ============================================================

SELECT
    c.customer_unique_id,
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(oi.price), 2) AS product_sales
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id, c.customer_state
ORDER BY product_sales DESC
LIMIT 100;


-- ============================================================
-- SECTION 05 — REPEAT CUSTOMER REVENUE CONTRIBUTION
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
customer_sales AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS product_sales
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN co.order_count = 1 THEN 'One-time'
        ELSE 'Repeat'
    END AS customer_type,
    COUNT(*) AS customers,
    ROUND(SUM(cs.product_sales), 2) AS product_sales,
    ROUND(
        SUM(cs.product_sales) * 100.0
        / (SELECT SUM(product_sales) FROM customer_sales),
        2
    ) AS sales_share_pct
FROM customer_orders co
JOIN customer_sales cs
    ON co.customer_unique_id = cs.customer_unique_id
GROUP BY customer_type;


-- ============================================================
-- SECTION 06 — MONTHLY SALES WITH CUSTOMER COUNTS
-- ============================================================

SELECT
    STRFTIME('%Y-%m', o.order_purchase_timestamp) AS sales_month,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY sales_month
ORDER BY sales_month;


-- ============================================================
-- SECTION 07 — MONTH-OVER-MONTH PRODUCT SALES GROWTH
-- ============================================================

WITH monthly_sales AS (
    SELECT
        STRFTIME('%Y-%m', o.order_purchase_timestamp) AS sales_month,
        SUM(oi.price) AS product_sales
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY sales_month
)
SELECT
    sales_month,
    ROUND(product_sales, 2) AS product_sales,
    ROUND(
        product_sales
        - LAG(product_sales) OVER (ORDER BY sales_month),
        2
    ) AS change_from_previous_month,
    ROUND(
        (
            product_sales
            - LAG(product_sales) OVER (ORDER BY sales_month)
        ) * 100.0
        / NULLIF(LAG(product_sales) OVER (ORDER BY sales_month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY sales_month;


-- ============================================================
-- SECTION 08 — CUSTOMER ACQUISITION BY MONTH
-- ============================================================
-- First observed purchase month for each customer_unique_id.

WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(STRFTIME('%Y-%m', o.order_purchase_timestamp)) AS first_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    first_month,
    COUNT(*) AS new_customers
FROM first_purchase
GROUP BY first_month
ORDER BY first_month;


-- ============================================================
-- SECTION 09 — CUSTOMER REPEAT RATE BY FIRST PURCHASE MONTH
-- ============================================================

WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        MIN(STRFTIME('%Y-%m', o.order_purchase_timestamp)) AS first_month
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    first_month,
    COUNT(*) AS customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS repeat_rate_pct
FROM customer_order_counts
GROUP BY first_month
ORDER BY first_month;


-- ============================================================
-- SECTION 10 — CATEGORY SALES OVERVIEW
-- ============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.order_item_id) AS item_units,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
ORDER BY product_sales DESC;


-- ============================================================
-- SECTION 11 — CATEGORY SALES RANKING
-- ============================================================

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,
        SUM(oi.price) AS product_sales
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY category
)
SELECT
    category,
    ROUND(product_sales, 2) AS product_sales,
    RANK() OVER (ORDER BY product_sales DESC) AS sales_rank
FROM category_sales
ORDER BY sales_rank;


-- ============================================================
-- SECTION 12 — CATEGORY REVENUE CONCENTRATION
-- ============================================================

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,
        SUM(oi.price) AS product_sales
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY category
),
ranked AS (
    SELECT
        category,
        product_sales,
        RANK() OVER (ORDER BY product_sales DESC) AS sales_rank
    FROM category_sales
)
SELECT
    category,
    ROUND(product_sales, 2) AS product_sales,
    sales_rank,
    ROUND(
        SUM(product_sales) OVER (
            ORDER BY sales_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0
        / SUM(product_sales) OVER (),
        2
    ) AS cumulative_sales_share_pct
FROM ranked
ORDER BY sales_rank;


-- ============================================================
-- SECTION 13 — SELLER PERFORMANCE
-- ============================================================

SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS orders,
    COUNT(*) AS item_units,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
GROUP BY s.seller_id, s.seller_state
ORDER BY product_sales DESC
LIMIT 100;


-- ============================================================
-- SECTION 14 — SELLER SALES CONCENTRATION
-- ============================================================

WITH seller_sales AS (
    SELECT
        seller_id,
        SUM(price) AS product_sales
    FROM order_items
    GROUP BY seller_id
),
ranked AS (
    SELECT
        seller_id,
        product_sales,
        RANK() OVER (ORDER BY product_sales DESC) AS sales_rank
    FROM seller_sales
)
SELECT
    seller_id,
    ROUND(product_sales, 2) AS product_sales,
    sales_rank,
    ROUND(
        SUM(product_sales) OVER (
            ORDER BY sales_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0
        / SUM(product_sales) OVER (),
        2
    ) AS cumulative_sales_share_pct
FROM ranked
ORDER BY sales_rank
LIMIT 100;


-- ============================================================
-- SECTION 15 — SELLER DELIVERY PERFORMANCE
-- ============================================================

SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        AVG(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp)
        ),
        2
    ) AS avg_delivery_days,
    ROUND(
        AVG(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_estimated_delivery_date)
        ),
        2
    ) AS avg_days_vs_estimate
FROM sellers s
JOIN order_items oi
    ON s.seller_id = oi.seller_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL
GROUP BY s.seller_id, s.seller_state
HAVING COUNT(DISTINCT o.order_id) >= 20
ORDER BY avg_delivery_days ASC;


-- ============================================================
-- SECTION 16 — STATE SALES AND SATISFACTION
-- ============================================================

WITH state_sales AS (
    SELECT
        c.customer_state,
        SUM(oi.price) AS product_sales,
        COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_state
),
state_reviews AS (
    SELECT
        c.customer_state,
        AVG(r.review_score) AS avg_review_score
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_reviews r
        ON o.order_id = r.order_id
    GROUP BY c.customer_state
)
SELECT
    ss.customer_state,
    ss.orders,
    ROUND(ss.product_sales, 2) AS product_sales,
    ROUND(sr.avg_review_score, 2) AS average_review_score
FROM state_sales ss
LEFT JOIN state_reviews sr
    ON ss.customer_state = sr.customer_state
ORDER BY ss.product_sales DESC;


-- ============================================================
-- SECTION 17 — PAYMENT METHOD + CUSTOMER VALUE
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id) AS orders,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    ROUND(SUM(os.total_sales_value), 2) AS total_sales_value,
    ROUND(AVG(os.total_sales_value), 2) AS average_order_value
FROM order_payments p
JOIN orders o
    ON p.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_sales os
    ON o.order_id = os.order_id
GROUP BY p.payment_type
ORDER BY total_sales_value DESC;


-- ============================================================
-- SECTION 18 — PAYMENT INSTALLMENTS VS ORDER VALUE
-- ============================================================

WITH payment_by_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value,
        MAX(payment_installments) AS max_installments
    FROM order_payments
    GROUP BY order_id
)
SELECT
    CASE
        WHEN max_installments <= 1 THEN '1 installment'
        WHEN max_installments <= 3 THEN '2-3 installments'
        WHEN max_installments <= 6 THEN '4-6 installments'
        WHEN max_installments <= 12 THEN '7-12 installments'
        ELSE '13+ installments'
    END AS installment_group,
    COUNT(*) AS orders,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payment_by_order
GROUP BY installment_group
ORDER BY
    CASE installment_group
        WHEN '1 installment' THEN 1
        WHEN '2-3 installments' THEN 2
        WHEN '4-6 installments' THEN 3
        WHEN '7-12 installments' THEN 4
        WHEN '13+ installments' THEN 5
    END;


-- ============================================================
-- SECTION 19 — REVIEW + DELIVERY PERFORMANCE
-- ============================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
            THEN 'Unknown'
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On/Before Estimate'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(DISTINCT r.review_id) AS reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS low_score_rate_pct
FROM order_reviews r
JOIN orders o
    ON r.order_id = o.order_id
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 20 — CATEGORY + SATISFACTION
-- ============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT r.review_id) AS reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(DISTINCT r.review_id),
        2
    ) AS low_score_rate_pct,
    ROUND(SUM(oi.price), 2) AS product_sales
FROM order_reviews r
JOIN order_items oi
    ON r.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
HAVING COUNT(DISTINCT r.review_id) >= 100
ORDER BY product_sales DESC;


-- ============================================================
-- SECTION 21 — HIGH-VALUE ORDERS WITH LOW SATISFACTION
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_state,
    ROUND(os.total_sales_value, 2) AS total_sales_value,
    r.review_score,
    o.order_status,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_reviews r
    ON o.order_id = r.order_id
JOIN order_sales os
    ON o.order_id = os.order_id
WHERE r.review_score <= 2
ORDER BY os.total_sales_value DESC
LIMIT 100;


-- ============================================================
-- SECTION 22 — FREIGHT BURDEN BY CATEGORY
-- ============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(
        SUM(oi.freight_value) * 100.0
        / NULLIF(SUM(oi.price), 0),
        2
    ) AS freight_to_sales_pct
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
HAVING SUM(oi.price) > 0
ORDER BY freight_to_sales_pct DESC;


-- ============================================================
-- SECTION 23 — CUSTOMER STATE + PAYMENT PREFERENCE
-- ============================================================

WITH state_payment AS (
    SELECT
        c.customer_state,
        p.payment_type,
        COUNT(*) AS payment_records
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_payments p
        ON o.order_id = p.order_id
    GROUP BY c.customer_state, p.payment_type
),
ranked AS (
    SELECT
        customer_state,
        payment_type,
        payment_records,
        ROW_NUMBER() OVER (
            PARTITION BY customer_state
            ORDER BY payment_records DESC, payment_type
        ) AS rn
    FROM state_payment
)
SELECT
    customer_state,
    payment_type AS most_common_payment_type,
    payment_records
FROM ranked
WHERE rn = 1
ORDER BY customer_state;


-- ============================================================
-- SECTION 24 — BUSINESS OPPORTUNITY: HIGH SALES + LOW RATING
-- ============================================================

WITH category_metrics AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,
        SUM(oi.price) AS product_sales,
        AVG(r.review_score) AS avg_review_score,
        COUNT(DISTINCT r.review_id) AS review_count
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    JOIN order_reviews r
        ON oi.order_id = r.order_id
    GROUP BY category
)
SELECT
    category,
    ROUND(product_sales, 2) AS product_sales,
    ROUND(avg_review_score, 2) AS average_review_score,
    review_count
FROM category_metrics
WHERE review_count >= 100
ORDER BY product_sales DESC, avg_review_score ASC;


-- ============================================================
-- SECTION 25 — BUSINESS OPPORTUNITY: HIGH FREIGHT + HIGH SALES
-- ============================================================

WITH category_metrics AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,
        SUM(oi.price) AS product_sales,
        SUM(oi.freight_value) AS freight_value
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY category
)
SELECT
    category,
    ROUND(product_sales, 2) AS product_sales,
    ROUND(freight_value, 2) AS freight_value,
    ROUND(
        freight_value * 100.0 / NULLIF(product_sales, 0),
        2
    ) AS freight_to_sales_pct
FROM category_metrics
WHERE product_sales > 0
ORDER BY product_sales DESC, freight_to_sales_pct DESC;


-- ============================================================
-- SECTION 26 — TOP PRODUCT PERFORMANCE
-- ============================================================

SELECT
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(*) AS item_units,
    COUNT(DISTINCT oi.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY oi.product_id, category
ORDER BY product_sales DESC
LIMIT 100;


-- ============================================================
-- SECTION 27 — TOP SELLERS BY SALES AND CUSTOMER SATISFACTION
-- ============================================================

WITH seller_sales AS (
    SELECT
        seller_id,
        SUM(price) AS product_sales,
        COUNT(DISTINCT order_id) AS orders
    FROM order_items
    GROUP BY seller_id
),
seller_reviews AS (
    SELECT
        oi.seller_id,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    JOIN order_reviews r
        ON oi.order_id = r.order_id
    GROUP BY oi.seller_id
)
SELECT
    ss.seller_id,
    ROUND(ss.product_sales, 2) AS product_sales,
    ss.orders,
    ROUND(sr.avg_review_score, 2) AS average_review_score
FROM seller_sales ss
LEFT JOIN seller_reviews sr
    ON ss.seller_id = sr.seller_id
ORDER BY ss.product_sales DESC
LIMIT 100;


-- ============================================================
-- SECTION 28 — MONTHLY CUSTOMER VALUE TREND
-- ============================================================

SELECT
    STRFTIME('%Y-%m', o.order_purchase_timestamp) AS sales_month,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    ROUND(SUM(oi.price), 2) AS product_sales,
    ROUND(
        SUM(oi.price)
        / NULLIF(COUNT(DISTINCT c.customer_unique_id), 0),
        2
    ) AS sales_per_customer
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY sales_month
ORDER BY sales_month;


-- ============================================================
-- SECTION 29 — DATA-DRIVEN BUSINESS PRIORITY TABLE
-- ============================================================
-- Creates a simple prioritization using observable metrics.
-- This is a prioritization rule, not a machine-learning score.

WITH category_metrics AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,
        SUM(oi.price) AS product_sales,
        SUM(oi.freight_value) AS freight_value,
        AVG(r.review_score) AS avg_review_score,
        COUNT(DISTINCT r.review_id) AS review_count
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    LEFT JOIN order_reviews r
        ON oi.order_id = r.order_id
    GROUP BY category
)
SELECT
    category,
    ROUND(product_sales, 2) AS product_sales,
    ROUND(freight_value, 2) AS freight_value,
    ROUND(avg_review_score, 2) AS average_review_score,
    review_count,
    CASE
        WHEN product_sales >= 100000
         AND avg_review_score < 4
        THEN 'High sales + lower satisfaction'
        WHEN product_sales >= 100000
         AND freight_value * 100.0 / NULLIF(product_sales, 0) >= 20
        THEN 'High sales + high freight burden'
        WHEN product_sales < 100000
         AND avg_review_score < 4
        THEN 'Lower sales + lower satisfaction'
        ELSE 'Monitor'
    END AS business_priority
FROM category_metrics
WHERE review_count >= 100
ORDER BY
    CASE
        WHEN product_sales >= 100000
         AND avg_review_score < 4 THEN 1
        WHEN product_sales >= 100000
         AND freight_value * 100.0 / NULLIF(product_sales, 0) >= 20 THEN 2
        WHEN product_sales < 100000
         AND avg_review_score < 4 THEN 3
        ELSE 4
    END,
    product_sales DESC;


-- ============================================================
-- SECTION 30 — EXECUTIVE KPI SNAPSHOT
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS product_sales,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM customers) AS total_customers,
    (SELECT ROUND(SUM(product_sales), 2) FROM order_sales) AS product_sales,
    (SELECT ROUND(SUM(freight_value), 2) FROM order_sales) AS total_freight,
    (SELECT ROUND(SUM(total_sales_value), 2) FROM order_sales) AS total_sales_value,
    (SELECT ROUND(AVG(total_sales_value), 2) FROM order_sales) AS average_order_value,
    (SELECT ROUND(AVG(review_score), 2) FROM order_reviews) AS average_review_score;


-- ============================================================
-- SECTION 31 — POWER BI READY ADVANCED DATASET
-- ============================================================

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS product_sales,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_sales_value,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
),
order_payment AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value,
        MAX(payment_installments) AS payment_installments
    FROM order_payments
    GROUP BY order_id
),
order_review AS (
    SELECT
        order_id,
        AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    os.product_sales,
    os.freight_value,
    os.total_sales_value,
    os.item_count,
    op.payment_value,
    op.payment_installments,
    orv.review_score,
    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
        THEN 'Unknown'
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
        THEN 'On/Before Estimate'
        ELSE 'Late'
    END AS delivery_performance,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_purchase_timestamp IS NOT NULL
        THEN ROUND(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp),
            2
        )
    END AS delivery_days
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN order_sales os
    ON o.order_id = os.order_id
LEFT JOIN order_payment op
    ON o.order_id = op.order_id
LEFT JOIN order_review orv
    ON o.order_id = orv.order_id;


-- ============================================================
-- END OF 08_advanced_business_analysis.sql
-- ============================================================
