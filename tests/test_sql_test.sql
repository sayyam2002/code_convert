-- Unit Tests for Customer Analytics SQL Query
-- Testing Framework: SQL Unit Testing with Test Data Setup

-- Test Setup: Create test tables and insert test data
CREATE TABLE test_raw_customers (
    customer_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(50),
    birth_date DATE,
    gender VARCHAR(20),
    income_bracket VARCHAR(50),
    customer_segment VARCHAR(50),
    signup_date DATE
);

CREATE TABLE test_orders (
    order_id INT,
    customer_id INT,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

CREATE TABLE test_order_items (
    order_item_id INT,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2)
);

CREATE TABLE test_products (
    product_id INT,
    category VARCHAR(100)
);

CREATE TABLE test_results (
    test_name VARCHAR(255),
    test_status VARCHAR(20),
    expected_value VARCHAR(500),
    actual_value VARCHAR(500),
    test_timestamp TIMESTAMP
);

-- Test 1: Deduplication by email with most recent signup_date
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 'john@test.com' AS email, CAST('2023-01-01' AS DATE) AS signup_date
    UNION ALL
    SELECT 2 AS customer_id, 'john@test.com' AS email, CAST('2023-06-01' AS DATE) AS signup_date
    UNION ALL
    SELECT 3 AS customer_id, 'jane@test.com' AS email, CAST('2023-03-01' AS DATE) AS signup_date
),
deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
    FROM test_data
),
result AS (
    SELECT COUNT(*) AS cnt FROM deduplicated WHERE row_num = 1
)
SELECT 
    'Test_Deduplication_By_Email' AS test_name,
    CASE WHEN cnt = 2 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2' AS expected_value,
    CAST(cnt AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 2: NULL email filtering
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, NULL AS email, 1 AS customer_id_check
    UNION ALL
    SELECT 2 AS customer_id, 'valid@test.com' AS email, 2 AS customer_id_check
    UNION ALL
    SELECT NULL AS customer_id, 'another@test.com' AS email, NULL AS customer_id_check
),
filtered AS (
    SELECT * FROM test_data WHERE email IS NOT NULL AND customer_id IS NOT NULL
),
result AS (
    SELECT COUNT(*) AS cnt FROM filtered
)
SELECT 
    'Test_NULL_Email_Filtering' AS test_name,
    CASE WHEN cnt = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '1' AS expected_value,
    CAST(cnt AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 3: Name trimming and uppercasing
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT '  john  ' AS first_name, '  doe  ' AS last_name
),
cleaned AS (
    SELECT 
        UPPER(TRIM(first_name)) AS first_name,
        UPPER(TRIM(last_name)) AS last_name
    FROM test_data
),
result AS (
    SELECT first_name, last_name FROM cleaned
)
SELECT 
    'Test_Name_Trimming_Uppercasing' AS test_name,
    CASE WHEN first_name = 'JOHN' AND last_name = 'DOE' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'JOHN|DOE' AS expected_value,
    first_name || '|' || last_name AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 4: Email lowercasing and trimming
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT '  TEST@EXAMPLE.COM  ' AS email
),
cleaned AS (
    SELECT LOWER(TRIM(email)) AS email FROM test_data
),
result AS (
    SELECT email FROM cleaned
)
SELECT 
    'Test_Email_Lowercasing_Trimming' AS test_name,
    CASE WHEN email = 'test@example.com' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'test@example.com' AS expected_value,
    email AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 5: COALESCE default values for phone
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS phone
    UNION ALL
    SELECT '555-1234' AS phone
),
cleaned AS (
    SELECT COALESCE(phone, 'N/A') AS phone FROM test_data
),
result AS (
    SELECT COUNT(*) AS na_count FROM cleaned WHERE phone = 'N/A'
)
SELECT 
    'Test_Phone_COALESCE_Default' AS test_name,
    CASE WHEN na_count = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '1' AS expected_value,
    CAST(na_count AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 6: COALESCE default values for address
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS address, NULL AS city, NULL AS state
),
cleaned AS (
    SELECT 
        COALESCE(address, 'Unknown') AS address,
        COALESCE(city, 'Unknown') AS city,
        COALESCE(state, 'Unknown') AS state
    FROM test_data
),
result AS (
    SELECT address, city, state FROM cleaned
)
SELECT 
    'Test_Address_COALESCE_Defaults' AS test_name,
    CASE WHEN address = 'Unknown' AND city = 'Unknown' AND state = 'Unknown' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Unknown|Unknown|Unknown' AS expected_value,
    address || '|' || city || '|' || state AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 7: COALESCE default country to USA
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS country
),
cleaned AS (
    SELECT COALESCE(country, 'USA') AS country FROM test_data
),
result AS (
    SELECT country FROM cleaned
)
SELECT 
    'Test_Country_COALESCE_USA' AS test_name,
    CASE WHEN country = 'USA' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'USA' AS expected_value,
    country AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 8: COALESCE default gender
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS gender
),
cleaned AS (
    SELECT COALESCE(gender, 'Unknown') AS gender FROM test_data
),
result AS (
    SELECT gender FROM cleaned
)
SELECT 
    'Test_Gender_COALESCE_Unknown' AS test_name,
    CASE WHEN gender = 'Unknown' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Unknown' AS expected_value,
    gender AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 9: COALESCE default income_bracket
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS income_bracket
),
cleaned AS (
    SELECT COALESCE(income_bracket, 'Not Specified') AS income_bracket FROM test_data
),
result AS (
    SELECT income_bracket FROM cleaned
)
SELECT 
    'Test_Income_Bracket_COALESCE' AS test_name,
    CASE WHEN income_bracket = 'Not Specified' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Not Specified' AS expected_value,
    income_bracket AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 10: COALESCE default customer_segment
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT NULL AS customer_segment
),
cleaned AS (
    SELECT COALESCE(customer_segment, 'Standard') AS customer_segment FROM test_data
),
result AS (
    SELECT customer_segment FROM cleaned
)
SELECT 
    'Test_Customer_Segment_COALESCE' AS test_name,
    CASE WHEN customer_segment = 'Standard' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Standard' AS expected_value,
    customer_segment AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 11: Age calculation from birth_date
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT CAST('1990-01-01' AS DATE) AS birth_date
),
calculated AS (
    SELECT CAST((CURRENT_DATE - birth_date) AS FLOAT) / 365.0 AS age FROM test_data
),
result AS (
    SELECT age FROM calculated
)
SELECT 
    'Test_Age_Calculation' AS test_name,
    CASE WHEN age >= 30 AND age <= 40 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '30-40' AS expected_value,
    CAST(ROUND(age, 1) AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 12: Days as customer calculation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT CAST(CURRENT_DATE - INTERVAL '100' DAY AS DATE) AS signup_date
),
calculated AS (
    SELECT CAST((CURRENT_DATE - signup_date) AS INT) AS days_as_customer FROM test_data
),
result AS (
    SELECT days_as_customer FROM calculated
)
SELECT 
    'Test_Days_As_Customer_Calculation' AS test_name,
    CASE WHEN days_as_customer >= 95 AND days_as_customer <= 105 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '100' AS expected_value,
    CAST(days_as_customer AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 13: Orders filtered by 365 day window
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS order_id, CAST(CURRENT_DATE - INTERVAL '30' DAY AS DATE) AS order_date
    UNION ALL
    SELECT 2 AS order_id, CAST(CURRENT_DATE - INTERVAL '400' DAY AS DATE) AS order_date
    UNION ALL
    SELECT 3 AS order_id, CAST(CURRENT_DATE - INTERVAL '200' DAY AS DATE) AS order_date
),
filtered AS (
    SELECT * FROM test_data WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
),
result AS (
    SELECT COUNT(*) AS cnt FROM filtered
)
SELECT 
    'Test_Orders_365_Day_Filter' AS test_name,
    CASE WHEN cnt = 2 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2' AS expected_value,
    CAST(cnt AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 14: Customer order summary aggregation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, CAST('2023-01-01' AS DATE) AS order_date
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, CAST('2023-02-01' AS DATE) AS order_date
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, CAST('2023-03-01' AS DATE) AS order_date
),
summary AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date
    FROM test_data
    GROUP BY customer_id
),
result AS (
    SELECT total_orders FROM summary
)
SELECT 
    'Test_Customer_Order_Summary' AS test_name,
    CASE WHEN total_orders = 3 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '3' AS expected_value,
    CAST(total_orders AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 15: Completed orders filtering and aggregation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, 'COMPLETED' AS status, 100.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, 'COMPLETED' AS status, 200.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, 'CANCELLED' AS status, 50.00 AS total_amount
),
completed AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS completed_orders,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value
    FROM test_data
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
),
result AS (
    SELECT completed_orders, total_revenue, avg_order_value FROM completed
)
SELECT 
    'Test_Completed_Orders_Aggregation' AS test_name,
    CASE WHEN completed_orders = 2 AND total_revenue = 300.00 AND avg_order_value = 150.00 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2|300.00|150.00' AS expected_value,
    CAST(completed_orders AS VARCHAR) || '|' || CAST(total_revenue AS VARCHAR) || '|' || CAST(avg_order_value AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 16: Cancelled orders count
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, 'CANCELLED' AS status
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, 'CANCELLED' AS status
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, 'COMPLETED' AS status
),
cancelled AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
    FROM test_data
    WHERE status = 'CANCELLED'
    GROUP BY customer_id
),
result AS (
    SELECT cancelled_orders FROM cancelled
)
SELECT 
    'Test_Cancelled_Orders_Count' AS test_name,
    CASE WHEN cancelled_orders = 2 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2' AS expected_value,
    CAST(cancelled_orders AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 17: Returned orders count
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, 'RETURNED' AS status
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, 'COMPLETED' AS status
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, 'RETURNED' AS status
),
returned AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
    FROM test_data
    WHERE status = 'RETURNED'
    GROUP BY customer_id
),
result AS (
    SELECT returned_orders FROM returned
)
SELECT 
    'Test_Returned_Orders_Count' AS test_name,
    CASE WHEN returned_orders = 2 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2' AS expected_value,
    CAST(returned_orders AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 18: Revenue last 30 days calculation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, CAST(CURRENT_DATE - INTERVAL '10' DAY AS DATE) AS order_date, 100.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, CAST(CURRENT_DATE - INTERVAL '20' DAY AS DATE) AS order_date, 200.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, CAST(CURRENT_DATE - INTERVAL '40' DAY AS DATE) AS order_date, 300.00 AS total_amount
),
revenue_30 AS (
    SELECT customer_id, 
        SUM(total_amount) AS revenue_last_30_days,
        COUNT(DISTINCT order_id) AS orders_last_30_days
    FROM test_data
    WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
    GROUP BY customer_id
),
result AS (
    SELECT revenue_last_30_days, orders_last_30_days FROM revenue_30
)
SELECT 
    'Test_Revenue_Last_30_Days' AS test_name,
    CASE WHEN revenue_last_30_days = 300.00 AND orders_last_30_days = 2 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '300.00|2' AS expected_value,
    CAST(revenue_last_30_days AS VARCHAR) || '|' || CAST(orders_last_30_days AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 19: Revenue last 90 days calculation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH test_data AS (
    SELECT 1 AS customer_id, 1 AS order_id, CAST(CURRENT_DATE - INTERVAL '30' DAY AS DATE) AS order_date, 100.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 2 AS order_id, CAST(CURRENT_DATE - INTERVAL '60' DAY AS DATE) AS order_date, 200.00 AS total_amount
    UNION ALL
    SELECT 1 AS customer_id, 3 AS order_id, CAST(CURRENT_DATE - INTERVAL '100' DAY AS DATE) AS order_date, 300.00 AS total_amount
),
revenue_90 AS (
    SELECT customer_id, SUM(total_amount) AS revenue_last_90_days
    FROM test_data
    WHERE order_date >= CURRENT_DATE - INTERVAL '90' DAY
    GROUP BY customer_id
),
result AS (
    SELECT revenue_last_90_days FROM revenue_90
)
SELECT 
    'Test_Revenue_Last_90_Days' AS test_name,
    CASE WHEN revenue_last_90_days = 300.00 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '300.00' AS expected_value,
    CAST(revenue_last_90_days AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 20: Customer orders LEFT JOIN with COALESCE
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH customer_summary AS (
    SELECT 1 AS customer_id, 5 AS total_orders
),
completed_orders AS (
    SELECT 1 AS customer_id, 3 AS completed_orders, 500.00 AS total_revenue
),
cancelled_orders AS (
    SELECT 1 AS customer_id, 1 AS cancelled_orders
),
customer_orders AS (
    SELECT 
        cos.customer_id,
        cos.total_orders,
        COALESCE(co.completed_orders, 0) AS completed_orders,
        COALESCE(co.total_revenue, 0) AS lifetime_revenue,
        COALESCE(can.cancelled_orders, 0) AS cancelled_orders
    FROM customer_summary cos
    LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    LEFT JOIN cancelled_orders can ON cos.customer_id = can.customer_id
),
result AS (
    SELECT total_orders, completed_orders, lifetime_revenue, cancelled_orders FROM customer_orders
)
SELECT 
    'Test_Customer_Orders_LEFT_JOIN' AS test_name,
    CASE WHEN total_orders = 5 AND completed_orders = 3 AND lifetime_revenue = 500.00 AND cancelled_orders = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '5|3|500.00|1' AS expected_value,
    CAST(total_orders AS VARCHAR) || '|' || CAST(completed_orders AS VARCHAR) || '|' || CAST(lifetime_revenue AS VARCHAR) || '|' || CAST(cancelled_orders AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 21: Customer orders with no orders (COALESCE to 0)
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH customer_summary AS (
    SELECT 1 AS customer_id, 0 AS total_orders
),
customer_orders AS (
    SELECT 
        cos.customer_id,
        COALESCE(cos.total_orders, 0) AS total_orders,
        COALESCE(NULL, 0) AS completed_orders,
        COALESCE(NULL, 0) AS lifetime_revenue
    FROM customer_summary cos
),
result AS (
    SELECT total_orders, completed_orders, lifetime_revenue FROM customer_orders
)
SELECT 
    'Test_No_Orders_COALESCE_Zero' AS test_name,
    CASE WHEN total_orders = 0 AND completed_orders = 0 AND lifetime_revenue = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '0|0|0' AS expected_value,
    CAST(total_orders AS VARCHAR) || '|' || CAST(completed_orders AS VARCHAR) || '|' || CAST(lifetime_revenue AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 22: Completed order items JOIN
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH order_items AS (
    SELECT 1 AS order_item_id, 1 AS order_id, 101 AS product_id, 2 AS quantity, 50.00 AS unit_price
    UNION ALL
    SELECT 2 AS order_item_id, 2 AS order_id, 102 AS product_id, 1 AS quantity, 100.00 AS unit_price
),
orders AS (
    SELECT 1 AS order_id, 1 AS customer_id, 'COMPLETED' AS status
    UNION ALL
    SELECT 2 AS order_id, 1 AS customer_id, 'CANCELLED' AS status
),
completed_order_items AS (
    SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price, o.customer_id
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'COMPLETED'
),
result AS (
    SELECT COUNT(*) AS cnt FROM completed_order_items
)
SELECT 
    'Test_Completed_Order_Items_JOIN' AS test_name,
    CASE WHEN cnt = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '1' AS expected_value,
    CAST(cnt AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 23: Category spend calculation
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH order_items AS (
    SELECT 1 AS order_item_id, 1 AS order_id, 101 AS product_id, 2 AS quantity, 50.00 AS unit_price, 1 AS customer_id
    UNION ALL
    SELECT 2 AS order_item_id, 1 AS order_id, 102 AS product_id, 3 AS quantity, 30.00 AS unit_price, 1 AS customer_id
),
products AS (
    SELECT 101 AS product_id, 'Electronics' AS category
    UNION ALL
    SELECT 102 AS product_id, 'Electronics' AS category
),
category_spend AS (
    SELECT 
        oi.customer_id,
        p.category,
        COUNT(DISTINCT oi.order_item_id) AS items_purchased,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.quantity * oi.unit_price) AS category_spend
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY oi.customer_id, p.category
),
result AS (
    SELECT items_purchased, total_quantity, category_spend FROM category_spend
)
SELECT 
    'Test_Category_Spend_Calculation' AS test_name,
    CASE WHEN items_purchased = 2 AND total_quantity = 5 AND category_spend = 190.00 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    '2|5|190.00' AS expected_value,
    CAST(items_purchased AS VARCHAR) || '|' || CAST(total_quantity AS VARCHAR) || '|' || CAST(category_spend AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 24: Ranked categories by spend
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH category_spend AS (
    SELECT 1 AS customer_id, 'Electronics' AS category, 500.00 AS category_spend
    UNION ALL
    SELECT 1 AS customer_id, 'Clothing' AS category, 300.00 AS category_spend
    UNION ALL
    SELECT 1 AS customer_id, 'Books' AS category, 100.00 AS category_spend
),
ranked_categories AS (
    SELECT 
        customer_id,
        category,
        category_spend,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
    FROM category_spend
),
result AS (
    SELECT category, category_rank FROM ranked_categories WHERE category_rank = 1
)
SELECT 
    'Test_Ranked_Categories_By_Spend' AS test_name,
    CASE WHEN category = 'Electronics' AND category_rank = 1 THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Electronics|1' AS expected_value,
    category || '|' || CAST(category_rank AS VARCHAR) AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 25: Top 3 categories pivot
INSERT INTO test_results (test_name, test_status, expected_value, actual_value, test_timestamp)
WITH ranked_categories AS (
    SELECT 1 AS customer_id, 'Electronics' AS category, 500.00 AS category_spend, 1 AS category_rank
    UNION ALL
    SELECT 1 AS customer_id, 'Clothing' AS category, 300.00 AS category_spend, 2 AS category_rank
    UNION ALL
    SELECT 1 AS customer_id, 'Books' AS category, 100.00 AS category_spend, 3 AS category_rank
),
top_categories AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN category_rank = 1 THEN category END) AS top_category_1,
        MAX(CASE WHEN category_rank = 1 THEN category_spend END) AS top_category_1_spend,
        MAX(CASE WHEN category_rank = 2 THEN category END) AS top_category_2,
        MAX(CASE WHEN category_rank = 2 THEN category_spend END) AS top_category_2_spend,
        MAX(CASE WHEN category_rank = 3 THEN category END) AS top_category_3,
        MAX(CASE WHEN category_rank = 3 THEN category_spend END) AS top_category_3_spend
    FROM ranked_categories
    WHERE category_rank <= 3
    GROUP BY customer_id
),
result AS (
    SELECT top_category_1, top_category_2, top_category_3 FROM top_categories
)
SELECT 
    'Test_Top_3_Categories_Pivot' AS test_name,
    CASE WHEN top_category_1 = 'Electronics' AND top_category_2 = 'Clothing' AND top_category_3 = 'Books' THEN 'PASS' ELSE 'FAIL' END AS test_status,
    'Electronics|Clothing|Books' AS expected_value,
    top_category_1 || '|' || top_category_2 || '|' || top_category_3 AS actual_value,
    CURRENT_TIMESTAMP AS test_timestamp
FROM result;

-- Test 26: RFM base calculation
INSERT
