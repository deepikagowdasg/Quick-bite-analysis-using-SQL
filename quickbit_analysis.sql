-- Create the database -- 
create database quickbit_analysis;
use quickbit_analysis;

-- Create Tables & Import Data -- 
-- Customers
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  customer_name VARCHAR(100),
  city VARCHAR(50),
  signup_date DATE,
  customer_segment VARCHAR(20)
);

-- Restaurants
CREATE TABLE restaurants (
  restaurant_id INT PRIMARY KEY,
  restaurant_name VARCHAR(100),
  city VARCHAR(50),
  cuisine VARCHAR(50),
  rating DECIMAL(2,1)
);

-- Menu Items
CREATE TABLE menu_items (
  item_id INT PRIMARY KEY,
  restaurant_id INT,
  item_name VARCHAR(100),
  category VARCHAR(50),
  price DECIMAL(10,2)
);

-- Orders
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  restaurant_id INT,
  order_date DATE,
  order_status VARCHAR(20),
  delivery_minutes DECIMAL(5,2),
  order_amount DECIMAL(10,2),
  discount DECIMAL(10,2)
);

-- Payments
CREATE TABLE payments (
  payment_id INT PRIMARY KEY,
  order_id INT,
  payment_method VARCHAR(20),
  payment_status VARCHAR(20),
  payment_date DATE
);
--  Understand the Data
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM restaurants;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM payments;

-- Check Missing Values
-- Check for NULLs in customers
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN customer_name IS NULL OR customer_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN signup_date IS NULL OR signup_date='' THEN 1 END) AS missing_signup_date,
  COUNT(CASE WHEN customer_segment IS NULL OR customer_segment='' THEN 1 END) AS missing_segment
FROM customers;

-- order table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN order_status IS NULL OR order_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN delivery_minutes IS NULL OR delivery_minutes='' THEN 1 END) AS missing_delivery_time,
  COUNT(CASE WHEN order_amount IS NULL OR order_amount='' THEN 1 END) AS missing_amount,
  COUNT(CASE WHEN discount IS NULL OR discount='' THEN 1 END) AS missing_discount
FROM orders;

-- Payment Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN payment_method IS NULL OR payment_method='' THEN 1 END) AS missing_method,
  COUNT(CASE WHEN payment_status IS NULL OR payment_status='' THEN 1 END) AS missing_status,
  COUNT(CASE WHEN payment_date IS NULL OR payment_date='' THEN 1 END) AS missing_date
FROM payments;

-- Restaurants Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN restaurant_name IS NULL OR restaurant_name='' THEN 1 END) AS missing_name,
  COUNT(CASE WHEN city IS NULL OR city='' THEN 1 END) AS missing_city,
  COUNT(CASE WHEN cuisine IS NULL OR cuisine='' THEN 1 END) AS missing_cuisine,
  COUNT(CASE WHEN rating IS NULL OR rating='' THEN 1 END) AS missing_rating
FROM restaurants;

-- Menu Items Table
SELECT 
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN item_name IS NULL OR item_name='' THEN 1 END) AS missing_item,
  COUNT(CASE WHEN category IS NULL OR category='' THEN 1 END) AS missing_category,
  COUNT(CASE WHEN price IS NULL OR price='' THEN 1 END) AS missing_price
FROM menu_items;

-- Check Distinct Values - To spot inconsistencies:
-- Customer segments
SELECT DISTINCT customer_segment FROM customers;

-- Order statuses
SELECT DISTINCT order_status FROM orders;

-- Payment statuses
SELECT DISTINCT payment_status FROM payments;

-- Cuisine types
SELECT DISTINCT cuisine FROM restaurants;

DESCRIBE customers;
DESCRIBE restaurants;
DESCRIBE menu_items;
DESCRIBE orders;
DESCRIBE payments;

-- Data Cleanning
-- Convert signup_date from text to DATE
-- Disable safe update mode
SET SQL_SAFE_UPDATES = 0;
-- Run your update
UPDATE customers
SET signup_date = STR_TO_DATE(signup_date, '%d-%m-%Y')
WHERE signup_date IS NOT NULL AND signup_date <> '';

-- Re-enable safe update mode (recommended)
SET SQL_SAFE_UPDATES = 1;

-- Fill missing customer_segment with 'Unknown'
UPDATE customers
SET customer_segment = 'Unknown'
WHERE customer_segment IS NULL OR customer_segment = '';

## Orders
-- Normalize order_status values
UPDATE orders
SET order_status = CASE 
  WHEN order_status IN ('Delivered','Cancelled','Pending') THEN order_status
  ELSE 'Unknown' END;

-- Ensure discount is not greater than order_amount
UPDATE orders
SET discount = order_amount
WHERE discount > order_amount OR discount IS NULL;

### Payments
-- Remove orphan payments (orders that don’t exist)
DELETE FROM payments
WHERE order_id NOT IN (SELECT order_id FROM orders);

-- Normalize payment_status values
UPDATE payments
SET payment_status = CASE 
  WHEN payment_status IN ('Paid','Pending','Failed') THEN payment_status
  ELSE 'Unknown' END;
  
  ### Clean Menu Items
-- Remove invalid prices
DELETE FROM menu_items
WHERE price IS NULL OR price <= 0;

-- Standardize category values
UPDATE menu_items
SET category = CASE 
  WHEN category IN ('Main Course','Starter','Beverage','Dessert') THEN category
  ELSE 'Other' END;
  
  ## Validation After Cleaning
-- Customers
SELECT DISTINCT customer_segment FROM customers;

-- Orders
SELECT DISTINCT order_status FROM orders;

-- Payments
SELECT DISTINCT payment_status FROM payments;

-- Restaurants
SELECT DISTINCT cuisine FROM restaurants;

-- Menu Items
SELECT DISTINCT category FROM menu_items;

## A. Daily Demand & Order Volume Concentration
-- 1. Total unique active ordering dates
SELECT COUNT(DISTINCT order_date) AS total_active_dates 
FROM orders;

-- 2. Daily order volume distribution
SELECT order_date, COUNT(*) AS daily_orders
FROM orders
GROUP BY order_date
ORDER BY daily_orders DESC;

-- 3. Peak calendar date by total order volume
SELECT order_date, COUNT(*) AS peak_orders
FROM orders
GROUP BY order_date
ORDER BY peak_orders DESC
LIMIT 1;

-- 4. Calendar dates with above-average order volume
WITH daily_counts AS (
  SELECT order_date, COUNT(*) AS order_count 
  FROM orders 
  GROUP BY order_date
)
SELECT order_date, order_count 
FROM daily_counts 
WHERE order_count > (SELECT AVG(order_count) FROM daily_counts)
ORDER BY order_count DESC;

-- 5. Percentage of orders placed on peak demand dates (>= 3 orders)
SELECT
    (COUNT(CASE
        WHEN daily_orders >= 3 THEN order_id
    END) * 100.0 / COUNT(*)) AS peak_volume_share_pct
FROM (
    SELECT
        order_id,
        COUNT(*) OVER (PARTITION BY order_date) AS daily_orders
    FROM orders
) AS order_summary;

## B. Daily Revenue Concentration & Net Realization
-- 6. Total delivered net revenue by calendar date
SELECT order_date, SUM(order_amount - discount) AS daily_net_revenue
FROM orders 
WHERE order_status='Delivered'
GROUP BY order_date
ORDER BY daily_net_revenue DESC;

-- 7. Peak date generating highest delivered net revenue
SELECT order_date, SUM(order_amount - discount) AS highest_net_revenue
FROM orders 
WHERE order_status='Delivered'
GROUP BY order_date
ORDER BY highest_net_revenue DESC
LIMIT 1;

-- 8. Average daily delivered net revenue
WITH daily_rev AS (
  SELECT order_date, SUM(order_amount - discount) AS net_revenue 
  FROM orders 
  WHERE order_status='Delivered' 
  GROUP BY order_date
)
SELECT AVG(net_revenue) AS avg_daily_revenue 
FROM daily_rev;

-- 9. Dates generating revenue above daily average
WITH daily_rev AS (
  SELECT order_date, SUM(order_amount - discount) AS net_revenue 
  FROM orders 
  WHERE order_status='Delivered' 
  GROUP BY order_date
)
SELECT order_date, net_revenue 
FROM daily_rev, (SELECT AVG(net_revenue) AS avg_rev FROM daily_rev) a
WHERE net_revenue > a.avg_rev
ORDER BY net_revenue DESC;

-- 10. Total discount given on high-demand dates (>= 2 orders)
SELECT SUM(discount) AS discount_on_multi_order_dates
FROM orders
WHERE order_date IN (
  SELECT order_date 
  FROM orders 
  GROUP BY order_date 
  HAVING COUNT(*) >= 2
);

## C. Delivery Reliability During Demand Peaks
-- 11. Average delivery time on peak dates vs regular dates


SELECT
    CASE
        WHEN daily_count >= 2 THEN 'Peak / Multi-Order Date'
        ELSE 'Regular / Single-Order Date'
    END AS demand_type,
    AVG(delivery_minutes) AS avg_delivery_time
FROM (
    SELECT
        order_id,
        order_date,
        delivery_minutes,
        COUNT(*) OVER (PARTITION BY order_date) AS daily_count
    FROM orders
    WHERE order_status = 'Delivered'
) AS daily_orders
GROUP BY
    CASE
        WHEN daily_count >= 2 THEN 'Peak / Multi-Order Date'
        ELSE 'Regular / Single-Order Date'
    END;

-- 12. Top 5 calendar dates with highest average delivery delays
SELECT order_date, AVG(delivery_minutes) AS avg_delivery_minutes
FROM orders 
WHERE order_status='Delivered'
GROUP BY order_date
ORDER BY avg_delivery_minutes DESC
LIMIT 5;

-- 13. Delayed orders (> 45 mins) concentration across calendar dates
SELECT order_date, COUNT(*) AS delayed_orders_count
FROM orders 
WHERE order_status='Delivered' AND delivery_minutes > 45
GROUP BY order_date
ORDER BY delayed_orders_count DESC;

-- 14. Calendar dates with severe delivery SLA breaches (> 60 mins)
SELECT order_date, COUNT(*) AS severe_delay_count
FROM orders 
WHERE order_status='Delivered' AND delivery_minutes > 60
GROUP BY order_date
HAVING COUNT(*) > 0
ORDER BY severe_delay_count DESC;

## D. Order Fulfillment & Cancellation Patterns Across Dates
-- 15. Calendar dates with order cancellations
SELECT order_date, COUNT(CASE WHEN order_status='Cancelled' THEN 1 END) AS cancelled_orders
FROM orders
GROUP BY order_date
HAVING COUNT(CASE WHEN order_status='Cancelled' THEN 1 END) > 0
ORDER BY cancelled_orders DESC;

-- 16. Cancellation rate comparison between peak dates and normal dates
WITH date_types AS (
  SELECT order_id, order_status,
         CASE WHEN COUNT(*) OVER (PARTITION BY order_date) >= 2 THEN 'Peak Date' ELSE 'Normal Date' END AS date_category
  FROM orders
)
SELECT date_category,
       COUNT(CASE WHEN order_status='Cancelled' THEN 1 END) * 100.0 / COUNT(*) AS cancellation_rate
FROM date_types
GROUP BY date_category;

-- 17. Orders pending fulfillment by calendar date
SELECT order_date, COUNT(*) AS pending_orders
FROM orders
WHERE order_status='Pending'
GROUP BY order_date
ORDER BY pending_orders DESC;

-- 18. Customer segment order participation on high-demand dates
WITH peak_dates AS (
  SELECT order_date 
  FROM orders 
  GROUP BY order_date 
  HAVING COUNT(*) >= 2
)
SELECT c.customer_segment, COUNT(o.order_id) AS peak_orders
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date IN (SELECT order_date FROM peak_dates)
GROUP BY c.customer_segment
ORDER BY peak_orders DESC;

-- 19. Classify calendar dates into High, Moderate, or Low Demand Days
SELECT order_date,
       COUNT(*) AS total_orders,
       CASE 
         WHEN COUNT(*) >= 3 THEN 'High Demand Day'
         WHEN COUNT(*) = 2 THEN 'Moderate Demand Day'
         ELSE 'Low Demand Day'
       END AS demand_classification
FROM orders
GROUP BY order_date
ORDER BY total_orders DESC;

## E. Date Rankings & Cumulative Concentration
-- 20. Rank calendar dates by total order volume
SELECT order_date, COUNT(*) AS total_orders,
       RANK() OVER (ORDER BY COUNT(*) DESC) AS volume_rank
FROM orders
GROUP BY order_date;

-- 21. Rank calendar dates by realized delivered net revenue
SELECT order_date, SUM(order_amount - discount) AS net_revenue,
       DENSE_RANK() OVER (ORDER BY SUM(order_amount - discount) DESC) AS revenue_rank
FROM orders 
WHERE order_status='Delivered'
GROUP BY order_date;

-- 22. Top 3 highest revenue-contributing calendar dates
SELECT order_date, SUM(order_amount - discount) AS top_revenue
FROM orders 
WHERE order_status='Delivered'
GROUP BY order_date
ORDER BY top_revenue DESC
LIMIT 3;

-- 23. Cumulative revenue concentration across top calendar dates
WITH daily_summary AS (
  SELECT order_date, SUM(order_amount - discount) AS daily_rev
  FROM orders 
  WHERE order_status='Delivered'
  GROUP BY order_date
)
SELECT order_date, daily_rev,
       SUM(daily_rev) OVER (ORDER BY daily_rev DESC) AS cumulative_revenue
FROM daily_summary;
