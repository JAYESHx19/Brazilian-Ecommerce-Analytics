/*
================================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 06_payment_analysis.sql
PURPOSE : Analyze payment methods, payment value, installments,
          customer payment behavior and geographic payment patterns
DATABASE: Olist SQLite Database
================================================================

OBJECTIVE
---------
This script answers:

1. Which payment methods are used most frequently?
2. Which payment methods generate the highest payment value?
3. What is the average payment value by method?
4. How common are installment payments?
5. Which installment counts are most common?
6. How does payment behavior vary by customer state?
7. How does payment behavior vary by order value?
8. How many orders use multiple payment records?
9. What share of payment value comes from each method?
10. Which payment methods are associated with larger orders?
11. What payment KPIs can be used in Power BI?

CORE RELATIONSHIP
-----------------
orders
    |
    | order_id
    v
order_payments

customers
    |
    | customer_id
    v
orders

IMPORTANT DEFINITIONS
---------------------
Payment Value:
    SUM(order_payments.payment_value)

Payment Record:
    One row in order_payments.

Order:
    One distinct order_id.

Important:
    An order can have multiple payment records. Therefore,
    payment_record_count and distinct_order_count must not be
    treated as the same metric.

READ-ONLY
---------
All queries are SELECT statements only.

EXECUTION
---------
Run each numbered section separately in DB Browser for SQLite.
================================================================
*/


/* ==============================================================
   01. PAYMENT TABLE OVERVIEW
   Purpose: Establish the size of the payment dataset.
   ============================================================== */

SELECT
    COUNT(*) AS total_payment_records,
    COUNT(DISTINCT order_id) AS orders_with_payment_records,
    COUNT(DISTINCT payment_type) AS payment_method_count,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments;


/* ==============================================================
   02. PAYMENT METHODS
   Purpose: Discover all payment methods and their usage.
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
   03. PAYMENT METHOD SHARE
   Purpose: Calculate each payment method's share of total
            payment value.
   ============================================================== */

WITH payment_summary AS (
    SELECT
        payment_type,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY payment_type
)

SELECT
    payment_type,
    ROUND(total_payment_value, 2) AS total_payment_value,
    ROUND(
        100.0 * total_payment_value /
        NULLIF((SELECT SUM(total_payment_value)
                FROM payment_summary), 0),
        2
    ) AS payment_value_share_percentage
FROM payment_summary
ORDER BY total_payment_value DESC;


/* ==============================================================
   04. PAYMENT METHOD BY ORDER COUNT
   Purpose: Compare methods by number of distinct orders.

   Note:
       An order may use multiple payment records/methods, so the
       order counts across methods may not sum to total orders.
   ============================================================== */

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(
        100.0 * COUNT(DISTINCT order_id) /
        NULLIF((SELECT COUNT(DISTINCT order_id)
                FROM order_payments), 0),
        2
    ) AS order_share_percentage
FROM order_payments
GROUP BY payment_type
ORDER BY distinct_orders DESC;


/* ==============================================================
   05. INSTALLMENT DISTRIBUTION
   Purpose: Understand how customers pay in installments.
   ============================================================== */

SELECT
    payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY payment_installments
ORDER BY payment_installments;


/* ==============================================================
   06. INSTALLMENT BUCKETS
   Purpose: Create business-friendly installment groups.
   ============================================================== */

SELECT
    CASE
        WHEN payment_installments = 1 THEN '1 installment'
        WHEN payment_installments BETWEEN 2 AND 3 THEN '2-3 installments'
        WHEN payment_installments BETWEEN 4 AND 6 THEN '4-6 installments'
        WHEN payment_installments BETWEEN 7 AND 12 THEN '7-12 installments'
        WHEN payment_installments > 12 THEN '13+ installments'
        ELSE 'Invalid / Unknown'
    END AS installment_bucket,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY
    CASE
        WHEN payment_installments = 1 THEN '1 installment'
        WHEN payment_installments BETWEEN 2 AND 3 THEN '2-3 installments'
        WHEN payment_installments BETWEEN 4 AND 6 THEN '4-6 installments'
        WHEN payment_installments BETWEEN 7 AND 12 THEN '7-12 installments'
        WHEN payment_installments > 12 THEN '13+ installments'
        ELSE 'Invalid / Unknown'
    END
ORDER BY
    CASE installment_bucket
        WHEN '1 installment' THEN 1
        WHEN '2-3 installments' THEN 2
        WHEN '4-6 installments' THEN 3
        WHEN '7-12 installments' THEN 4
        ELSE 5
    END;


/* ==============================================================
   07. PAYMENT METHOD + INSTALLMENTS
   Purpose: Understand installment behavior within each payment
            method.
   ============================================================== */

SELECT
    payment_type,
    payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY
    payment_type,
    payment_installments
ORDER BY
    payment_type,
    payment_installments;


/* ==============================================================
   08. CREDIT CARD INSTALLMENT SUMMARY
   Purpose: Focus specifically on credit-card installment behavior.
   ============================================================== */

SELECT
    payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;


/* ==============================================================
   09. PAYMENT VALUE DISTRIBUTION
   Purpose: Understand payment-value ranges.
   ============================================================== */

SELECT
    CASE
        WHEN payment_value < 50 THEN 'Under 50'
        WHEN payment_value < 100 THEN '50-99.99'
        WHEN payment_value < 250 THEN '100-249.99'
        WHEN payment_value < 500 THEN '250-499.99'
        WHEN payment_value < 1000 THEN '500-999.99'
        ELSE '1000+'
    END AS payment_value_bucket,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY
    CASE
        WHEN payment_value < 50 THEN 'Under 50'
        WHEN payment_value < 100 THEN '50-99.99'
        WHEN payment_value < 250 THEN '100-249.99'
        WHEN payment_value < 500 THEN '250-499.99'
        WHEN payment_value < 1000 THEN '500-999.99'
        ELSE '1000+'
    END
ORDER BY
    CASE payment_value_bucket
        WHEN 'Under 50' THEN 1
        WHEN '50-99.99' THEN 2
        WHEN '100-249.99' THEN 3
        WHEN '250-499.99' THEN 4
        WHEN '500-999.99' THEN 5
        ELSE 6
    END;


/* ==============================================================
   10. ORDERS WITH MULTIPLE PAYMENT RECORDS
   Purpose: Identify orders that contain more than one payment
            record.
   ============================================================== */

WITH order_payment_counts AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count
    FROM order_payments
    GROUP BY order_id
)

SELECT
    payment_record_count,
    COUNT(*) AS order_count
FROM order_payment_counts
GROUP BY payment_record_count
ORDER BY payment_record_count;


/* ==============================================================
   11. MULTI-PAYMENT ORDER SUMMARY
   Purpose: Quantify orders using multiple payment records.
   ============================================================== */

WITH order_payment_counts AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count
    FROM order_payments
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_with_payment_records,
    SUM(
        CASE
            WHEN payment_record_count > 1 THEN 1
            ELSE 0
        END
    ) AS orders_with_multiple_payment_records,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN payment_record_count > 1 THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS multiple_payment_order_percentage
FROM order_payment_counts;


/* ==============================================================
   12. ORDERS WITH MULTIPLE PAYMENT TYPES
   Purpose: Identify orders using more than one payment method.
   ============================================================== */

WITH order_payment_types AS (
    SELECT
        order_id,
        COUNT(DISTINCT payment_type) AS payment_method_count
    FROM order_payments
    GROUP BY order_id
)

SELECT
    payment_method_count,
    COUNT(*) AS order_count
FROM order_payment_types
GROUP BY payment_method_count
ORDER BY payment_method_count;


/* ==============================================================
   13. MULTIPLE PAYMENT TYPE SUMMARY
   Purpose: Quantify orders that use multiple payment methods.
   ============================================================== */

WITH order_payment_types AS (
    SELECT
        order_id,
        COUNT(DISTINCT payment_type) AS payment_method_count
    FROM order_payments
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_with_payment_records,
    SUM(
        CASE
            WHEN payment_method_count > 1 THEN 1
            ELSE 0
        END
    ) AS orders_using_multiple_payment_methods,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN payment_method_count > 1 THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS multiple_payment_method_percentage
FROM order_payment_types;


/* ==============================================================
   14. ORDER-LEVEL PAYMENT TOTALS
   Purpose: Aggregate payment records to one row per order.

   This is important because order_payments may contain multiple
   rows for the same order.
   ============================================================== */

WITH order_payments_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value,
        COUNT(*) AS payment_record_count,
        COUNT(DISTINCT payment_type) AS payment_method_count,
        MAX(payment_installments) AS maximum_installments
    FROM order_payments
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_with_payments,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,
    ROUND(AVG(total_payment_value), 2) AS average_order_payment,
    ROUND(MIN(total_payment_value), 2) AS minimum_order_payment,
    ROUND(MAX(total_payment_value), 2) AS maximum_order_payment,
    ROUND(AVG(payment_record_count), 2)
        AS average_payment_records_per_order
FROM order_payments_summary;


/* ==============================================================
   15. PAYMENT VALUE VS ORDER SALES VALUE
   Purpose: Compare payment totals against order item values.

   Product + freight is used as the order sales value.

   This is a reconciliation diagnostic. Differences can occur
   because the tables represent different business concepts.
   ============================================================== */

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS order_sales_value
    FROM order_items
    GROUP BY order_id
),
order_payments_summary AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM order_payments
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_present_in_both_tables,
    ROUND(SUM(os.order_sales_value), 2) AS total_item_sales_value,
    ROUND(SUM(op.order_payment_value), 2) AS total_payment_value,
    ROUND(
        SUM(op.order_payment_value - os.order_sales_value),
        2
    ) AS total_payment_minus_sales_difference,
    ROUND(
        AVG(op.order_payment_value - os.order_sales_value),
        2
    ) AS average_payment_minus_sales_difference
FROM order_sales os
INNER JOIN order_payments_summary op
    ON os.order_id = op.order_id;


/* ==============================================================
   16. PAYMENT VS ORDER VALUE BY PAYMENT METHOD
   Purpose: Compare average payment value by method with the
            overall order payment value.
   ============================================================== */

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_record_value,
    ROUND(MIN(payment_value), 2) AS minimum_payment_value,
    ROUND(MAX(payment_value), 2) AS maximum_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY average_payment_record_value DESC;


/* ==============================================================
   17. PAYMENT METHOD BY CUSTOMER STATE
   Purpose: Understand geographic differences in payment usage.
   ============================================================== */

SELECT
    c.customer_state,
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS distinct_orders,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value,
    ROUND(AVG(op.payment_value), 2) AS average_payment_value
FROM order_payments op
INNER JOIN orders o
    ON op.order_id = o.order_id
INNER JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_state,
    op.payment_type
ORDER BY
    c.customer_state,
    total_payment_value DESC;


/* ==============================================================
   18. DOMINANT PAYMENT METHOD BY STATE
   Purpose: Rank payment methods within each customer state.

   ROW_NUMBER() gives the top method per state.
   ============================================================== */

WITH state_payment_methods AS (
    SELECT
        c.customer_state,
        op.payment_type,
        COUNT(DISTINCT op.order_id) AS distinct_orders,
        SUM(op.payment_value) AS total_payment_value
    FROM order_payments op
    INNER JOIN orders o
        ON op.order_id = o.order_id
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    GROUP BY
        c.customer_state,
        op.payment_type
),
ranked_methods AS (
    SELECT
        customer_state,
        payment_type,
        distinct_orders,
        total_payment_value,
        ROW_NUMBER() OVER (
            PARTITION BY customer_state
            ORDER BY total_payment_value DESC
        ) AS method_rank
    FROM state_payment_methods
)

SELECT
    customer_state,
    payment_type AS top_payment_method,
    distinct_orders,
    ROUND(total_payment_value, 2) AS total_payment_value
FROM ranked_methods
WHERE method_rank = 1
ORDER BY customer_state;


/* ==============================================================
   19. PAYMENT METHOD BY ORDER STATUS
   Purpose: Compare payment behavior across order statuses.
   ============================================================== */

SELECT
    o.order_status,
    op.payment_type,
    COUNT(DISTINCT o.order_id) AS distinct_orders,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value
FROM orders o
INNER JOIN order_payments op
    ON o.order_id = op.order_id
GROUP BY
    o.order_status,
    op.payment_type
ORDER BY
    o.order_status,
    total_payment_value DESC;


/* ==============================================================
   20. INSTALLMENTS VS PAYMENT VALUE
   Purpose: Determine whether higher-value payment records tend
            to have more installments.
   ============================================================== */

SELECT
    payment_installments,
    COUNT(*) AS payment_records,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments
GROUP BY payment_installments
ORDER BY payment_installments;


/* ==============================================================
   21. CREDIT CARD INSTALLMENT SHARE
   Purpose: Calculate how payment value is distributed across
            credit-card installment counts.
   ============================================================== */

WITH credit_card_payments AS (
    SELECT
        payment_installments,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    WHERE payment_type = 'credit_card'
    GROUP BY payment_installments
)

SELECT
    payment_installments,
    ROUND(total_payment_value, 2) AS total_payment_value,
    ROUND(
        100.0 * total_payment_value /
        NULLIF(
            (SELECT SUM(total_payment_value)
             FROM credit_card_payments),
            0
        ),
        2
    ) AS payment_value_share_percentage
FROM credit_card_payments
ORDER BY total_payment_value DESC;


/* ==============================================================
   22. HIGH-VALUE PAYMENT RECORDS
   Purpose: Identify payment records with unusually high values.

   Threshold:
       payment_value >= 1000

   This is a descriptive threshold and is not an outlier test.
   ============================================================== */

SELECT
    payment_type,
    COUNT(*) AS high_value_payment_records,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
WHERE payment_value >= 1000
GROUP BY payment_type
ORDER BY total_payment_value DESC;


/* ==============================================================
   23. PAYMENT VALUE BY CUSTOMER
   Purpose: Aggregate payment value to unique customer identity.

   This creates a customer-level payment dataset for comparison
   with the customer sales analysis.
   ============================================================== */

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT op.order_id) AS total_orders,
    COUNT(*) AS payment_records,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value,
    ROUND(AVG(op.payment_value), 2) AS average_payment_value
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_payments op
    ON o.order_id = op.order_id
GROUP BY c.customer_unique_id
ORDER BY total_payment_value DESC
LIMIT 50;


/* ==============================================================
   24. CUSTOMER PAYMENT METHOD PROFILE
   Purpose: Identify each customer's primary payment method by
            payment value.
   ============================================================== */

WITH customer_method_value AS (
    SELECT
        c.customer_unique_id,
        op.payment_type,
        SUM(op.payment_value) AS total_payment_value
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    INNER JOIN order_payments op
        ON o.order_id = op.order_id
    GROUP BY
        c.customer_unique_id,
        op.payment_type
),
ranked_methods AS (
    SELECT
        customer_unique_id,
        payment_type,
        total_payment_value,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY total_payment_value DESC
        ) AS method_rank
    FROM customer_method_value
)

SELECT
    customer_unique_id,
    payment_type AS primary_payment_method,
    ROUND(total_payment_value, 2) AS payment_value
FROM ranked_methods
WHERE method_rank = 1
ORDER BY payment_value DESC
LIMIT 50;


/* ==============================================================
   25. PAYMENT METHOD BY ORDER VALUE BUCKET
   Purpose: Explore whether payment method usage changes with
            order value.

   Order value here is based on payment total per order.
   ============================================================== */

WITH order_payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY order_id
),
orders_with_primary_method AS (
    SELECT
        opt.order_id,
        opt.total_payment_value,
        op.payment_type,
        ROW_NUMBER() OVER (
            PARTITION BY op.order_id
            ORDER BY op.payment_value DESC, op.payment_sequential
        ) AS payment_rank
    FROM order_payment_totals opt
    INNER JOIN order_payments op
        ON opt.order_id = op.order_id
)

SELECT
    CASE
        WHEN total_payment_value < 100 THEN 'Under 100'
        WHEN total_payment_value < 250 THEN '100-249.99'
        WHEN total_payment_value < 500 THEN '250-499.99'
        WHEN total_payment_value < 1000 THEN '500-999.99'
        ELSE '1000+'
    END AS order_value_bucket,
    payment_type AS primary_payment_method,
    COUNT(*) AS order_count,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value
FROM orders_with_primary_method
WHERE payment_rank = 1
GROUP BY
    CASE
        WHEN total_payment_value < 100 THEN 'Under 100'
        WHEN total_payment_value < 250 THEN '100-249.99'
        WHEN total_payment_value < 500 THEN '250-499.99'
        WHEN total_payment_value < 1000 THEN '500-999.99'
        ELSE '1000+'
    END,
    payment_type
ORDER BY
    CASE order_value_bucket
        WHEN 'Under 100' THEN 1
        WHEN '100-249.99' THEN 2
        WHEN '250-499.99' THEN 3
        WHEN '500-999.99' THEN 4
        ELSE 5
    END,
    total_payment_value DESC;


/* ==============================================================
   26. MONTHLY PAYMENT TREND
   Purpose: Analyze payment value and payment methods over time.
   ============================================================== */

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS payment_month,
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS distinct_orders,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value,
    ROUND(AVG(op.payment_value), 2) AS average_payment_value
FROM order_payments op
INNER JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY
    strftime('%Y-%m', o.order_purchase_timestamp),
    op.payment_type
ORDER BY
    payment_month,
    total_payment_value DESC;


/* ==============================================================
   27. MONTHLY PAYMENT VALUE
   Purpose: Create a simple monthly payment-value dataset.
   ============================================================== */

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS payment_month,
    COUNT(DISTINCT op.order_id) AS distinct_orders,
    ROUND(SUM(op.payment_value), 2) AS total_payment_value,
    ROUND(AVG(op.payment_value), 2) AS average_payment_value
FROM order_payments op
INNER JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
ORDER BY payment_month;


/* ==============================================================
   28. PAYMENT VALUE MONTH-OVER-MONTH GROWTH
   Purpose: Measure changes in payment value over time.
   ============================================================== */

WITH monthly_payments AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS payment_month,
        SUM(op.payment_value) AS total_payment_value
    FROM order_payments op
    INNER JOIN orders o
        ON op.order_id = o.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
),
with_previous AS (
    SELECT
        payment_month,
        total_payment_value,
        LAG(total_payment_value) OVER (
            ORDER BY payment_month
        ) AS previous_month_value
    FROM monthly_payments
)

SELECT
    payment_month,
    ROUND(total_payment_value, 2) AS total_payment_value,
    ROUND(previous_month_value, 2) AS previous_month_value,
    ROUND(
        100.0 *
        (total_payment_value - previous_month_value)
        / NULLIF(previous_month_value, 0),
        2
    ) AS month_over_month_growth_percentage
FROM with_previous
ORDER BY payment_month;


/* ==============================================================
   29. PAYMENT METHOD RANKING
   Purpose: Rank payment methods by total payment value.
   ============================================================== */

WITH payment_summary AS (
    SELECT
        payment_type,
        COUNT(DISTINCT order_id) AS distinct_orders,
        SUM(payment_value) AS total_payment_value
    FROM order_payments
    GROUP BY payment_type
)

SELECT
    payment_type,
    distinct_orders,
    ROUND(total_payment_value, 2) AS total_payment_value,
    RANK() OVER (
        ORDER BY total_payment_value DESC
    ) AS payment_value_rank
FROM payment_summary
ORDER BY payment_value_rank;


/* ==============================================================
   30. FINAL PAYMENT KPI SNAPSHOT
   Purpose: Compact summary for project documentation and the
            future Power BI Payment Analytics page.
   ============================================================== */

SELECT
    (SELECT COUNT(*) FROM order_payments)
        AS total_payment_records,

    (SELECT COUNT(DISTINCT order_id)
     FROM order_payments)
        AS orders_with_payments,

    (SELECT COUNT(DISTINCT payment_type)
     FROM order_payments)
        AS payment_methods,

    (SELECT ROUND(SUM(payment_value), 2)
     FROM order_payments)
        AS total_payment_value,

    (SELECT ROUND(AVG(payment_value), 2)
     FROM order_payments)
        AS average_payment_record_value,

    (SELECT COUNT(DISTINCT order_id)
     FROM order_payments
     WHERE payment_type = 'credit_card')
        AS credit_card_orders,

    (SELECT COUNT(DISTINCT order_id)
     FROM order_payments
     WHERE payment_type = 'boleto')
        AS boleto_orders;


/*
================================================================
END OF 06_PAYMENT_ANALYSIS.SQL

NEXT FILE:
07_customer_satisfaction.sql

The next stage will analyze:
- Review score distribution
- Average review score
- Reviews by category
- Reviews by state
- Review score vs delivery time
- Late delivery vs customer satisfaction
- Review response behavior
- Low-rating/high-rating patterns
================================================================
*/
