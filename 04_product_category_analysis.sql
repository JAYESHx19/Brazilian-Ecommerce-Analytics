/*
================================================================
PROJECT  : Brazilian E-Commerce Sales & Customer Analytics
FILE    : 04_product_category_analysis.sql
PURPOSE : Analyze product performance, categories, pricing,
          sales volume and freight
DATABASE: Olist SQLite Database
================================================================

OBJECTIVE
---------
This script answers:

1. Which product categories generate the most sales?
2. Which categories sell the most items?
3. Which products generate the most revenue?
4. What is the average selling price?
5. Which categories have high freight costs?
6. What share of sales does each category contribute?
7. How do translated/English category names map to sales?
8. Which products and categories have strong order performance?
9. Which categories have high sales but relatively high freight?
10. What product characteristics are available for analysis?

CORE TABLE RELATIONSHIPS
------------------------
products
    |
    | product_id
    v
order_items
    |
    | order_id
    v
orders

products
    |
    | product_category_name
    v
product_category_name_translation

SALES DEFINITION
----------------
Product Sales Value = SUM(order_items.price)

Total Sales Value = SUM(price + freight_value)

This script does NOT calculate profit because the dataset does
not contain product cost.

IMPORTANT
---------
The original Olist dataset contains the spelling:
    product_name_lenght
    product_description_lenght

Those original names are intentionally preserved when referenced.

READ-ONLY
---------
All queries are SELECT statements. No data is modified.

EXECUTION
---------
Run each numbered section separately in DB Browser for SQLite.
================================================================
*/


/* ==============================================================
   01. PRODUCT CATALOG OVERVIEW
   Purpose: Understand the size and structure of the product
            catalog.
   ============================================================== */

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS distinct_products,
    COUNT(DISTINCT product_category_name) AS distinct_categories
FROM products;


/* ==============================================================
   02. PRODUCT CATEGORY COVERAGE
   Purpose: Count products by original Portuguese category name.
   ============================================================== */

SELECT
    product_category_name,
    COUNT(*) AS product_count
FROM products
GROUP BY product_category_name
ORDER BY product_count DESC;


/* ==============================================================
   03. ENGLISH CATEGORY TRANSLATION COVERAGE
   Purpose: Check how many product categories have an English
            translation.
   ============================================================== */

SELECT
    COUNT(DISTINCT p.product_category_name) AS categories_in_products,
    COUNT(DISTINCT t.product_category_name) AS categories_with_translation,
    COUNT(DISTINCT t.product_category_name_english) AS english_categories
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name;


/* ==============================================================
   04. PRODUCTS WITHOUT ENGLISH CATEGORY TRANSLATION
   Purpose: Identify categories that cannot currently be mapped
            to an English category name.
   ============================================================== */

SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name_english IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;


/* ==============================================================
   05. PRODUCT SALES OVERVIEW
   Purpose: Establish overall item-level sales metrics.
   ============================================================== */

SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT order_id) AS orders_with_items,
    COUNT(DISTINCT product_id) AS products_sold,
    ROUND(SUM(price), 2) AS product_sales_value,
    ROUND(SUM(freight_value), 2) AS total_freight_value,
    ROUND(SUM(price + freight_value), 2) AS total_sales_value,
    ROUND(AVG(price), 2) AS average_item_price,
    ROUND(AVG(freight_value), 2) AS average_item_freight
FROM order_items;


/* ==============================================================
   06. SALES BY CATEGORY
   Purpose: Main category-performance table.

   English category names are used when a translation exists;
   otherwise the original category name is retained.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.product_id) AS distinct_products,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY total_sales_value DESC;


/* ==============================================================
   07. TOP 20 CATEGORIES BY PRODUCT SALES
   Purpose: Rank categories by product revenue only, excluding
            freight from the ranking metric.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY product_sales_value DESC
LIMIT 20;


/* ==============================================================
   08. TOP 20 CATEGORIES BY ITEM VOLUME
   Purpose: Find categories with the highest number of items sold.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_sales_value
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY items_sold DESC
LIMIT 20;


/* ==============================================================
   09. CATEGORY SALES CONTRIBUTION
   Purpose: Calculate each category's percentage contribution to
            overall product sales.
   ============================================================== */

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        SUM(oi.price) AS product_sales_value
    FROM order_items oi
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)

SELECT
    category_name,
    ROUND(product_sales_value, 2) AS product_sales_value,
    ROUND(
        100.0 * product_sales_value /
        NULLIF((SELECT SUM(product_sales_value)
                FROM category_sales), 0),
        2
    ) AS sales_contribution_percentage
FROM category_sales
ORDER BY product_sales_value DESC;


/* ==============================================================
   10. CATEGORY FREIGHT ANALYSIS
   Purpose: Compare freight value and freight percentage by
            category.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(
        100.0 * SUM(oi.freight_value) /
        NULLIF(SUM(oi.price + oi.freight_value), 0),
        2
    ) AS freight_percentage_of_total_sales
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY freight_percentage_of_total_sales DESC;


/* ==============================================================
   11. TOP PRODUCTS BY SALES VALUE
   Purpose: Identify individual products generating the highest
            product sales value.
   ============================================================== */

SELECT
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_sales_value,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY product_sales_value DESC
LIMIT 20;


/* ==============================================================
   12. TOP PRODUCTS BY ITEM VOLUME
   Purpose: Identify products with the highest number of items
            sold.
   ============================================================== */

SELECT
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY items_sold DESC
LIMIT 20;


/* ==============================================================
   13. CATEGORY AVERAGE PRICE
   Purpose: Compare typical item prices across categories.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(*) AS items_sold,
    ROUND(AVG(oi.price), 2) AS average_item_price,
    ROUND(MIN(oi.price), 2) AS minimum_item_price,
    ROUND(MAX(oi.price), 2) AS maximum_item_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY average_item_price DESC;


/* ==============================================================
   14. CATEGORY SALES PER ORDER
   Purpose: Compare category sales value relative to the number
            of orders containing the category.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(
        SUM(oi.price) /
        NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS sales_value_per_order
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY sales_value_per_order DESC;


/* ==============================================================
   15. CATEGORY ORDER PENETRATION
   Purpose: Estimate the percentage of all orders that contained
            at least one item from each category.

   A single order can contain multiple categories, so percentages
   across categories are not expected to add to 100%.
   ============================================================== */

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT oi.order_id) AS orders_with_category,
    ROUND(
        100.0 * COUNT(DISTINCT oi.order_id) /
        NULLIF((SELECT COUNT(*) FROM orders), 0),
        2
    ) AS order_penetration_percentage
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY order_penetration_percentage DESC;


/* ==============================================================
   16. CATEGORY RANKING
   Purpose: Demonstrate RANK() for category performance.
   ============================================================== */

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        SUM(oi.price) AS product_sales_value,
        COUNT(*) AS items_sold
    FROM order_items oi
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)

SELECT
    category_name,
    items_sold,
    ROUND(product_sales_value, 2) AS product_sales_value,
    RANK() OVER (
        ORDER BY product_sales_value DESC
    ) AS sales_rank
FROM category_sales
ORDER BY sales_rank;


/* ==============================================================
   17. TOP CATEGORY SALES CONCENTRATION
   Purpose: Show how much of total product sales comes from the
            top categories.

   This output is useful for identifying sales concentration.
   ============================================================== */

WITH category_sales AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        SUM(oi.price) AS product_sales_value
    FROM order_items oi
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
),
ranked_categories AS (
    SELECT
        category_name,
        product_sales_value,
        ROW_NUMBER() OVER (
            ORDER BY product_sales_value DESC
        ) AS sales_rank
    FROM category_sales
)

SELECT
    CASE
        WHEN sales_rank <= 5 THEN 'Top 5'
        WHEN sales_rank <= 10 THEN '6-10'
        WHEN sales_rank <= 20 THEN '11-20'
        ELSE '21+'
    END AS category_group,
    COUNT(*) AS category_count,
    ROUND(SUM(product_sales_value), 2) AS product_sales_value,
    ROUND(
        100.0 * SUM(product_sales_value) /
        NULLIF((SELECT SUM(product_sales_value)
                FROM category_sales), 0),
        2
    ) AS sales_contribution_percentage
FROM ranked_categories
GROUP BY
    CASE
        WHEN sales_rank <= 5 THEN 'Top 5'
        WHEN sales_rank <= 10 THEN '6-10'
        WHEN sales_rank <= 20 THEN '11-20'
        ELSE '21+'
    END
ORDER BY
    CASE category_group
        WHEN 'Top 5' THEN 1
        WHEN '6-10' THEN 2
        WHEN '11-20' THEN 3
        ELSE 4
    END;


/* ==============================================================
   18. PRODUCT CATALOG CHARACTERISTICS
   Purpose: Summarize available product attributes.

   NOTE:
       These fields describe the catalog, not necessarily sales.
   ============================================================== */

SELECT
    ROUND(AVG(product_weight_g), 2) AS average_weight_g,
    ROUND(AVG(product_length_cm), 2) AS average_length_cm,
    ROUND(AVG(product_height_cm), 2) AS average_height_cm,
    ROUND(AVG(product_width_cm), 2) AS average_width_cm,
    ROUND(AVG(product_photos_qty), 2) AS average_photos_qty,
    ROUND(AVG(product_name_lenght), 2) AS average_name_length,
    ROUND(AVG(product_description_lenght), 2) AS average_description_length
FROM products;


/* ==============================================================
   19. CATEGORY PRODUCT CATALOG SIZE VS SALES
   Purpose: Compare the number of products available in a
            category with its sales performance.
   ============================================================== */

WITH catalog AS (
    SELECT
        p.product_category_name,
        COUNT(DISTINCT p.product_id) AS catalog_products
    FROM products p
    GROUP BY p.product_category_name
),
sales AS (
    SELECT
        p.product_category_name,
        COUNT(*) AS items_sold,
        SUM(oi.price) AS product_sales_value
    FROM products p
    INNER JOIN order_items oi
        ON p.product_id = oi.product_id
    GROUP BY p.product_category_name
)

SELECT
    COALESCE(
        t.product_category_name_english,
        c.product_category_name,
        'Unknown'
    ) AS category_name,
    c.catalog_products,
    COALESCE(s.items_sold, 0) AS items_sold,
    ROUND(COALESCE(s.product_sales_value, 0), 2)
        AS product_sales_value
FROM catalog c
LEFT JOIN sales s
    ON c.product_category_name = s.product_category_name
LEFT JOIN product_category_name_translation t
    ON c.product_category_name = t.product_category_name
ORDER BY product_sales_value DESC;


/* ==============================================================
   20. HIGH-SALES / HIGH-FREIGHT CATEGORIES
   Purpose: Flag categories where freight represents a relatively
            large share of total sales.

   This is descriptive, not a claim that freight is a problem.
   We will interpret the result after seeing the data.
   ============================================================== */

WITH category_metrics AS (
    SELECT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category_name,
        SUM(oi.price) AS product_sales_value,
        SUM(oi.freight_value) AS freight_value,
        SUM(oi.price + oi.freight_value) AS total_sales_value,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM order_items oi
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    GROUP BY
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        )
)

SELECT
    category_name,
    total_orders,
    ROUND(product_sales_value, 2) AS product_sales_value,
    ROUND(freight_value, 2) AS freight_value,
    ROUND(total_sales_value, 2) AS total_sales_value,
    ROUND(
        100.0 * freight_value /
        NULLIF(total_sales_value, 0),
        2
    ) AS freight_percentage
FROM category_metrics
WHERE total_sales_value > 0
ORDER BY freight_percentage DESC;


/* ==============================================================
   21. CATEGORY PERFORMANCE BY ORDER STATUS
   Purpose: Understand category sales alongside order status.

   This can help identify categories with larger values associated
   with cancelled/unavailable/other statuses. We do not interpret
   the result until it has been validated.
   ============================================================== */

SELECT
    o.order_status,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    o.order_status,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY
    o.order_status,
    product_sales_value DESC;


/* ==============================================================
   22. MONTHLY CATEGORY SALES
   Purpose: Prepare a dataset for Power BI trend analysis by
            category and month.
   ============================================================== */

SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_sales_value,
    ROUND(SUM(oi.price + oi.freight_value), 2)
        AS total_sales_value
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    strftime('%Y-%m', o.order_purchase_timestamp),
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )
ORDER BY
    order_month,
    product_sales_value DESC;


/* ==============================================================
   23. FINAL PRODUCT & CATEGORY KPI SNAPSHOT
   Purpose: Compact summary for project documentation and the
            future Power BI Product Analytics page.
   ============================================================== */

SELECT
    (SELECT COUNT(*) FROM products)
        AS total_products,

    (SELECT COUNT(DISTINCT product_category_name)
     FROM products)
        AS total_categories,

    (SELECT COUNT(*) FROM order_items)
        AS total_order_items,

    (SELECT COUNT(DISTINCT product_id)
     FROM order_items)
        AS products_with_sales,

    (SELECT ROUND(SUM(price), 2)
     FROM order_items)
        AS product_sales_value,

    (SELECT ROUND(SUM(freight_value), 2)
     FROM order_items)
        AS freight_value,

    (SELECT ROUND(AVG(price), 2)
     FROM order_items)
        AS average_item_price,

    (SELECT ROUND(AVG(freight_value), 2)
     FROM order_items)
        AS average_item_freight;


/*
================================================================
END OF 04_PRODUCT_CATEGORY_ANALYSIS.SQL

NEXT FILE:
05_seller_logistics_analysis.sql

The next stage will analyze:
- Seller performance
- Seller sales
- Seller order volume
- Freight
- Delivery time
- Estimated vs actual delivery
- Late-delivery rates
- Delivery performance by state/category
================================================================
*/
