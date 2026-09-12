/*
===============================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 01_data_validation.sql
PURPOSE : Validate the Olist SQLite database before analysis
DATABASE: Olist E-Commerce Dataset
===============================================================

HOW TO USE IN DB BROWSER FOR SQLITE
------------------------------------
1. Open the original olist.sqlite database.
2. Open this SQL file in the "Execute SQL" tab.
3. Run each numbered section separately.
4. Review the results before moving to the next section.

IMPORTANT
---------
This script is READ-ONLY. It uses SELECT statements only and does
not modify, insert, update, or delete any data.

VALIDATION AREAS
----------------
01. Database overview
02. Table row counts
03. Primary-key / duplicate checks
04. Missing-value checks
05. Relationship / orphan-record checks
06. Date-range checks
07. Data-value sanity checks
08. Order-status validation
09. Final validation summary
===============================================================
*/


/* =============================================================
   01. DATABASE OVERVIEW
   Goal: Confirm the main tables contain data.
   ============================================================= */

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'leads_closed', COUNT(*) FROM leads_closed
UNION ALL
SELECT 'leads_qualified', COUNT(*) FROM leads_qualified
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
ORDER BY row_count DESC;


/* =============================================================
   02. TABLE ROW COUNTS
   Goal: Quickly verify the core analytical tables individually.
   ============================================================= */

-- Customers
SELECT COUNT(*) AS customers_count
FROM customers;

-- Orders
SELECT COUNT(*) AS orders_count
FROM orders;

-- Order Items
SELECT COUNT(*) AS order_items_count
FROM order_items;

-- Products
SELECT COUNT(*) AS products_count
FROM products;

-- Sellers
SELECT COUNT(*) AS sellers_count
FROM sellers;

-- Payments
SELECT COUNT(*) AS payments_count
FROM order_payments;

-- Reviews
SELECT COUNT(*) AS reviews_count
FROM order_reviews;


/* =============================================================
   03. DUPLICATE / KEY VALIDATION
   Goal: Identify unexpected duplicate business keys.
   Note: Some tables legitimately contain multiple rows per
   order/product/customer, so the checks below are chosen around
   the schema relationships.
   ============================================================= */

-- 03.1 Duplicate customer_id
SELECT
    customer_id,
    COUNT(*) AS record_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 03.2 Duplicate order_id in orders
SELECT
    order_id,
    COUNT(*) AS record_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 03.3 Duplicate product_id in products
SELECT
    product_id,
    COUNT(*) AS record_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 03.4 Duplicate seller_id in sellers
SELECT
    seller_id,
    COUNT(*) AS record_count
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 03.5 Duplicate order_id + order_item_id
-- Each order item should have a unique combination of these fields.
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS record_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- 03.6 Duplicate review_id
SELECT
    review_id,
    COUNT(*) AS record_count
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


/* =============================================================
   04. MISSING-VALUE VALIDATION
   Goal: Identify NULL / missing values in important columns.
   ============================================================= */

-- 04.1 Customers
SELECT
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(customer_unique_id IS NULL) AS missing_customer_unique_id,
    SUM(customer_zip_code_prefix IS NULL) AS missing_zip_code,
    SUM(customer_city IS NULL) AS missing_city,
    SUM(customer_state IS NULL) AS missing_state
FROM customers;


-- 04.2 Orders
SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_status IS NULL) AS missing_order_status,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_date,
    SUM(order_approved_at IS NULL) AS missing_approved_date,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_date,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated_delivery_date
FROM orders;


-- 04.3 Order Items
SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(order_item_id IS NULL) AS missing_order_item_id,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(seller_id IS NULL) AS missing_seller_id,
    SUM(shipping_limit_date IS NULL) AS missing_shipping_limit_date,
    SUM(price IS NULL) AS missing_price,
    SUM(freight_value IS NULL) AS missing_freight_value
FROM order_items;


-- 04.4 Products
SELECT
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_name_lenght IS NULL) AS missing_name_length,
    SUM(product_description_lenght IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photos_qty,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width
-- FROM products;

-- 04.5 Sellers
SELECT
    SUM(seller_id IS NULL) AS missing_seller_id,
    SUM(seller_zip_code_prefix IS NULL) AS missing_zip_code,
    SUM(seller_city IS NULL) AS missing_city,
    SUM(seller_state IS NULL) AS missing_state
FROM sellers;


-- 04.6 Payments
SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(payment_sequential IS NULL) AS missing_payment_sequential,
    SUM(payment_type IS NULL) AS missing_payment_type,
    SUM(payment_installments IS NULL) AS missing_installments,
    SUM(payment_value IS NULL) AS missing_payment_value
FROM order_payments;


-- 04.7 Reviews
SELECT
    SUM(review_id IS NULL) AS missing_review_id,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(review_score IS NULL) AS missing_review_score,
    SUM(review_comment_title IS NULL) AS missing_comment_title,
    SUM(review_comment_message IS NULL) AS missing_comment_message,
    SUM(review_creation_date IS NULL) AS missing_creation_date,
    SUM(review_answer_timestamp IS NULL) AS missing_answer_timestamp
FROM order_reviews;


/* =============================================================
   05. RELATIONSHIP / ORPHAN-RECORD VALIDATION
   Goal: Find child records that do not have a matching parent.
   A result of 0 means no orphan records were found.
   ============================================================= */

-- 05.1 Orders without a matching customer
SELECT COUNT(*) AS orders_without_customer
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 05.2 Order items without a matching order
SELECT COUNT(*) AS order_items_without_order
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 05.3 Order items without a matching product
SELECT COUNT(*) AS order_items_without_product
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 05.4 Order items without a matching seller
SELECT COUNT(*) AS order_items_without_seller
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- 05.5 Payments without a matching order
SELECT COUNT(*) AS payments_without_order
FROM order_payments op
LEFT JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 05.6 Reviews without a matching order
SELECT COUNT(*) AS reviews_without_order
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


/* =============================================================
   06. DATE-RANGE VALIDATION
   Goal: Understand the time coverage and identify suspicious
   date relationships.
   ============================================================= */

-- 06.1 Overall order date range
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM orders;


-- 06.2 Date ranges for major order milestones
SELECT
    MIN(order_purchase_timestamp) AS first_purchase,
    MAX(order_purchase_timestamp) AS last_purchase,
    MIN(order_approved_at) AS first_approval,
    MAX(order_approved_at) AS last_approval,
    MIN(order_delivered_customer_date) AS first_delivery,
    MAX(order_delivered_customer_date) AS last_delivery,
    MIN(order_estimated_delivery_date) AS first_estimated_delivery,
    MAX(order_estimated_delivery_date) AS last_estimated_delivery
FROM orders;


-- 06.3 Orders where approval appears before purchase
SELECT COUNT(*) AS approval_before_purchase
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND datetime(order_approved_at) < datetime(order_purchase_timestamp);


-- 06.4 Orders where customer delivery appears before purchase
SELECT COUNT(*) AS delivery_before_purchase
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND datetime(order_delivered_customer_date) < datetime(order_purchase_timestamp);


-- 06.5 Orders delivered after estimated delivery
-- This is a validation/diagnostic count; later we will analyze
-- late deliveries in the logistics analysis file.
SELECT COUNT(*) AS delivered_after_estimated_date
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND datetime(order_delivered_customer_date)
      > datetime(order_estimated_delivery_date);


/* =============================================================
   07. DATA-VALUE SANITY CHECKS
   Goal: Identify impossible or suspicious numerical values.
   ============================================================= */

-- 07.1 Negative product prices
SELECT COUNT(*) AS negative_prices
FROM order_items
WHERE price < 0;


-- 07.2 Negative freight values
SELECT COUNT(*) AS negative_freight_values
FROM order_items
WHERE freight_value < 0;


-- 07.3 Zero-value product prices
SELECT COUNT(*) AS zero_price_items
FROM order_items
WHERE price = 0;


-- 07.4 Zero or negative payment values
SELECT COUNT(*) AS non_positive_payment_values
FROM order_payments
WHERE payment_value <= 0;


-- 07.5 Invalid review scores
SELECT COUNT(*) AS invalid_review_scores
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;


-- 07.6 Invalid payment installments
SELECT COUNT(*) AS invalid_installments
FROM order_payments
WHERE payment_installments <= 0;


-- 07.7 Invalid product dimensions
SELECT
    SUM(product_weight_g < 0) AS negative_weight,
    SUM(product_length_cm < 0) AS negative_length,
    SUM(product_height_cm < 0) AS negative_height,
    SUM(product_width_cm < 0) AS negative_width
FROM products;


/* =============================================================
   08. ORDER STATUS VALIDATION
   Goal: Understand the status values present in the database.
   We do not assume a fixed list; the query discovers the values.
   ============================================================= */

SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


/* =============================================================
   09. REVIEW SCORE DISTRIBUTION
   Goal: Check the quality and distribution of customer ratings.
   ============================================================= */

SELECT
    review_score,
    COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


/* =============================================================
   10. PAYMENT TYPE VALIDATION
   Goal: Discover the payment methods present in the dataset.
   ============================================================= */

SELECT
    payment_type,
    COUNT(*) AS payment_count,
    SUM(payment_value) AS total_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


/* =============================================================
   11. CATEGORY TRANSLATION VALIDATION
   Goal: Identify product categories that do not have an English
   translation.
   ============================================================= */

SELECT COUNT(*) AS categories_without_english_translation
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name_english IS NULL;


/* =============================================================
   12. CUSTOMER UNIQUE-ID VALIDATION
   Goal: Compare customer records with unique customer identities.
   One customer_unique_id can represent multiple customer_id
   records, so this is an observation rather than an error check.
   ============================================================= */

SELECT
    COUNT(*) AS customer_records,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


/* =============================================================
   13. FINAL VALIDATION SNAPSHOT
   Goal: Produce a compact set of important database-quality
   indicators that we can refer to in the project documentation.
   ============================================================= */

SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COUNT(*) FROM customers) AS total_customer_records,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM customers) AS unique_customers,
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM sellers) AS total_sellers,
    (SELECT COUNT(*) FROM order_items) AS total_order_items,
    (SELECT COUNT(*) FROM order_payments) AS total_payment_records,
    (SELECT COUNT(*) FROM order_reviews) AS total_review_records;


/*
===============================================================
END OF 01_DATA_VALIDATION.SQL
===============================================================

NEXT FILE:
02_business_overview.sql

The next stage will use the validated tables to calculate:
- Revenue
- Freight
- Total sales value
- Average order value
- Monthly sales
- Orders and customer KPIs
===============================================================
*/

