/*
================================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 05_seller_logistics_analysis.sql
PURPOSE : Analyze seller performance, freight, delivery time,
          delivery reliability and logistics by state/category
DATABASE: Olist SQLite Database
================================================================

OBJECTIVE
---------
This script answers:

1. Which sellers generate the most sales?
2. Which sellers process the most orders/items?
3. What is the average order/item value by seller?
4. Which sellers have higher freight values?
5. How long do orders take to reach customers?
6. How does actual delivery compare with estimated delivery?
7. What percentage of delivered orders are late?
8. Which customer states experience more late deliveries?
9. Which categories have longer delivery times?
10. Are longer delivery times associated with lower review scores?
11. Which sellers have the strongest/weakest delivery performance?
12. What logistics KPIs can be used in Power BI?

CORE RELATIONSHIPS
------------------
sellers
    |
    | seller_id
    v
order_items
    |
    | order_id
    v
orders
    |
    | customer_id
    v
customers

products are also connected through order_items.product_id.

IMPORTANT DEFINITIONS
---------------------
Product Sales Value:
    SUM(order_items.price)

Freight Value:
    SUM(order_items.freight_value)

Total Sales Value:
    SUM(order_items.price + order_items.freight_value)

Actual Delivery Days:
    Difference between order purchase date and customer delivery
    date, calculated only where both dates are available.

Delivery Delay Days:
    Actual delivery date - estimated delivery date.

Late Delivery:
    Actual delivery date > estimated delivery date.

NOTE:
    This script does NOT calculate profit. Product cost is not
    available in the dataset.

READ-ONLY
---------
All queries are SELECT statements only.

EXECUTION
---------
Run each numbered section separately in DB Browser for SQLite.
================================================================
*/


/* ==============================================================
   01. SELLER BASE OVERVIEW
   Purpose: Understand the size of the seller population.
   ============================================================== */

SELECT
    COUNT(*) AS seller_records,
    COUNT(DISTINCT seller_id) AS distinct_sellers,
    COUNT(DISTINCT seller_state) AS seller_states
FROM sellers;


/* ==============================================================
   02. SELLERS BY STATE
   Purpose: Understand where sellers are located.
   ============================================================== */

SELECT
    seller_state,
    COUNT(DISTINCT seller_id) AS seller_count
FROM sellers
GROUP BY seller_state
ORDER BY seller_count DESC;


/* ==============================================================
   03. SELLER PERFORMANCE OVERVIEW
   Purpose: Main seller-level sales and volume metrics.
   ============================================================== */

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.product_id) AS distinct_products,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM order_items oi
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY total_sales_value DESC;


/* ==============================================================
   04. TOP 20 SELLERS BY SALES VALUE
   Purpose: Identify highest-value sellers.
   ============================================================== */

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value
FROM order_items oi
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY total_sales_value DESC
LIMIT 20;


/* ==============================================================
   05. TOP 20 SELLERS BY ORDER VOLUME
   Purpose: Identify sellers processing the largest number of
            distinct orders.
   ============================================================== */

SELECT
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value
FROM order_items oi
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY total_orders DESC
LIMIT 20;


/* ==============================================================
   06. SELLER SALES PER ORDER
   Purpose: Compare seller sales value relative to order volume.
   ============================================================== */

SELECT
    oi.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(
        SUM(oi.price) /
        NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS sales_value_per_order
FROM order_items oi
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_state
ORDER BY sales_value_per_order DESC;


/* ==============================================================
   07. SELLER FREIGHT ANALYSIS
   Purpose: Compare freight value across sellers.
   ============================================================== */

SELECT
    oi.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(
        100.0 * SUM(oi.freight_value) /
        NULLIF(SUM(oi.price + oi.freight_value), 0),
        2
    ) AS freight_percentage
FROM order_items oi
INNER JOIN sellers s
    ON oi.seller_id = s.seller_id
GROUP BY
    oi.seller_id,
    s.seller_state
ORDER BY freight_percentage DESC;


/* ==============================================================
   08. SELLER SALES RANKING
   Purpose: Demonstrate RANK() for seller performance.
   ============================================================== */

WITH seller_sales AS (
    SELECT
        oi.seller_id,
        SUM(oi.price + oi.freight_value) AS total_sales_value,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS items_sold
    FROM order_items oi
    GROUP BY oi.seller_id
)

SELECT
    seller_id,
    total_orders,
    items_sold,
    ROUND(total_sales_value, 2) AS total_sales_value,
    RANK() OVER (
        ORDER BY total_sales_value DESC
    ) AS sales_rank
FROM seller_sales
ORDER BY sales_rank
LIMIT 50;


/* ==============================================================
   09. SELLER SALES CONCENTRATION
   Purpose: Understand how much sales value is generated by
            top sellers.
   ============================================================== */

WITH seller_sales AS (
    SELECT
        seller_id,
        SUM(price + freight_value) AS total_sales_value
    FROM order_items
    GROUP BY seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        total_sales_value,
        ROW_NUMBER() OVER (
            ORDER BY total_sales_value DESC
        ) AS sales_rank
    FROM seller_sales
)

SELECT
    CASE
        WHEN sales_rank <= 10 THEN 'Top 10'
        WHEN sales_rank <= 50 THEN '11-50'
        WHEN sales_rank <= 100 THEN '51-100'
        ELSE '101+'
    END AS seller_group,
    COUNT(*) AS seller_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(
        100.0 * SUM(total_sales_value) /
        NULLIF((SELECT SUM(total_sales_value)
                FROM seller_sales), 0),
        2
    ) AS sales_contribution_percentage
FROM ranked_sellers
GROUP BY
    CASE
        WHEN sales_rank <= 10 THEN 'Top 10'
        WHEN sales_rank <= 50 THEN '11-50'
        WHEN sales_rank <= 100 THEN '51-100'
        ELSE '101+'
    END
ORDER BY
    CASE seller_group
        WHEN 'Top 10' THEN 1
        WHEN '11-50' THEN 2
        WHEN '51-100' THEN 3
        ELSE 4
    END;


/* ==============================================================
   10. DELIVERY DATE COVERAGE
   Purpose: Check how many orders have the timestamps required
            for delivery analysis.
   ============================================================== */

SELECT
    COUNT(*) AS total_orders,
    SUM(order_purchase_timestamp IS NOT NULL)
        AS orders_with_purchase_date,
    SUM(order_delivered_customer_date IS NOT NULL)
        AS orders_with_customer_delivery_date,
    SUM(order_estimated_delivery_date IS NOT NULL)
        AS orders_with_estimated_delivery_date,
    SUM(
        order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
    ) AS orders_with_delivery_comparison_dates
FROM orders;


/* ==============================================================
   11. DELIVERY STATUS OVERVIEW
   Purpose: Focus on delivered orders and the availability of
            delivery dates.
   ============================================================== */

SELECT
    order_status,
    COUNT(*) AS order_count,
    SUM(order_delivered_customer_date IS NOT NULL)
        AS orders_with_delivery_date,
    SUM(order_estimated_delivery_date IS NOT NULL)
        AS orders_with_estimated_date
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


/* ==============================================================
   12. ACTUAL DELIVERY TIME DISTRIBUTION
   Purpose: Calculate how many days orders took from purchase to
            customer delivery.

   Only delivered orders with both timestamps are included.
   ============================================================== */

WITH delivered_orders AS (
    SELECT
        order_id,
        datetime(order_purchase_timestamp) AS purchase_date,
        datetime(order_delivered_customer_date) AS delivery_date
    FROM orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            julianday(delivery_date) - julianday(purchase_date)
        ),
        2
    ) AS average_delivery_days,
    ROUND(
        MIN(
            julianday(delivery_date) - julianday(purchase_date)
        ),
        2
    ) AS minimum_delivery_days,
    ROUND(
        MAX(
            julianday(delivery_date) - julianday(purchase_date)
        ),
        2
    ) AS maximum_delivery_days
FROM delivered_orders;


/* ==============================================================
   13. DELIVERY TIME BUCKETS
   Purpose: Group delivered orders into easy-to-understand
            delivery-time ranges.
   ============================================================== */

WITH delivery_times AS (
    SELECT
        order_id,
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_purchase_timestamp)
        ) AS delivery_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    CASE
        WHEN delivery_days < 0 THEN 'Invalid'
        WHEN delivery_days <= 3 THEN '0-3 days'
        WHEN delivery_days <= 7 THEN '4-7 days'
        WHEN delivery_days <= 14 THEN '8-14 days'
        WHEN delivery_days <= 30 THEN '15-30 days'
        ELSE '31+ days'
    END AS delivery_bucket,
    COUNT(*) AS order_count,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days
FROM delivery_times
GROUP BY
    CASE
        WHEN delivery_days < 0 THEN 'Invalid'
        WHEN delivery_days <= 3 THEN '0-3 days'
        WHEN delivery_days <= 7 THEN '4-7 days'
        WHEN delivery_days <= 14 THEN '8-14 days'
        WHEN delivery_days <= 30 THEN '15-30 days'
        ELSE '31+ days'
    END
ORDER BY
    CASE delivery_bucket
        WHEN 'Invalid' THEN 0
        WHEN '0-3 days' THEN 1
        WHEN '4-7 days' THEN 2
        WHEN '8-14 days' THEN 3
        WHEN '15-30 days' THEN 4
        ELSE 5
    END;


/* ==============================================================
   14. ESTIMATED VS ACTUAL DELIVERY
   Purpose: Calculate delivery delay relative to the estimated
            delivery date.

   Positive delay = delivered after estimate.
   Negative delay = delivered before estimate.
   ============================================================== */

WITH delivery_performance AS (
    SELECT
        order_id,
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_estimated_delivery_date)
        ) AS delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS delivered_orders_with_estimate,
    ROUND(AVG(delay_days), 2) AS average_delay_days,
    ROUND(MIN(delay_days), 2) AS earliest_vs_estimate_days,
    ROUND(MAX(delay_days), 2) AS latest_vs_estimate_days,
    SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)
        AS late_orders,
    SUM(CASE WHEN delay_days <= 0 THEN 1 ELSE 0 END)
        AS on_time_or_early_orders,
    ROUND(
        100.0 *
        SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM delivery_performance;


/* ==============================================================
   15. LATE DELIVERY CLASSIFICATION
   Purpose: Produce a reusable order-level delivery classification.
   ============================================================== */

SELECT
    order_id,
    order_status,
    date(order_purchase_timestamp) AS purchase_date,
    date(order_delivered_customer_date) AS actual_delivery_date,
    date(order_estimated_delivery_date) AS estimated_delivery_date,
    ROUND(
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_purchase_timestamp)
        ),
        2
    ) AS actual_delivery_days,
    ROUND(
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_estimated_delivery_date)
        ),
        2
    ) AS delivery_delay_days,
    CASE
        WHEN order_delivered_customer_date IS NULL
          OR order_estimated_delivery_date IS NULL
            THEN 'Not available'
        WHEN datetime(order_delivered_customer_date)
             > datetime(order_estimated_delivery_date)
            THEN 'Late'
        ELSE 'On time / Early'
    END AS delivery_status
FROM orders
WHERE order_status = 'delivered';


/* ==============================================================
   16. DELIVERY PERFORMANCE BY CUSTOMER STATE
   Purpose: Identify geographic differences in delivery
            performance.
   ============================================================== */

WITH delivery_performance AS (
    SELECT
        o.order_id,
        c.customer_state,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    SUM(is_late) AS late_orders,
    ROUND(
        100.0 * SUM(is_late) /
        NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM delivery_performance
GROUP BY customer_state
ORDER BY late_delivery_percentage DESC;


/* ==============================================================
   17. DELIVERY PERFORMANCE BY SELLER
   Purpose: Identify seller-level delivery performance.

   Important:
       An order can contain multiple sellers. Therefore seller
       delivery performance is based on orders containing that
       seller's items.
   ============================================================== */

WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id
    FROM order_items oi
),
seller_delivery AS (
    SELECT
        so.seller_id,
        so.order_id,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM seller_orders so
    INNER JOIN orders o
        ON so.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_id,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    SUM(is_late) AS late_orders,
    ROUND(
        100.0 * SUM(is_late) /
        NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM seller_delivery
GROUP BY seller_id
ORDER BY late_delivery_percentage DESC;


/* ==============================================================
   18. SELLERS WITH SUFFICIENT DELIVERY VOLUME
   Purpose: Avoid over-interpreting sellers with very few orders.

   Threshold:
       At least 20 delivered orders.

   The threshold is transparent and can be adjusted.
   ============================================================== */

WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id
    FROM order_items oi
),
seller_delivery AS (
    SELECT
        so.seller_id,
        so.order_id,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM seller_orders so
    INNER JOIN orders o
        ON so.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_id,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    SUM(is_late) AS late_orders,
    ROUND(
        100.0 * SUM(is_late) /
        NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM seller_delivery
GROUP BY seller_id
HAVING COUNT(*) >= 20
ORDER BY late_delivery_percentage DESC;


/* ==============================================================
   19. CATEGORY DELIVERY PERFORMANCE
   Purpose: Compare delivery performance across product
            categories.
   ============================================================== */

WITH category_delivery AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    category_name,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    SUM(is_late) AS late_orders,
    ROUND(
        100.0 * SUM(is_late) /
        NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM category_delivery
GROUP BY category_name
ORDER BY late_delivery_percentage DESC;


/* ==============================================================
   20. SELLER SALES + DELIVERY PERFORMANCE
   Purpose: Combine seller commercial performance with logistics
            performance for a more complete seller view.
   ============================================================== */

WITH seller_sales AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS product_sales_value,
        SUM(oi.freight_value) AS freight_value
    FROM order_items oi
    GROUP BY oi.seller_id
),
seller_orders AS (
    SELECT DISTINCT
        seller_id,
        order_id
    FROM order_items
),
seller_delivery AS (
    SELECT
        so.seller_id,
        so.order_id,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM seller_orders so
    INNER JOIN orders o
        ON so.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
seller_delivery_summary AS (
    SELECT
        seller_id,
        COUNT(*) AS delivered_orders,
        AVG(delivery_days) AS average_delivery_days,
        SUM(is_late) AS late_orders,
        100.0 * SUM(is_late) / NULLIF(COUNT(*), 0)
            AS late_delivery_percentage
    FROM seller_delivery
    GROUP BY seller_id
)

SELECT
    ss.seller_id,
    s.seller_city,
    s.seller_state,
    ss.total_orders,
    ss.items_sold,
    ROUND(ss.product_sales_value, 2) AS product_sales_value,
    ROUND(ss.freight_value, 2) AS freight_value,
    sds.delivered_orders,
    ROUND(sds.average_delivery_days, 2)
        AS average_delivery_days,
    sds.late_orders,
    ROUND(sds.late_delivery_percentage, 2)
        AS late_delivery_percentage
FROM seller_sales ss
INNER JOIN sellers s
    ON ss.seller_id = s.seller_id
LEFT JOIN seller_delivery_summary sds
    ON ss.seller_id = sds.seller_id
ORDER BY ss.product_sales_value DESC;


/* ==============================================================
   21. DELIVERY PERFORMANCE BY MONTH
   Purpose: Identify changes in logistics performance over time.
   ============================================================== */

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            julianday(
                datetime(o.order_delivered_customer_date)
            ) -
            julianday(
                datetime(o.order_purchase_timestamp)
            )
        ),
        2
    ) AS average_delivery_days,
    SUM(
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN datetime(o.order_delivered_customer_date)
                     > datetime(o.order_estimated_delivery_date)
                    THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM orders o
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
ORDER BY order_month;


/* ==============================================================
   22. SHIPPING LIMIT VS ACTUAL CARRIER HANDOFF
   Purpose: Compare the seller's shipping-limit timestamp with
            the actual carrier handoff date where available.

   This is a diagnostic measure. A positive value means the
   carrier handoff occurred after the stated shipping limit.
   ============================================================== */

SELECT
    COUNT(*) AS orders_with_both_dates,
    ROUND(
        AVG(
            julianday(
                datetime(o.order_delivered_carrier_date)
            ) -
            julianday(
                datetime(oi.shipping_limit_date)
            )
        ),
        2
    ) AS average_handoff_vs_shipping_limit_days,
    SUM(
        CASE
            WHEN datetime(o.order_delivered_carrier_date)
                 > datetime(oi.shipping_limit_date)
                THEN 1
            ELSE 0
        END
    ) AS handoffs_after_shipping_limit
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_delivered_carrier_date IS NOT NULL
  AND oi.shipping_limit_date IS NOT NULL;


/* ==============================================================
   23. CARRIER HANDOFF TIME
   Purpose: Measure the time from purchase to carrier handoff.
   ============================================================== */

SELECT
    ROUND(
        AVG(
            julianday(
                datetime(o.order_delivered_carrier_date)
            ) -
            julianday(
                datetime(o.order_purchase_timestamp)
            )
        ),
        2
    ) AS average_purchase_to_carrier_days,
    ROUND(
        MIN(
            julianday(
                datetime(o.order_delivered_carrier_date)
            ) -
            julianday(
                datetime(o.order_purchase_timestamp)
            )
        ),
        2
    ) AS minimum_purchase_to_carrier_days,
    ROUND(
        MAX(
            julianday(
                datetime(o.order_delivered_carrier_date)
            ) -
            julianday(
                datetime(o.order_purchase_timestamp)
            )
        ),
        2
    ) AS maximum_purchase_to_carrier_days
FROM orders o
WHERE o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp IS NOT NULL;


/* ==============================================================
   24. CUSTOMER STATE + SELLER STATE
   Purpose: Explore origin/destination geography.

   This can help identify whether certain seller/customer state
   combinations have different delivery performance.
   ============================================================== */

WITH state_routes AS (
    SELECT DISTINCT
        oi.order_id,
        s.seller_state,
        c.customer_state,
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ) AS delivery_days,
        CASE
            WHEN datetime(o.order_delivered_customer_date)
                 > datetime(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS is_late
    FROM order_items oi
    INNER JOIN sellers s
        ON oi.seller_id = s.seller_id
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_state,
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS average_delivery_days,
    ROUND(
        100.0 * SUM(is_late) /
        NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM state_routes
GROUP BY seller_state, customer_state
HAVING COUNT(*) >= 20
ORDER BY late_delivery_percentage DESC;


/* ==============================================================
   25. DELIVERY PERFORMANCE DATASET FOR POWER BI
   Purpose: Produce a clean order-level logistics dataset that
            can later be imported into Power BI.

   This is intentionally kept at order level to avoid unnecessary
   duplication from order_items.
   ============================================================== */

SELECT
    o.order_id,
    c.customer_state,
    date(o.order_purchase_timestamp) AS purchase_date,
    date(o.order_delivered_carrier_date) AS carrier_date,
    date(o.order_delivered_customer_date) AS actual_delivery_date,
    date(o.order_estimated_delivery_date) AS estimated_delivery_date,

    ROUND(
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_purchase_timestamp)
        ),
        2
    ) AS actual_delivery_days,

    ROUND(
        julianday(
            datetime(o.order_delivered_customer_date)
        ) -
        julianday(
            datetime(o.order_estimated_delivery_date)
        ),
        2
    ) AS delivery_delay_days,

    CASE
        WHEN datetime(o.order_delivered_customer_date)
             > datetime(o.order_estimated_delivery_date)
            THEN 'Late'
        ELSE 'On time / Early'
    END AS delivery_status

FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;


/* ==============================================================
   26. FINAL LOGISTICS KPI SNAPSHOT
   Purpose: Compact summary for project documentation and the
            future Power BI Logistics page.
   ============================================================== */

WITH delivery_performance AS (
    SELECT
        order_id,
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_purchase_timestamp)
        ) AS delivery_days,
        julianday(
            datetime(order_delivered_customer_date)
        ) -
        julianday(
            datetime(order_estimated_delivery_date)
        ) AS delay_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS delivered_orders_analyzed,

    ROUND(AVG(delivery_days), 2)
        AS average_delivery_days,

    ROUND(AVG(delay_days), 2)
        AS average_delay_vs_estimate_days,

    SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)
        AS late_orders,

    SUM(CASE WHEN delay_days <= 0 THEN 1 ELSE 0 END)
        AS on_time_or_early_orders,

    ROUND(
        100.0 *
        SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_percentage
FROM delivery_performance;


/*
================================================================
END OF 05_SELLER_LOGISTICS_ANALYSIS.SQL

NEXT FILE:
06_payment_analysis.sql

The next stage will analyze:
- Payment methods
- Payment value
- Installments
- Orders per payment method
- Payment method share
- Customer payment behavior
- State-level payment patterns
================================================================
*/
