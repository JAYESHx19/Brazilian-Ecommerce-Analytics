/*
================================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 02_business_overview.sql
PURPOSE : Generate high-level business KPIs and sales trends
DATABASE: Olist SQLite Database
================================================================

OBJECTIVE
---------
This script answers the first set of business questions:

1. How large is the marketplace?
2. What is the total product sales value?
3. How much freight value is associated with orders?
4. What is the average order value?
5. How do orders and sales change over time?
6. Which order statuses make up the order base?
7. How much sales value comes from each order status?
8. How many customers and unique customer identities are present?

IMPORTANT DEFINITIONS
---------------------
Product Sales Value:
    SUM(order_items.price)

Freight Value:
    SUM(order_items.freight_value)

Total Sales Value:
    Product Sales Value + Freight Value

Average Order Value (AOV):
    Average of the total item value + freight value per order.

NOTE:
    The dataset does NOT contain product cost. Therefore this
    script does NOT calculate "profit".

READ-ONLY
---------
This script contains SELECT statements only. It does not modify
the database.

EXECUTION
---------
Run each numbered section separately in DB Browser for SQLite.
================================================================
*/


/* ==============================================================
   01. EXECUTIVE KPI SNAPSHOT
   Purpose: Main high-level KPIs for the project.
   ============================================================== */

SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,

    (SELECT COUNT(DISTINCT customer_id)
     FROM orders) AS customers_with_orders,

    (SELECT COUNT(DISTINCT customer_unique_id)
     FROM customers) AS unique_customer_identities,

    (SELECT COUNT(*) FROM products) AS total_products,

    (SELECT COUNT(*) FROM sellers) AS total_sellers,

    (SELECT COUNT(*) FROM order_items) AS total_order_items,

    (SELECT ROUND(SUM(price), 2)
     FROM order_items) AS product_sales_value,

    (SELECT ROUND(SUM(freight_value), 2)
     FROM order_items) AS total_freight_value,

    (SELECT ROUND(SUM(price + freight_value), 2)
     FROM order_items) AS total_sales_value;


/* ==============================================================
   02. PRODUCT SALES VS FREIGHT
   Purpose: Separate product value from shipping/freight value.
   ============================================================== */

SELECT
    ROUND(SUM(price), 2) AS product_sales_value,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(price + freight_value), 2) AS total_sales_value,
    ROUND(
        100.0 * SUM(freight_value)
        / NULLIF(SUM(price + freight_value), 0),
        2
    ) AS freight_percentage_of_total_sales
FROM order_items;


/* ==============================================================
   03. ORDER-LEVEL SALES METRICS
   Purpose: Calculate metrics at the order level rather than
            treating every order item as an order.

   Why this matters:
       One order can contain multiple products/items.
       Therefore AOV must be calculated after aggregating
       order_items by order_id.
   ============================================================== */

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_with_items,
    ROUND(SUM(product_value), 2) AS product_sales_value,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(total_order_value), 2) AS total_sales_value,
    ROUND(AVG(total_order_value), 2) AS average_order_value,
    ROUND(MIN(total_order_value), 2) AS minimum_order_value,
    ROUND(MAX(total_order_value), 2) AS maximum_order_value
FROM order_values;


/* ==============================================================
   04. MEDIAN-STYLE ORDER VALUE ANALYSIS
   Purpose: Show the distribution of order values.

   SQLite does not provide a simple built-in MEDIAN() function,
   so we calculate useful percentile-style checkpoints using
   window functions.

   Output:
       Lowest 25%
       Middle
       Highest 25%
   ============================================================== */

WITH order_values AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
),
ranked_orders AS (
    SELECT
        order_id,
        total_order_value,
        ROW_NUMBER() OVER (
            ORDER BY total_order_value
        ) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM order_values
)

SELECT
    ROUND(MIN(total_order_value), 2) AS minimum_order_value,
    ROUND(
        MAX(
            CASE
                WHEN row_num >= CAST(total_rows * 0.25 AS INTEGER)
                THEN total_order_value
            END
        ), 2
    ) AS approx_25th_percentile,
    ROUND(
        AVG(
            CASE
                WHEN row_num IN (
                    CAST((total_rows + 1) / 2 AS INTEGER),
                    CAST((total_rows + 2) / 2 AS INTEGER)
                )
                THEN total_order_value
            END
        ), 2
    ) AS median_order_value,
    ROUND(
        MAX(
            CASE
                WHEN row_num >= CAST(total_rows * 0.75 AS INTEGER)
                THEN total_order_value
            END
        ), 2
    ) AS approx_75th_percentile,
    ROUND(MAX(total_order_value), 2) AS maximum_order_value
FROM ranked_orders;


/* ==============================================================
   05. ORDER STATUS DISTRIBUTION
   Purpose: Understand the composition of the order base.
   ============================================================== */

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) /
        NULLIF((SELECT COUNT(*) FROM orders), 0),
        2
    ) AS order_percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


/* ==============================================================
   06. ORDER STATUS + SALES VALUE
   Purpose: Connect order status with product/freight value.

   This helps distinguish the overall order base from the value
   associated with different statuses.
   ============================================================== */

SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(oi.order_item_id) AS item_count,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value
FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY o.order_status
ORDER BY total_sales_value DESC;


/* ==============================================================
   07. DELIVERED-ORDER KPI SNAPSHOT
   Purpose: Create a separate view of completed/delivered orders.

   We keep this separate from the overall KPIs because the orders
   table contains multiple statuses.
   ============================================================== */

WITH delivered_orders AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
),
delivered_order_values AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_value,
        SUM(oi.freight_value) AS freight_value,
        SUM(oi.price + oi.freight_value) AS total_order_value
    FROM order_items oi
    INNER JOIN delivered_orders d
        ON oi.order_id = d.order_id
    GROUP BY oi.order_id
)

SELECT
    COUNT(*) AS delivered_orders_with_items,
    ROUND(SUM(product_value), 2) AS delivered_product_sales_value,
    ROUND(SUM(freight_value), 2) AS delivered_freight_value,
    ROUND(SUM(total_order_value), 2) AS delivered_total_sales_value,
    ROUND(AVG(total_order_value), 2) AS delivered_average_order_value
FROM delivered_order_values;


/* ==============================================================
   08. MONTHLY ORDER & SALES TREND
   Purpose: Analyze business performance over time.

   We use order_purchase_timestamp as the order date.
   ============================================================== */

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(ov.product_value), 2) AS product_sales_value,
    ROUND(SUM(ov.freight_value), 2) AS freight_value,
    ROUND(SUM(ov.total_order_value), 2) AS total_sales_value,
    ROUND(AVG(ov.total_order_value), 2) AS average_order_value
FROM orders o
INNER JOIN order_values ov
    ON o.order_id = ov.order_id
GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
ORDER BY order_month;


/* ==============================================================
   09. MONTH-OVER-MONTH SALES GROWTH
   Purpose: Measure how total sales value changes from month
            to month.

   Formula:
       (Current Month - Previous Month)
       / Previous Month * 100
   ============================================================== */

WITH monthly_sales AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM orders o
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
),
monthly_with_previous AS (
    SELECT
        order_month,
        total_sales_value,
        LAG(total_sales_value) OVER (
            ORDER BY order_month
        ) AS previous_month_sales
    FROM monthly_sales
)

SELECT
    order_month,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(previous_month_sales, 2) AS previous_month_sales,
    ROUND(
        100.0 *
        (total_sales_value - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS month_over_month_growth_percentage
FROM monthly_with_previous
ORDER BY order_month;


/* ==============================================================
   10. MONTHLY ORDER VOLUME GROWTH
   Purpose: Measure month-over-month changes in order volume.
   ============================================================== */

WITH monthly_orders AS (
    SELECT
        strftime('%Y-%m', order_purchase_timestamp) AS order_month,
        COUNT(*) AS total_orders
    FROM orders
    GROUP BY strftime('%Y-%m', order_purchase_timestamp)
),
monthly_with_previous AS (
    SELECT
        order_month,
        total_orders,
        LAG(total_orders) OVER (
            ORDER BY order_month
        ) AS previous_month_orders
    FROM monthly_orders
)

SELECT
    order_month,
    total_orders,
    previous_month_orders,
    ROUND(
        100.0 *
        (total_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS month_over_month_order_growth_percentage
FROM monthly_with_previous
ORDER BY order_month;


/* ==============================================================
   11. YEARLY BUSINESS SUMMARY
   Purpose: Provide a simpler annual view for the dashboard.
   ============================================================== */

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    strftime('%Y', o.order_purchase_timestamp) AS order_year,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(SUM(ov.product_value), 2) AS product_sales_value,
    ROUND(SUM(ov.freight_value), 2) AS freight_value,
    ROUND(SUM(ov.total_order_value), 2) AS total_sales_value,
    ROUND(AVG(ov.total_order_value), 2) AS average_order_value
FROM orders o
INNER JOIN order_values ov
    ON o.order_id = ov.order_id
GROUP BY strftime('%Y', o.order_purchase_timestamp)
ORDER BY order_year;


/* ==============================================================
   12. TOP SALES DAYS
   Purpose: Identify the strongest purchase dates by sales value.
   ============================================================== */

WITH daily_sales AS (
    SELECT
        date(o.order_purchase_timestamp) AS order_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM orders o
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY date(o.order_purchase_timestamp)
)

SELECT
    order_date,
    total_orders,
    ROUND(total_sales_value, 2) AS total_sales_value
FROM daily_sales
ORDER BY total_sales_value DESC
LIMIT 10;


/* ==============================================================
   13. SALES BY CUSTOMER STATE
   Purpose: Establish a geographic business overview.

   Relationship:
       customers → orders → order_items
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
   14. SALES CONCENTRATION BY STATE
   Purpose: Calculate each state's share of total sales value.
   ============================================================== */

WITH state_sales AS (
    SELECT
        c.customer_state,
        SUM(oi.price + oi.freight_value) AS total_sales_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY c.customer_state
)

SELECT
    customer_state,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(
        100.0 * total_sales_value /
        NULLIF((SELECT SUM(total_sales_value) FROM state_sales), 0),
        2
    ) AS sales_share_percentage
FROM state_sales
ORDER BY total_sales_value DESC;


/* ==============================================================
   15. PAYMENT VALUE OVERVIEW
   Purpose: Provide a high-level view of payment methods.

   Detailed payment analysis will be handled later in
   06_payment_analysis.sql.
   ============================================================== */

SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders_using_method,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


/* ==============================================================
   16. FINAL BUSINESS KPI TABLE
   Purpose: Compact output for project documentation.

   These are the core metrics we can use later in the Power BI
   Executive Overview page.
   ============================================================== */

WITH order_values AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,

    (SELECT COUNT(DISTINCT customer_unique_id)
     FROM customers) AS unique_customers,

    (SELECT COUNT(*) FROM products) AS total_products,

    (SELECT COUNT(*) FROM sellers) AS total_sellers,

    (SELECT ROUND(SUM(price), 2)
     FROM order_items) AS product_sales_value,

    (SELECT ROUND(SUM(freight_value), 2)
     FROM order_items) AS freight_value,

    (SELECT ROUND(SUM(price + freight_value), 2)
     FROM order_items) AS total_sales_value,

    (SELECT ROUND(AVG(total_order_value), 2)
     FROM order_values) AS average_order_value;


/*
================================================================
END OF 02_BUSINESS_OVERVIEW.SQL

NEXT FILE:
03_customer_analysis.sql

The next stage will focus on:
- Customer geography
- One-time vs repeat customers
- Customer order frequency
- Customer spending
- High-value customers
- Customer segmentation
================================================================
*/
