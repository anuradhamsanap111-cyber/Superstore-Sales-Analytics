CREATE DATABASE retail_db;
USE retail_db;
select * from customers;
select * from `customers (2)`;
select count(customer_id) from `customers (2)`;
USE retail_db;
RENAME TABLE `customers (2)` TO customers;
select count(order_id) from order_items;
RENAME TABLE `orders (3)` TO orders;
select * from orders;
select count(order_id) from orders;
rename table `products (1)` to products;

USE retail_db;

CREATE  VIEW vw_sales_detail AS
SELECT
    oi.order_item_id,
    o.order_id,
    o.order_date,
    YEAR(o.order_date)  AS order_year,
    MONTH(o.order_date) AS order_month,
    o.ship_date,
    o.ship_mode,
    o.payment_method,
    o.order_status,
    c.customer_id,
    c.customer_name,
    c.age,
    c.city, c.state, c.region, c.segment,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    oi.quantity,
    oi.discount_pct,
    oi.quantity * p.unit_price * (1 - oi.discount_pct/100) AS revenue,
    oi.quantity * p.unit_cost AS cost,
    oi.quantity * p.unit_price * (1 - oi.discount_pct/100)
      - oi.quantity * p.unit_cost   AS profit
FROM order_items oi
JOIN orders o    ON oi.order_id    = o.order_id
JOIN customers c ON o.customer_id  = c.customer_id
JOIN products p  ON oi.product_id  = p.product_id; 
 select * from vw_sales_detail;
 
 -- Orders that have no items
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- Items whose order does not exist
SELECT COUNT(*) AS items_without_order
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Items whose product does not exist
SELECT COUNT(*) AS items_without_product
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Orders whose customer does not exist
SELECT COUNT(*) AS orders_without_customer
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Customers who never placed an order
SELECT COUNT(*) AS customers_without_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL;

-- Which orders have a NULL ship_date, and are they all Cancelled?
SHOW COLUMNS FROM orders LIKE 'ship_date';
SELECT order_status, 
COUNT(*) FROM orders 
WHERE ship_date = ''
GROUP BY order_status;

-- What is the date range of the orders, and is any ship_date earlier than order_date?
SELECT MIN(order_date) AS first_order,
       MAX(order_date) AS last_order,
       SUM(ship_date < order_date) AS ship_before_order
FROM orders;

-- SECTION B: BUSINESS OVERVIEW (KPIs)
-- What are the overall KPIs: orders, customers, revenue, profit, margin %, average order value?
SELECT 
COUNT(DISTINCT order_id) AS total_orders,
COUNT(DISTINCT customer_id) AS customers_who_ordered,
ROUND(SUM(revenue), 0) AS total_revenue,
ROUND(SUM(profit), 0)  AS total_profit,
ROUND(SUM(profit) / SUM(revenue) * 100, 2)    AS margin_pct,
ROUND(SUM(revenue) / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM vw_sales_detail;

-- How do revenue, profit and margin change each year, and what is the year-over-year growth %?
WITH yearly AS (
    SELECT order_year, SUM(revenue) AS revenue, SUM(profit) AS profit
    FROM vw_sales_detail
    GROUP BY order_year
)
SELECT order_year,
       ROUND(revenue, 0) AS revenue,
       ROUND(profit, 0)  AS profit,
       ROUND(profit / revenue * 100, 1) AS margin_pct,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY order_year))
             / LAG(revenue) OVER (ORDER BY order_year) * 100, 1) AS yoy_growth_pct
FROM yearly
ORDER BY order_year;

--  Which months are strongest? Show monthly revenue for each year side by side.
SELECT order_month,
       ROUND(SUM(CASE WHEN order_year = 2023 THEN revenue END), 0) AS rev_2023,
       ROUND(SUM(CASE WHEN order_year = 2024 THEN revenue END), 0) AS rev_2024,
       ROUND(SUM(CASE WHEN order_year = 2025 THEN revenue END), 0) AS rev_2025
FROM vw_sales_detail
GROUP BY order_month
ORDER BY order_month;

--  What share of total revenue does each category contribute?
SELECT category,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(revenue) / SUM(SUM(revenue)) OVER () * 100, 1) AS pct_of_total
FROM vw_sales_detail
GROUP BY category
ORDER BY revenue DESC;

--  SECTION C: TRENDS AND GROWTH

--  What is the month-over-month revenue growth %?
WITH monthly AS (
    SELECT order_year, order_month, SUM(revenue) AS revenue
    FROM vw_sales_detail
    GROUP BY order_year, order_month
)
SELECT order_year, order_month,
       ROUND(revenue, 0) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY order_year, order_month), 0) AS prev_month_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY order_year, order_month))
             / LAG(revenue) OVER (ORDER BY order_year, order_month) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY order_year, order_month;

-- What is the running (cumulative) revenue within each year?
WITH monthly AS (
    SELECT order_year, order_month, SUM(revenue) AS revenue
    FROM vw_sales_detail
    GROUP BY order_year, order_month
)
SELECT order_year, order_month,
       ROUND(revenue, 0) AS revenue,
       ROUND(SUM(revenue) OVER (PARTITION BY order_year ORDER BY order_month), 0) AS running_total
FROM monthly
ORDER BY order_year, order_month;

-- What are revenue and profit by quarter?
SELECT order_year,
       QUARTER(order_date) AS order_quarter,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(profit), 0)  AS profit,
       COUNT(DISTINCT order_id) AS orders
FROM vw_sales_detail
GROUP BY order_year, QUARTER(order_date)
ORDER BY order_year, order_quarter;

-- -- SECTION D: PRODUCTS AND PROFITABILITY

-- D1. Which categories earn the most profit, and which have the lowest margin?
SELECT category,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(profit), 0)  AS profit,
       ROUND(SUM(profit) / SUM(revenue) * 100, 1) AS margin_pct
FROM vw_sales_detail
GROUP BY category
ORDER BY profit DESC;

-- What are the top 3 products by revenue within each category?
WITH product_rev AS (
    SELECT category, product_name, SUM(revenue) AS revenue
    FROM vw_sales_detail
    GROUP BY category, product_name
),
ranked AS (
    SELECT category, product_name, revenue,
           DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM product_rev
)
SELECT category, rnk, product_name, ROUND(revenue, 0) AS revenue
FROM ranked
WHERE rnk <= 3
ORDER BY category, rnk;

-- which products have above-average revenue but a margin below the company margin (high volume, low profit)?
WITH product_stats AS (
    SELECT product_name, category,
           SUM(revenue) AS revenue,
           SUM(profit)  AS profit
    FROM vw_sales_detail
    GROUP BY product_name, category
)
SELECT product_name, category,
       ROUND(revenue, 0) AS revenue,
       ROUND(profit / revenue * 100, 1) AS margin_pct
FROM product_stats
WHERE revenue > (SELECT AVG(revenue) FROM product_stats)
  AND profit / revenue * 100 < (SELECT SUM(profit) / SUM(revenue) * 100 FROM vw_sales_detail)
ORDER BY revenue DESC;

-- How many order lines were sold at a loss, and what is the total loss?
SELECT COUNT(*) AS loss_making_lines,
       ROUND(SUM(profit), 0) AS total_loss
FROM vw_sales_detail
WHERE profit < 0;

-- Which products and discount levels cause these losses?
SELECT product_name, discount_pct,
       COUNT(*) as no_of_products,
       ROUND(SUM(profit), 0) AS profit
FROM vw_sales_detail
WHERE profit < 0
GROUP BY product_name, discount_pct
ORDER BY profit;

-- How do quantity and margin change with the discount level?
SELECT discount_pct,
       COUNT(*)   AS order_lines,
       ROUND(AVG(quantity), 2)   AS avg_quantity,
       ROUND(SUM(revenue), 0)  AS revenue,
       ROUND(SUM(profit) / SUM(revenue) * 100, 1) AS margin_pct
FROM vw_sales_detail
GROUP BY discount_pct
ORDER BY discount_pct;

-- SECTION E: CUSTOMERS
-- Who are the top 10 customers by revenue?
SELECT customer_id, customer_name, region,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(revenue), 0)   AS revenue
FROM vw_sales_detail
GROUP BY customer_id, customer_name, region
ORDER BY revenue DESC
LIMIT 10;

-- How many customers bought only once vs repeatedly, and how much revenue does each group bring?
WITH cust AS (
    SELECT customer_id,
           COUNT(DISTINCT order_id) AS orders,
           SUM(revenue) AS revenue
    FROM vw_sales_detail
    GROUP BY customer_id
)
SELECT 
CASE WHEN orders = 1
 THEN 'One-time' ELSE 'Repeat' 
 END AS customer_type,
       COUNT(*) AS customers,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 1) AS pct_revenue
FROM cust
GROUP BY CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END;

-- how do regions perform: customers, revenue, profit, margin and revenue per customer?
SELECT region,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(profit), 0) AS profit,
       ROUND(SUM(profit) / SUM(revenue) * 100, 1) AS margin_pct,
       ROUND(SUM(revenue) / COUNT(DISTINCT customer_id), 0) AS revenue_per_customer
FROM vw_sales_detail
GROUP BY region
ORDER BY revenue DESC;

-- Build the RFM table: recency (days), frequency (orders) and monetary value (revenue) per customer.
WITH ref AS (
    SELECT MAX(order_date) AS ref_date FROM orders
)
SELECT s.customer_id,
       DATEDIFF((SELECT ref_date FROM ref), MAX(s.order_date)) AS recency_days,
       COUNT(DISTINCT s.order_id) AS frequency,
       ROUND(SUM(s.revenue), 0) AS monetary
FROM vw_sales_detail s
GROUP BY s.customer_id
ORDER BY monetary DESC;

-- How many customers have not ordered in the last 6 months of the data (inactive customers)?
WITH last_order AS (
    SELECT customer_id, MAX(order_date) AS last_date
    FROM orders
    GROUP BY customer_id
)
SELECT COUNT(*) AS inactive_customers
FROM last_order
WHERE last_date < DATE_SUB((SELECT MAX(order_date) FROM orders), INTERVAL 6 MONTH);

-- SECTION F: OPERATIONS (returns, cancellations, delivery)

-- What is the split of orders by status (distinct orders and %)?
SELECT order_status,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER (), 1) AS pct_of_orders
FROM vw_sales_detail
GROUP BY order_status
ORDER BY orders DESC;

-- what is the return rate by category?
SELECT category,
       COUNT(DISTINCT order_id) AS orders,
       COUNT(DISTINCT CASE WHEN order_status = 'Returned' THEN order_id END) AS returned_orders,
       ROUND(COUNT(DISTINCT CASE WHEN order_status = 'Returned' THEN order_id END) * 100.0
             / COUNT(DISTINCT order_id), 1) AS return_rate_pct
FROM vw_sales_detail
GROUP BY category
ORDER BY return_rate_pct DESC;

-- What are the return and cancellation rates by payment method?
SELECT payment_method,
       COUNT(*) AS orders,
       ROUND(SUM(order_status = 'Returned')  * 100.0 / COUNT(*), 1) AS return_rate_pct,
       ROUND(SUM(order_status = 'Cancelled') * 100.0 / COUNT(*), 1) AS cancel_rate_pct
FROM orders
GROUP BY payment_method
ORDER BY orders DESC;

-- What is the average shipping time (days) by ship mode?
SELECT ship_mode,
       COUNT(*) AS shipped_orders,
       ROUND(AVG(DATEDIFF(ship_date, order_date)), 2) AS avg_days_to_ship
FROM orders
WHERE ship_date IS NOT NULL
GROUP BY ship_mode
ORDER BY avg_days_to_ship;

-- How much revenue is lost to cancelled and returned orders, and what is the net (delivered) revenue?
SELECT order_status,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM vw_sales_detail
GROUP BY order_status
ORDER BY revenue DESC;


-- One row per customer
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    c.customer_id,
    c.customer_name,
    c.age,
    c.region,
    c.segment,
    COUNT(DISTINCT s.order_id)  AS orders,
    ROUND(SUM(s.revenue), 2)    AS revenue,
    ROUND(SUM(s.profit), 2)     AS profit,
    MAX(s.order_date)           AS last_order_date
FROM customers c
LEFT JOIN vw_sales_detail s ON c.customer_id = s.customer_id
GROUP BY c.customer_id, c.customer_name, c.age, c.region, c.segment;
 
-- G3. One row per month
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    order_year,
    order_month,
    COUNT(DISTINCT order_id)                   AS orders,
    ROUND(SUM(revenue), 2)                     AS revenue,
    ROUND(SUM(profit), 2)                      AS profit,
    ROUND(SUM(profit) / SUM(revenue) * 100, 2) AS margin_pct
FROM vw_sales_detail
GROUP BY order_year, order_month;
 
-- Checks:
--   SELECT COUNT(*) FROM vw_customer_summary;  
--   SELECT COUNT(*) FROM vw_monthly_kpi;  