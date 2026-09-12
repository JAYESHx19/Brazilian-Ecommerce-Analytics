/*
================================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 03_customer_analysis.sql
PURPOSE : Analyze customer geography, behavior, spending and
          repeat-purchase patterns
DATABASE: Olist SQLite Database
================================================================

OBJECTIVE
---------
This script answers the following customer/business questions:

1. How many customers placed orders?
2. Where are customers located?
3. How many orders and how much sales value come from each state?
4. How frequently do customers purchase?
5. What proportion of customers are one-time vs repeat buyers?
6. Who are the highest-value customers?
7. How much revenue comes from repeat customers?
8. What is the average spend per customer?
9. How does customer order behavior vary by state?
10. Can customers be grouped into useful spending segments?

IMPORTANT CUSTOMER DEFINITIONS
------------------------------
customer_id:
    The identifier used to connect a customer record to an order.

customer_unique_id:
    The identifier used to represent a unique customer identity
    across customer records.

For customer-level behavior and repeat-purchase analysis, this
script uses customer_unique_id.

IMPORTANT SALES DEFINITION
--------------------------
Customer sales value = SUM(order_items.price + freight_value)

We keep product value and freight value separate where useful.

NOTE:
    The dataset does not contain product cost, so no profit metric
    is calculated.

READ-ONLY
---------
This script contains SELECT statements only.

EXECUTION
---------
Run each numbered section separately in DB Browser for SQLite.
================================================================
*/


/* ==============================================================
   01. CUSTOMER BASE OVERVIEW
   Purpose: Understand the size of the customer population.
   ============================================================== */

SELECT
    COUNT(*) AS customer_records,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS unique_customer_identities
FROM customers;


/* ==============================================================
   02. CUSTOMERS WITH ORDERS
   Purpose: Compare registered customer records with customers
            who actually appear in the order history.
   ============================================================== */

SELECT
    COUNT(DISTINCT o.customer_id) AS customer_records_with_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers_with_orders
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id;


/* ==============================================================
   03. CUSTOMER COVERAGE
   Purpose: Identify customer records that have no associated
            order.
   ============================================================== */

SELECT
    COUNT(*) AS customers_without_orders
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;


/* ==============================================================
   04. CUSTOMERS BY STATE
   Purpose: Geographic distribution of the customer base.
   ============================================================== */

SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(DISTINCT customer_id) AS customer_records
FROM customers
GROUP BY customer_state
ORDER BY unique_customers DESC;


/* ==============================================================
   05. ORDERS BY CUSTOMER STATE
   Purpose: Compare order volume across customer states.
   ============================================================== */

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY total_orders DESC;


/* ==============================================================
   06. SALES VALUE BY CUSTOMER STATE
   Purpose: Identify the states generating the highest sales value.
   ============================================================== */

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY total_sales_value DESC;


/* ==============================================================
   07. STATE-LEVEL CUSTOMER SPENDING
   Purpose: Calculate average sales value per unique customer
            within each state.

   This is calculated from customer-level totals first to avoid
   giving extra weight to customers with multiple order items.
   ============================================================== */

WITH customer_sales AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        SUM(oi.price + oi.freight_value) AS customer_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
)

SELECT
    customer_state,
    COUNT(*) AS unique_customers,
    ROUND(SUM(customer_sales_value), 2) AS total_sales_value,
    ROUND(AVG(customer_sales_value), 2) AS average_customer_spend,
    ROUND(MIN(customer_sales_value), 2) AS minimum_customer_spend,
    ROUND(MAX(customer_sales_value), 2) AS maximum_customer_spend
FROM customer_sales
GROUP BY customer_state
ORDER BY average_customer_spend DESC;


/* ==============================================================
   08. CUSTOMER ORDER FREQUENCY
   Purpose: Determine how many orders each unique customer placed.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    total_orders,
    COUNT(*) AS customer_count
FROM customer_orders
GROUP BY total_orders
ORDER BY total_orders;


/* ==============================================================
   09. ONE-TIME VS REPEAT CUSTOMERS
   Purpose: Classify customers based on purchase frequency.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) /
        NULLIF((SELECT COUNT(*) FROM customer_orders), 0),
        2
    ) AS customer_percentage
FROM customer_orders
GROUP BY
    CASE
        WHEN total_orders = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END
ORDER BY customer_count DESC;


/* ==============================================================
   10. REPEAT-PURCHASE SUMMARY
   Purpose: Provide a compact repeat-customer KPI view.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_customers_with_orders,
    SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END)
        AS one_time_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        AS repeat_customers,
    ROUND(
        100.0 *
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_percentage
FROM customer_orders;


/* ==============================================================
   11. CUSTOMER-LEVEL SPENDING
   Purpose: Create a reusable customer-level analytical dataset
            containing order count and sales value.
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT oi.order_id || '-' || oi.order_item_id)
            AS total_items,
        SUM(oi.price) AS product_sales_value,
        SUM(oi.freight_value) AS freight_value,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    total_items,
    ROUND(product_sales_value, 2) AS product_sales_value,
    ROUND(freight_value, 2) AS freight_value,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(total_sales_value / NULLIF(total_orders, 0), 2)
        AS average_order_value
FROM customer_metrics
ORDER BY total_sales_value DESC;


/* ==============================================================
   12. TOP 20 CUSTOMERS BY SALES VALUE
   Purpose: Identify the highest-value customers.
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(
        total_sales_value / NULLIF(total_orders, 0),
        2
    ) AS average_order_value
FROM customer_metrics
ORDER BY total_sales_value DESC
LIMIT 20;


/* ==============================================================
   13. TOP CUSTOMERS BY ORDER FREQUENCY
   Purpose: Identify customers with the highest number of orders.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(
        total_sales_value / NULLIF(total_orders, 0),
        2
    ) AS average_order_value
FROM customer_orders
ORDER BY total_orders DESC, total_sales_value DESC
LIMIT 20;


/* ==============================================================
   14. REPEAT VS ONE-TIME CUSTOMER SALES
   Purpose: Compare sales contribution from repeat and one-time
            customers.
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(AVG(total_sales_value), 2) AS average_customer_spend,
    ROUND(
        100.0 * SUM(total_sales_value)
        / NULLIF((SELECT SUM(total_sales_value)
                  FROM customer_metrics), 0),
        2
    ) AS sales_contribution_percentage
FROM customer_metrics
GROUP BY
    CASE
        WHEN total_orders = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END
ORDER BY total_sales_value DESC;


/* ==============================================================
   15. CUSTOMER SPENDING SEGMENTATION
   Purpose: Create simple business-friendly spending segments.

   Thresholds are intentionally transparent and can be changed
   after inspecting the distribution.

       < 100      = Low Value
       100-499.99 = Medium Value
       500-999.99 = High Value
       1000+      = Very High Value
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),
segmented_customers AS (
    SELECT
        customer_unique_id,
        total_sales_value,
        CASE
            WHEN total_sales_value < 100 THEN 'Low Value'
            WHEN total_sales_value < 500 THEN 'Medium Value'
            WHEN total_sales_value < 1000 THEN 'High Value'
            ELSE 'Very High Value'
        END AS customer_segment
    FROM customer_metrics
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(AVG(total_sales_value), 2) AS average_customer_spend,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF((SELECT COUNT(*) FROM segmented_customers), 0),
        2
    ) AS customer_percentage
FROM segmented_customers
GROUP BY customer_segment
ORDER BY
    CASE customer_segment
        WHEN 'Low Value' THEN 1
        WHEN 'Medium Value' THEN 2
        WHEN 'High Value' THEN 3
        WHEN 'Very High Value' THEN 4
    END;


/* ==============================================================
   16. CUSTOMER SEGMENT SALES CONTRIBUTION
   Purpose: Show which spending segments contribute the most
            sales value.
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),
segmented_customers AS (
    SELECT
        customer_unique_id,
        total_sales_value,
        CASE
            WHEN total_sales_value < 100 THEN 'Low Value'
            WHEN total_sales_value < 500 THEN 'Medium Value'
            WHEN total_sales_value < 1000 THEN 'High Value'
            ELSE 'Very High Value'
        END AS customer_segment
    FROM customer_metrics
)

SELECT
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(
        100.0 * SUM(total_sales_value)
        / NULLIF((SELECT SUM(total_sales_value)
                  FROM segmented_customers), 0),
        2
    ) AS sales_contribution_percentage
FROM segmented_customers
GROUP BY customer_segment
ORDER BY total_sales_value DESC;


/* ==============================================================
   17. CUSTOMER PURCHASE TIMING
   Purpose: Find each customer's first and latest purchase date.
   ============================================================== */

SELECT
    c.customer_unique_id,
    MIN(datetime(o.order_purchase_timestamp)) AS first_purchase_date,
    MAX(datetime(o.order_purchase_timestamp)) AS latest_purchase_date,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY first_purchase_date;


/* ==============================================================
   18. CUSTOMER LIFESPAN / PURCHASE WINDOW
   Purpose: Measure the number of days between a customer's first
            and latest purchase.

   A value of 0 means the customer has only one purchase date or
   multiple orders on the same date.
   ============================================================== */

WITH customer_dates AS (
    SELECT
        c.customer_unique_id,
        MIN(datetime(o.order_purchase_timestamp)) AS first_purchase,
        MAX(datetime(o.order_purchase_timestamp)) AS latest_purchase,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    date(first_purchase) AS first_purchase_date,
    date(latest_purchase) AS latest_purchase_date,
    CAST(
        julianday(latest_purchase) - julianday(first_purchase)
        AS INTEGER
    ) AS purchase_window_days
FROM customer_dates
ORDER BY purchase_window_days DESC;


/* ==============================================================
   19. REPEAT CUSTOMERS WITH PURCHASE WINDOW
   Purpose: Focus specifically on customers who purchased more
            than once and measure the gap between first and latest
            purchase.
   ============================================================== */

WITH customer_dates AS (
    SELECT
        c.customer_unique_id,
        MIN(datetime(o.order_purchase_timestamp)) AS first_purchase,
        MAX(datetime(o.order_purchase_timestamp)) AS latest_purchase,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    date(first_purchase) AS first_purchase_date,
    date(latest_purchase) AS latest_purchase_date,
    CAST(
        julianday(latest_purchase) - julianday(first_purchase)
        AS INTEGER
    ) AS purchase_window_days
FROM customer_dates
WHERE total_orders > 1
ORDER BY purchase_window_days DESC;


/* ==============================================================
   20. CUSTOMER STATE + REPEAT BEHAVIOR
   Purpose: Determine whether repeat-purchase behavior differs
            across states.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
)

SELECT
    customer_state,
    COUNT(*) AS customers,
    SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END)
        AS one_time_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        AS repeat_customers,
    ROUND(
        100.0 *
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_percentage,
    ROUND(AVG(total_orders), 2) AS average_orders_per_customer
FROM customer_orders
GROUP BY customer_state
ORDER BY repeat_customer_percentage DESC;


/* ==============================================================
   21. CUSTOMER STATE + AVERAGE ORDER VALUE
   Purpose: Compare customer spending/order behavior across states.
   ============================================================== */

WITH customer_order_values AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        o.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state,
        o.order_id
)

SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(order_value), 2) AS average_order_value,
    ROUND(SUM(order_value), 2) AS total_sales_value
FROM customer_order_values
GROUP BY customer_state
ORDER BY average_order_value DESC;


/* ==============================================================
   22. CUSTOMER RANKING
   Purpose: Rank customers by total sales value using a window
            function.

   This demonstrates an important analytical SQL technique.
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    total_orders,
    ROUND(total_sales_value, 2) AS total_sales_value,
    RANK() OVER (
        ORDER BY total_sales_value DESC
    ) AS customer_sales_rank
FROM customer_metrics
ORDER BY customer_sales_rank
LIMIT 50;


/* ==============================================================
   23. CUSTOMER SALES PERCENTILE / RANKING GROUP
   Purpose: Divide customers into four groups based on spending.

   NTILE(4):
       1 = lowest-spending quarter
       4 = highest-spending quarter
   ============================================================== */

WITH customer_metrics AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
),
customer_quartiles AS (
    SELECT
        customer_unique_id,
        total_sales_value,
        NTILE(4) OVER (
            ORDER BY total_sales_value
        ) AS spending_quartile
    FROM customer_metrics
)

SELECT
    spending_quartile,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_sales_value), 2) AS total_sales_value,
    ROUND(AVG(total_sales_value), 2) AS average_customer_spend,
    ROUND(MIN(total_sales_value), 2) AS minimum_spend,
    ROUND(MAX(total_sales_value), 2) AS maximum_spend
FROM customer_quartiles
GROUP BY spending_quartile
ORDER BY spending_quartile;


/* ==============================================================
   24. CUSTOMER ACQUISITION BY MONTH
   Purpose: Estimate the number of unique customers making their
            first purchase in each month.

   This provides a simple customer acquisition trend.
   ============================================================== */

WITH customer_first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(date(o.order_purchase_timestamp)) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    strftime('%Y-%m', first_purchase_date) AS acquisition_month,
    COUNT(*) AS new_customers
FROM customer_first_purchase
GROUP BY strftime('%Y-%m', first_purchase_date)
ORDER BY acquisition_month;


/* ==============================================================
   25. CUSTOMER ACQUISITION BY STATE
   Purpose: Identify states generating the largest number of
            unique customer identities.
   ============================================================== */

WITH customer_first_purchase AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        MIN(date(o.order_purchase_timestamp)) AS first_purchase_date
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id,
        c.customer_state
)

SELECT
    customer_state,
    COUNT(*) AS unique_customers,
    MIN(first_purchase_date) AS earliest_customer_purchase
FROM customer_first_purchase
GROUP BY customer_state
ORDER BY unique_customers DESC;


/* ==============================================================
   26. FINAL CUSTOMER KPI SNAPSHOT
   Purpose: Compact output for project documentation and the
            future Power BI Customer Analytics page.
   ============================================================== */

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
customer_sales AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    (SELECT COUNT(*) FROM customer_orders)
        AS customers_with_orders,

    (SELECT SUM(
        CASE WHEN total_orders = 1 THEN 1 ELSE 0 END
    ) FROM customer_orders)
        AS one_time_customers,

    (SELECT SUM(
        CASE WHEN total_orders > 1 THEN 1 ELSE 0 END
    ) FROM customer_orders)
        AS repeat_customers,

    ROUND(
        100.0 *
        (SELECT SUM(
            CASE WHEN total_orders > 1 THEN 1 ELSE 0 END
        ) FROM customer_orders)
        / NULLIF((SELECT COUNT(*) FROM customer_orders), 0),
        2
    ) AS repeat_customer_percentage,

    (SELECT ROUND(SUM(total_sales_value), 2)
     FROM customer_sales)
        AS total_customer_sales_value,

    (SELECT ROUND(AVG(total_sales_value), 2)
     FROM customer_sales)
        AS average_customer_spend,

    (SELECT ROUND(MAX(total_sales_value), 2)
     FROM customer_sales)
        AS highest_customer_spend;


/*
================================================================
END OF 03_CUSTOMER_ANALYSIS.SQL

NEXT FILE:
04_product_category_analysis.sql

The next stage will analyze:
- Product categories
- English category names
- Product sales
- Quantity/items sold
- Average product price
- Top products
- Category contribution
- Category freight
- Product performance
================================================================
*/
