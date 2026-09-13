

````markdown
# Brazilian E-Commerce Analytics Dashboard

This project is based on the Brazilian E-Commerce Public Dataset by Olist. 
I used SQL and Power BI to analyze sales, customers, products, sellers, payments, reviews, and delivery performance.

The main goal of the project was to work with real-world e-commerce data and create a dashboard that can be used to understand business performance.

## Tools Used

- SQL
- SQLite
- DB Browser for SQLite
- Power BI
- DAX

## What I Analyzed

- Total orders and sales
- Product and category performance
- Customer behavior
- Repeat customers
- Seller performance
- Payment methods
- Customer reviews
- Delivery time
- Logistics performance

## Dashboard Pages

### 1. Business Overview

Shows the main business KPIs such as:

- Total orders
- Total customers
- Product revenue
- Freight
- Total sales value
- Average item price

### 2. Product & Seller Analytics

This page looks at:

- Product performance
- Category revenue
- Seller revenue
- Revenue per seller
- Revenue per product
- Freight by category

### 3. Customer & Satisfaction Analytics

This page covers:

- Total customers
- One-time and repeat customers
- Repeat customer rate
- Customers by state
- Review scores
- Delivery time and review scores

### 4. Payment & Order Analytics

This page includes:

- Payment value
- Payment methods
- Payment installments
- Order status
- Average payment value

### 5. Seller & Logistics Analytics

This page looks at:

- Top sellers by revenue
- Top sellers by orders
- Seller revenue and freight
- Freight by category
- Delivery time by state

### 6. Executive Summary

A summary of the main KPIs and charts from the project.

## Some Key Numbers

- Total Orders: **99,441**
- Customers: **96K+**
- Sellers: **3.1K+**
- Product Revenue: **R$13.59M**
- Total Sales Value: **R$15.84M**
- Total Payment Value: **R$16.01M**
- Average Review Score: **4.09 / 5**

## SQL Analysis

I also created separate SQL scripts for different parts of the analysis.

```text
SQL/
├── 01_data_validation.sql
├── 02_business_overview.sql
├── 03_customer_analysis.sql
├── 04_product_category_analysis.sql
├── 05_seller_logistics_analysis.sql
├── 06_payment_analysis.sql
├── 07_customer_satisfaction.sql
└── 08_advanced_business_analysis.sql
````

## Project Structure

```text
Brazilian-Ecommerce-Analytics/
│
├── PowerBI/
├── SQL/
├── Screenshots/
└── README.md
```

## What I Learned

Through this project, I practiced working with a multi-table dataset, writing SQL queries, creating relationships between tables, creating DAX measures, and building an interactive Power BI dashboard.

## Key Findings / Business Insights

Repeat customers
Calculated repeat customers and compared them with total customers. The dashboard shows ~2.997K repeat customers out
of 96.09K, or ~3.1%.

Delivery vs satisfaction
Grouped/compared average delivery days by review score. The displayed pattern goes from roughly 21–22 days for 1-star
reviews to roughly 10–11 days for 5-star reviews.

Category revenue
Aggregated product-item price by product category and ranked categories. Health & Beauty is displayed at about R$1.3M,
followed by other leading categories.

Payment behavior
Grouped payment records by payment type and compared payment count/value. Credit card is the dominant payment type in
the dashboard.

Seller performance
Aggregated item revenue by seller and ranked sellers. The dashboard shows a small group of top sellers contributing
substantially more revenue than many individual sellers.

State delivery performance
Calculated average delivery days by customer state. The displayed examples range roughly from 19 to 27 days.


## Dataset

Brazilian E-Commerce Public Dataset by Olist.

## Author

**Jayeshkumar Patel**
