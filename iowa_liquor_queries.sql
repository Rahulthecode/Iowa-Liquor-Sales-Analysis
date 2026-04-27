CREATE TABLE sales (
    invoice_item_number TEXT,
    date TEXT,
    store_number TEXT,
    store_name TEXT,
    address TEXT,
    city TEXT,
    zip_code TEXT,
    store_location TEXT,
    county_number TEXT,
    county TEXT,
    category TEXT,
    category_name TEXT,
    vendor_number TEXT,
    vendor_name TEXT,
    item_number TEXT,
    item_description TEXT,
    pack TEXT,
    bottle_volume_ml TEXT,
    state_bottle_cost TEXT,
    state_bottle_retail TEXT,
    bottles_sold TEXT,
    sale_dollars TEXT,
    volume_sold_liters TEXT,
    volume_sold_gallons TEXT
);



---Section 1 — Data Exploration

-- 1. Total records
SELECT COUNT(*) AS total_records FROM sales;

-- 2. Date range
SELECT MIN(date) AS start_date,
       MAX(date) AS end_date
FROM sales;

-- 3. Unique stores
SELECT COUNT(DISTINCT store_number) AS total_stores
FROM sales;

-- 4. Unique vendors
SELECT COUNT(DISTINCT vendor_number) AS total_vendors
FROM sales;

-- 5. Unique categories
SELECT COUNT(DISTINCT category_name) AS total_categories
FROM sales;


---Section 2 — Revenue Analysis

-- 6. Total revenue
SELECT ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS total_revenue
FROM sales;

-- 7. Revenue by category
SELECT category_name,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue,
       COUNT(*) AS total_transactions
FROM sales
GROUP BY category_name
ORDER BY revenue DESC
LIMIT 10;

-- 8. Revenue by vendor
SELECT vendor_name,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue
FROM sales
GROUP BY vendor_name
ORDER BY revenue DESC
LIMIT 10;


---Section 3 — Top Products

-- 9. Top 10 products by revenue
SELECT item_description,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue,
       SUM(CAST(bottles_sold AS INTEGER)) AS total_bottles
FROM sales
GROUP BY item_description
ORDER BY revenue DESC
LIMIT 10;

-- 10. Top 10 products by volume
SELECT item_description,
       ROUND(SUM(CAST(volume_sold_liters AS NUMERIC)),2) 
       AS total_liters
FROM sales
GROUP BY item_description
ORDER BY total_liters DESC
LIMIT 10;

-- 11. Most sold bottle size
SELECT bottle_volume_ml,
       COUNT(*) AS transactions,
       SUM(CAST(bottles_sold AS INTEGER)) AS total_bottles
FROM sales
GROUP BY bottle_volume_ml
ORDER BY total_bottles DESC
LIMIT 10;


---Section 4 — Store Analysis

-- 12. Top 10 stores by revenue
SELECT store_name,
       city,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue
FROM sales
GROUP BY store_name, city
ORDER BY revenue DESC
LIMIT 10;

-- 13. Top cities by revenue
SELECT city,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue,
       COUNT(DISTINCT store_number) AS total_stores
FROM sales
GROUP BY city
ORDER BY revenue DESC
LIMIT 10;

-- 14. Revenue by county
SELECT county,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue
FROM sales
GROUP BY county
ORDER BY revenue DESC
LIMIT 10;


--- Section 5 — Monthly Trends

-- 15. Monthly revenue trend
SELECT SUBSTRING(date, 1, 7) AS month,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS monthly_revenue,
       COUNT(*) AS transactions,
       SUM(CAST(bottles_sold AS INTEGER)) AS bottles_sold
FROM sales
GROUP BY month
ORDER BY month;

-- 16. Best performing month
SELECT SUBSTRING(date, 1, 7) AS month,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue
FROM sales
GROUP BY month
ORDER BY revenue DESC
LIMIT 1;

-- 17. Month over month growth
WITH monthly AS (
    SELECT SUBSTRING(date, 1, 7) AS month,
           SUM(CAST(REPLACE(sale_dollars,'$','') 
           AS NUMERIC)) AS revenue
    FROM sales
    GROUP BY month
)
SELECT month,
       ROUND(revenue,2) AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY month),2) 
       AS prev_month_revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) /
             LAG(revenue) OVER (ORDER BY month) * 100, 2) 
       AS growth_pct
FROM monthly
ORDER BY month;


---Section 6 — Customer Segmentation (Store Level)

-- 18. Store segmentation using CTE
WITH store_stats AS (
    SELECT store_name,
           city,
           SUM(CAST(REPLACE(sale_dollars,'$','') 
           AS NUMERIC)) AS total_revenue,
           COUNT(*) AS total_transactions
    FROM sales
    GROUP BY store_name, city
),
avg_stats AS (
    SELECT AVG(total_revenue) AS avg_revenue
    FROM store_stats
)
SELECT store_name,
       city,
       ROUND(total_revenue,2) AS total_revenue,
       total_transactions,
       CASE
           WHEN total_revenue >= (SELECT avg_revenue FROM avg_stats) * 1.5
               THEN 'Premium Store'
           WHEN total_revenue >= (SELECT avg_revenue FROM avg_stats)
               THEN 'Regular Store'
           ELSE 'Low Volume Store'
       END AS store_segment
FROM store_stats
ORDER BY total_revenue DESC;


---Section 7 — Window Functions

-- 19. Store ranking by revenue
SELECT store_name,
       city,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue,
       RANK() OVER (ORDER BY SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)) DESC) AS revenue_rank
FROM sales
GROUP BY store_name, city
ORDER BY revenue_rank
LIMIT 20;

-- 20. Store rank within each city
SELECT store_name,
       city,
       ROUND(SUM(CAST(REPLACE(sale_dollars,'$','') 
       AS NUMERIC)),2) AS revenue,
       RANK() OVER (PARTITION BY city 
                    ORDER BY SUM(CAST(REPLACE(sale_dollars,'$','') 
                    AS NUMERIC)) DESC) AS rank_in_city
FROM sales
GROUP BY store_name, city
ORDER BY city, rank_in_city;

-- 21. Running total revenue
WITH daily AS (
    SELECT date,
           SUM(CAST(REPLACE(sale_dollars,'$','') 
           AS NUMERIC)) AS daily_revenue
    FROM sales
    GROUP BY date
)
SELECT date,
       ROUND(daily_revenue,2) AS daily_revenue,
       ROUND(SUM(daily_revenue) OVER (ORDER BY date),2) 
       AS running_total
FROM daily
ORDER BY date;

-- 22. Top product per category
WITH ranked AS (
    SELECT category_name,
           item_description,
           SUM(CAST(REPLACE(sale_dollars,'$','') 
           AS NUMERIC)) AS revenue,
           RANK() OVER (PARTITION BY category_name 
                        ORDER BY SUM(CAST(REPLACE(sale_dollars,'$','') 
                        AS NUMERIC)) DESC) AS rank
    FROM sales
    GROUP BY category_name, item_description
)
SELECT category_name,
       item_description,
       ROUND(revenue,2) AS revenue
FROM ranked
WHERE rank = 1
ORDER BY revenue DESC;


---Section 8 — Profit Margin Analysis

-- 23. Profit margin by category
SELECT category_name,
       ROUND(AVG(CAST(REPLACE(state_bottle_retail,'$','') 
       AS NUMERIC)),2) AS avg_retail_price,
       ROUND(AVG(CAST(REPLACE(state_bottle_cost,'$','') 
       AS NUMERIC)),2) AS avg_cost,
       ROUND(AVG(CAST(REPLACE(state_bottle_retail,'$','') 
       AS NUMERIC)) - 
       AVG(CAST(REPLACE(state_bottle_cost,'$','') 
       AS NUMERIC)),2) AS avg_margin
FROM sales
GROUP BY category_name
ORDER BY avg_margin DESC
LIMIT 10;

-- 24. Most profitable products
SELECT item_description,
       ROUND(AVG(CAST(REPLACE(state_bottle_retail,'$','') 
       AS NUMERIC) - 
       CAST(REPLACE(state_bottle_cost,'$','') 
       AS NUMERIC)),2) AS profit_per_bottle,
       SUM(CAST(bottles_sold AS INTEGER)) AS bottles_sold
FROM sales
GROUP BY item_description
ORDER BY profit_per_bottle DESC
LIMIT 10;

