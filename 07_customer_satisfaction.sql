-- ============================================================
-- 07_customer_satisfaction.sql
-- Brazilian E-Commerce Customer & Review Satisfaction Analysis
-- Dataset: Olist Brazilian E-Commerce
-- SQL Engine: SQLite
-- ============================================================

-- PURPOSE
-- Analyze customer satisfaction using order reviews, delivery performance,
-- order value, review scores, review comments, and customer geography.
--
-- IMPORTANT:
-- 1. Review scores are customer-provided ratings from 1 to 5.
-- 2. This file does NOT claim that delivery delays cause low reviews;
--    it only compares the two measures.
-- 3. customer_unique_id is used when customer-level behavior is required.
-- 4. Review text length is used only as an observable review characteristic.
-- ============================================================


-- ============================================================
-- SECTION 01 — REVIEW DATA OVERVIEW
-- ============================================================

SELECT
    COUNT(*) AS total_reviews
FROM order_reviews;


-- ============================================================
-- SECTION 02 — REVIEW SCORE DISTRIBUTION
-- ============================================================

SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_reviews),
        2
    ) AS review_share_pct
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- ============================================================
-- SECTION 03 — AVERAGE REVIEW SCORE
-- ============================================================

SELECT
    ROUND(AVG(review_score), 2) AS average_review_score,
    MIN(review_score) AS minimum_score,
    MAX(review_score) AS maximum_score
FROM order_reviews;


-- ============================================================
-- SECTION 04 — LOW / MEDIUM / HIGH SCORE GROUPS
-- ============================================================

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low (1-2)'
        WHEN review_score = 3 THEN 'Medium (3)'
        WHEN review_score >= 4 THEN 'High (4-5)'
    END AS satisfaction_group,
    COUNT(*) AS review_count,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_reviews),
        2
    ) AS review_share_pct
FROM order_reviews
GROUP BY satisfaction_group
ORDER BY
    CASE satisfaction_group
        WHEN 'Low (1-2)' THEN 1
        WHEN 'Medium (3)' THEN 2
        WHEN 'High (4-5)' THEN 3
    END;


-- ============================================================
-- SECTION 05 — ONE-STAR VS FIVE-STAR REVIEWS
-- ============================================================

SELECT
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS one_star_reviews,
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS five_star_reviews,
    ROUND(
        SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS one_star_share_pct,
    ROUND(
        SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS five_star_share_pct
FROM order_reviews;


-- ============================================================
-- SECTION 06 — REVIEW COMMENT COVERAGE
-- ============================================================

SELECT
    COUNT(*) AS total_reviews,
    SUM(
        CASE
            WHEN review_comment_message IS NOT NULL
             AND TRIM(review_comment_message) <> ''
            THEN 1 ELSE 0
        END
    ) AS reviews_with_comments,
    SUM(
        CASE
            WHEN review_comment_message IS NULL
              OR TRIM(review_comment_message) = ''
            THEN 1 ELSE 0
        END
    ) AS reviews_without_comments,
    ROUND(
        SUM(
            CASE
                WHEN review_comment_message IS NOT NULL
                 AND TRIM(review_comment_message) <> ''
                THEN 1 ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS comment_coverage_pct
FROM order_reviews;


-- ============================================================
-- SECTION 07 — REVIEW COMMENT LENGTH
-- ============================================================

SELECT
    ROUND(AVG(LENGTH(review_comment_message)), 2) AS avg_comment_length,
    MIN(LENGTH(review_comment_message)) AS min_comment_length,
    MAX(LENGTH(review_comment_message)) AS max_comment_length
FROM order_reviews
WHERE review_comment_message IS NOT NULL
  AND TRIM(review_comment_message) <> '';


-- ============================================================
-- SECTION 08 — COMMENT LENGTH BY REVIEW SCORE
-- ============================================================

SELECT
    review_score,
    COUNT(*) AS reviews_with_comments,
    ROUND(AVG(LENGTH(review_comment_message)), 2) AS avg_comment_length
FROM order_reviews
WHERE review_comment_message IS NOT NULL
  AND TRIM(review_comment_message) <> ''
GROUP BY review_score
ORDER BY review_score;


-- ============================================================
-- SECTION 09 — REVIEW CREATION DATE RANGE
-- ============================================================

SELECT
    MIN(review_creation_date) AS first_review_date,
    MAX(review_creation_date) AS last_review_date
FROM order_reviews;


-- ============================================================
-- SECTION 10 — REVIEWS BY MONTH
-- ============================================================

SELECT
    STRFTIME('%Y-%m', review_creation_date) AS review_month,
    COUNT(*) AS review_count,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM order_reviews
GROUP BY STRFTIME('%Y-%m', review_creation_date)
ORDER BY review_month;


-- ============================================================
-- SECTION 11 — MONTHLY REVIEW SCORE DISTRIBUTION
-- ============================================================

SELECT
    STRFTIME('%Y-%m', review_creation_date) AS review_month,
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS score_1,
    SUM(CASE WHEN review_score = 2 THEN 1 ELSE 0 END) AS score_2,
    SUM(CASE WHEN review_score = 3 THEN 1 ELSE 0 END) AS score_3,
    SUM(CASE WHEN review_score = 4 THEN 1 ELSE 0 END) AS score_4,
    SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) AS score_5
FROM order_reviews
GROUP BY STRFTIME('%Y-%m', review_creation_date)
ORDER BY review_month;


-- ============================================================
-- SECTION 12 — REVIEW SCORE BY ORDER STATUS
-- ============================================================

SELECT
    o.order_status,
    COUNT(r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
GROUP BY o.order_status
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 13 — REVIEW SCORE BY PAYMENT TYPE
-- ============================================================

SELECT
    p.payment_type,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM order_reviews r
JOIN orders o
    ON r.order_id = o.order_id
JOIN order_payments p
    ON o.order_id = p.order_id
GROUP BY p.payment_type
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 14 — REVIEW SCORE BY CUSTOMER STATE
-- ============================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM order_reviews r
JOIN orders o
    ON r.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 15 — LOW-SATISFACTION RATE BY CUSTOMER STATE
-- ============================================================

SELECT
    c.customer_state,
    COUNT(DISTINCT r.review_id) AS review_count,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_score_reviews,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(DISTINCT r.review_id),
        2
    ) AS low_score_rate_pct
FROM order_reviews r
JOIN orders o
    ON r.order_id = o.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT r.review_id) >= 100
ORDER BY low_score_rate_pct DESC;


-- ============================================================
-- SECTION 16 — REVIEW SCORE BY PRODUCT CATEGORY
-- ============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM order_reviews r
JOIN order_items oi
    ON r.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY category
HAVING COUNT(DISTINCT r.review_id) >= 100
ORDER BY average_review_score DESC;

-- ============================================================
-- SECTION 17 — LOW-SATISFACTION RATE BY PRODUCT CATEGORY
-- ============================================================

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,

    COUNT(DISTINCT r.review_id) AS review_count,

    SUM(
        CASE
            WHEN r.review_score <= 2 THEN 1
            ELSE 0
        END
    ) AS low_score_reviews,

    ROUND(
        SUM(
            CASE
                WHEN r.review_score <= 2 THEN 1
                ELSE 0
            END
        ) * 100.0
        / COUNT(DISTINCT r.review_id),
        2
    ) AS low_score_rate_pct

FROM order_reviews r

JOIN order_items oi
    ON r.order_id = oi.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name

GROUP BY category

HAVING COUNT(DISTINCT r.review_id) >= 100

ORDER BY low_score_rate_pct DESC;
-- ============================================================
-- SECTION 18 — ORDER-LEVEL REVIEW + DELIVERY DATASET
-- ============================================================
-- One row per reviewed order. Useful for Power BI and later analysis.

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    r.review_id,
    r.review_score,
    r.review_creation_date,
    CASE
        WHEN r.review_comment_message IS NOT NULL
         AND TRIM(r.review_comment_message) <> ''
        THEN 1 ELSE 0
    END AS has_review_comment,
    LENGTH(r.review_comment_message) AS review_comment_length
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
JOIN customers c
    ON o.customer_id = c.customer_id;


-- ============================================================
-- SECTION 19 — DELIVERY TIME VS REVIEW SCORE
-- ============================================================
-- Delivery time is measured from purchase to actual customer delivery.
-- Only delivered orders with both timestamps are included.

SELECT
    r.review_score,
    COUNT(*) AS reviewed_delivered_orders,
    ROUND(
        AVG(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp)
        ),
        2
    ) AS avg_delivery_days
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;


-- ============================================================
-- SECTION 20 — DELIVERY TIME BUCKET VS REVIEW SCORE
-- ============================================================

SELECT
    CASE
        WHEN (
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp)
        ) < 7 THEN '< 7 days'
        WHEN (
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp)
        ) < 15 THEN '7-14 days'
        WHEN (
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp)
        ) < 30 THEN '15-29 days'
        ELSE '30+ days'
    END AS delivery_bucket,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS low_score_rate_pct
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL
GROUP BY delivery_bucket
ORDER BY
    CASE delivery_bucket
        WHEN '< 7 days' THEN 1
        WHEN '7-14 days' THEN 2
        WHEN '15-29 days' THEN 3
        WHEN '30+ days' THEN 4
    END;


-- ============================================================
-- SECTION 21 — ESTIMATED DELIVERY VS ACTUAL DELIVERY
-- ============================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On or Before Estimate'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'Unknown'
    END AS delivery_performance,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS low_score_rate_pct
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 22 — DAYS EARLY / LATE VS REVIEW SCORE
-- ============================================================

SELECT
    r.review_score,
    COUNT(*) AS reviewed_orders,
    ROUND(
        AVG(
            JULIANDAY(o.order_estimated_delivery_date)
            - JULIANDAY(o.order_delivered_customer_date)
        ),
        2
    ) AS avg_days_before_estimate
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;


-- ============================================================
-- SECTION 23 — REVIEW SCORE VS ORDER VALUE
-- ============================================================
-- Product sales value = SUM(order_items.price) for the order.

WITH order_value AS (
    SELECT
        order_id,
        SUM(price) AS product_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    r.review_score,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(v.product_sales_value), 2) AS avg_product_sales_value
FROM order_reviews r
JOIN order_value v
    ON r.order_id = v.order_id
GROUP BY r.review_score
ORDER BY r.review_score;


-- ============================================================
-- SECTION 24 — REVIEW SCORE VS ORDER VALUE BUCKET
-- ============================================================

WITH order_value AS (
    SELECT
        order_id,
        SUM(price) AS product_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    CASE
        WHEN v.product_sales_value < 50 THEN '< R$50'
        WHEN v.product_sales_value < 100 THEN 'R$50-R$99'
        WHEN v.product_sales_value < 250 THEN 'R$100-R$249'
        WHEN v.product_sales_value < 500 THEN 'R$250-R$499'
        ELSE 'R$500+'
    END AS order_value_bucket,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS low_score_rate_pct
FROM order_reviews r
JOIN order_value v
    ON r.order_id = v.order_id
GROUP BY order_value_bucket
ORDER BY
    CASE order_value_bucket
        WHEN '< R$50' THEN 1
        WHEN 'R$50-R$99' THEN 2
        WHEN 'R$100-R$249' THEN 3
        WHEN 'R$250-R$499' THEN 4
        WHEN 'R$500+' THEN 5
    END;


-- ============================================================
-- SECTION 25 — REVIEWED ORDERS WITH LATE DELIVERY
-- ============================================================

SELECT
    o.order_id,
    c.customer_state,
    r.review_score,
    ROUND(
        JULIANDAY(o.order_delivered_customer_date)
        - JULIANDAY(o.order_estimated_delivery_date),
        2
    ) AS days_late
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date > o.order_estimated_delivery_date
ORDER BY days_late DESC
LIMIT 100;


-- ============================================================
-- SECTION 26 — LOW-SCORE ORDERS WITH DELIVERY DETAILS
-- ============================================================

SELECT
    o.order_id,
    c.customer_state,
    r.review_score,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ROUND(
        JULIANDAY(o.order_delivered_customer_date)
        - JULIANDAY(o.order_purchase_timestamp),
        2
    ) AS delivery_days,
    ROUND(
        JULIANDAY(o.order_delivered_customer_date)
        - JULIANDAY(o.order_estimated_delivery_date),
        2
    ) AS days_vs_estimate,
    r.review_comment_message
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE r.review_score <= 2
ORDER BY o.order_purchase_timestamp DESC
LIMIT 100;


-- ============================================================
-- SECTION 27 — CUSTOMER-LEVEL SATISFACTION
-- ============================================================
-- Uses customer_unique_id so repeat purchases are grouped to the
-- same underlying customer.

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS orders_reviewed,
    COUNT(DISTINCT r.review_id) AS reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_score_reviews
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_reviews r
    ON o.order_id = r.order_id
GROUP BY c.customer_unique_id
ORDER BY average_review_score ASC, orders_reviewed DESC
LIMIT 100;


-- ============================================================
-- SECTION 28 — REPEAT VS ONE-TIME CUSTOMER SATISFACTION
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN co.order_count = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    COUNT(DISTINCT r.review_id) AS reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(DISTINCT r.review_id),
        2
    ) AS low_score_rate_pct
FROM customer_orders co
JOIN customers c
    ON co.customer_unique_id = c.customer_unique_id
JOIN orders o
    ON c.customer_id = o.customer_id
JOIN order_reviews r
    ON o.order_id = r.order_id
GROUP BY customer_type
ORDER BY average_review_score DESC;


-- ============================================================
-- SECTION 29 — STATE-LEVEL REVIEW RANKING
-- ============================================================

WITH state_reviews AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT r.review_id) AS review_count,
        AVG(r.review_score) AS avg_score
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_reviews r
        ON o.order_id = r.order_id
    GROUP BY c.customer_state
    HAVING COUNT(DISTINCT r.review_id) >= 100
)
SELECT
    customer_state,
    review_count,
    ROUND(avg_score, 2) AS average_review_score,
    RANK() OVER (ORDER BY avg_score DESC) AS satisfaction_rank
FROM state_reviews
ORDER BY satisfaction_rank;

-- ============================================================
-- SECTION 30 — CATEGORY-LEVEL REVIEW RANKING
-- ============================================================

WITH category_reviews AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name
        ) AS category,

        COUNT(DISTINCT r.review_id) AS review_count,

        AVG(r.review_score) AS avg_score

    FROM order_reviews r

    JOIN order_items oi
        ON r.order_id = oi.order_id

    JOIN products p
        ON oi.product_id = p.product_id

    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name

    GROUP BY category

    HAVING COUNT(DISTINCT r.review_id) >= 100
)

SELECT
    category,
    review_count,
    ROUND(avg_score, 2) AS average_review_score,
    RANK() OVER (ORDER BY avg_score DESC) AS satisfaction_rank
FROM category_reviews
ORDER BY satisfaction_rank;


-- ============================================================
-- SECTION 31 — REVIEW SCORE + DELIVERY PERFORMANCE MATRIX
-- ============================================================

SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN 'On/Before Estimate'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late'
        ELSE 'Unknown'
    END AS delivery_performance,
    r.review_score,
    COUNT(*) AS reviewed_orders
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance, r.review_score
ORDER BY delivery_performance, r.review_score;


-- ============================================================
-- SECTION 32 — SATISFACTION KPI SNAPSHOT
-- ============================================================

SELECT
    COUNT(DISTINCT r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS average_review_score,
    ROUND(
        SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS high_score_rate_pct,
    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*),
        2
    ) AS low_score_rate_pct,
    SUM(
        CASE
            WHEN r.review_comment_message IS NOT NULL
             AND TRIM(r.review_comment_message) <> ''
            THEN 1 ELSE 0
        END
    ) AS reviews_with_comments
FROM order_reviews r;


-- ============================================================
-- SECTION 33 — POWER BI READY SATISFACTION DATASET
-- ============================================================
-- Recommended base query for importing customer satisfaction data
-- into Power BI.

WITH order_value AS (
    SELECT
        order_id,
        SUM(price) AS product_sales_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    r.review_id,
    r.review_score,
    r.review_creation_date,
    CASE
        WHEN r.review_score <= 2 THEN 'Low'
        WHEN r.review_score = 3 THEN 'Medium'
        ELSE 'High'
    END AS satisfaction_group,
    CASE
        WHEN r.review_comment_message IS NOT NULL
         AND TRIM(r.review_comment_message) <> ''
        THEN 'With Comment'
        ELSE 'No Comment'
    END AS comment_status,
    LENGTH(r.review_comment_message) AS review_comment_length,
    v.product_sales_value,
    v.freight_value,
    v.total_sales_value,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_purchase_timestamp IS NOT NULL
        THEN ROUND(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_purchase_timestamp),
            2
        )
    END AS delivery_days,
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
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN ROUND(
            JULIANDAY(o.order_delivered_customer_date)
            - JULIANDAY(o.order_estimated_delivery_date),
            2
        )
    END AS days_vs_estimate
FROM orders o
JOIN order_reviews r
    ON o.order_id = r.order_id
JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN order_value v
    ON o.order_id = v.order_id;


-- ============================================================
-- END OF 07_customer_satisfaction.sql
-- ============================================================
