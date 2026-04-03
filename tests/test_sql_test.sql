-- =====================================================
-- COMPLETE SQL UNIT TEST SUITE
-- Testing Framework: SQL Unit Testing with Assertions
-- =====================================================

-- Setup: Create test schema and tables
CREATE SCHEMA IF NOT EXISTS test_schema;
SET SCHEMA test_schema;

-- Drop existing test tables
DROP TABLE IF EXISTS raw_customers CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS test_results CASCADE;

-- Create test results table
CREATE TABLE test_results (
    test_id INTEGER PRIMARY KEY,
    test_name VARCHAR(200),
    test_status VARCHAR(20),
    expected_value VARCHAR(500),
    actual_value VARCHAR(500),
    test_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create base tables for testing
CREATE TABLE raw_customers (
    customer_id INTEGER,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(200),
    phone VARCHAR(50),
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(50),
    birth_date DATE,
    gender VARCHAR(20),
    income_bracket VARCHAR(50),
    customer_segment VARCHAR(50),
    signup_date DATE
);

CREATE TABLE orders (
    order_id INTEGER,
    customer_id INTEGER,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

CREATE TABLE order_items (
    order_item_id INTEGER,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(10,2)
);

CREATE TABLE products (
    product_id INTEGER,
    product_name VARCHAR(200),
    category VARCHAR(100)
);

-- =====================================================
-- TEST 1: Deduplication Logic - Email Duplicates
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (2, 'John', 'Doe', 'john@test.com', '555-0002', '456 Oak Ave', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-06-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        1,
        'TEST_DEDUPLICATION_EMAIL',
        CASE WHEN customer_count = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(customer_count AS VARCHAR)
    FROM (
        SELECT COUNT(*) as customer_count
        FROM (
            WITH deduplicated_customers AS (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
                FROM raw_customers
                WHERE email IS NOT NULL AND customer_id IS NOT NULL
            )
            SELECT * FROM deduplicated_customers WHERE row_num = 1
        ) t
    ) result;
COMMIT;

-- =====================================================
-- TEST 2: Null Email Filtering
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'Jane', 'Smith', NULL, '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1990-05-20', 'Female', '75-100K', 'Standard', DATE '2023-01-01'),
        (2, 'Bob', 'Jones', 'bob@test.com', '555-0002', '456 Oak Ave', 'Boston', 'MA', 'USA', 
         DATE '1988-03-10', 'Male', '50-75K', 'Premium', DATE '2023-02-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        2,
        'TEST_NULL_EMAIL_FILTER',
        CASE WHEN customer_count = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(customer_count AS VARCHAR)
    FROM (
        SELECT COUNT(*) as customer_count
        FROM (
            SELECT * FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
        ) t
    ) result;
COMMIT;

-- =====================================================
-- TEST 3: Data Cleaning - UPPER/LOWER/TRIM
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, '  john  ', '  doe  ', '  JOHN@TEST.COM  ', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        3,
        'TEST_DATA_CLEANING',
        CASE WHEN first_name = 'JOHN' AND last_name = 'DOE' AND email = 'john@test.com' 
             THEN 'PASS' ELSE 'FAIL' END,
        'JOHN|DOE|john@test.com',
        first_name || '|' || last_name || '|' || email
    FROM (
        SELECT 
            UPPER(TRIM(first_name)) AS first_name,
            UPPER(TRIM(last_name)) AS last_name,
            LOWER(TRIM(email)) AS email
        FROM raw_customers
        WHERE customer_id = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 4: COALESCE Default Values
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', NULL, NULL, NULL, NULL, NULL, 
         DATE '1985-01-15', NULL, NULL, NULL, DATE '2023-01-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        4,
        'TEST_COALESCE_DEFAULTS',
        CASE WHEN phone = 'N/A' AND city = 'Unknown' AND country = 'USA' 
                  AND gender = 'Unknown' AND income_bracket = 'Not Specified' 
                  AND customer_segment = 'Standard'
             THEN 'PASS' ELSE 'FAIL' END,
        'N/A|Unknown|USA|Unknown|Not Specified|Standard',
        phone || '|' || city || '|' || country || '|' || gender || '|' || income_bracket || '|' || customer_segment
    FROM (
        SELECT 
            COALESCE(phone, 'N/A') AS phone,
            COALESCE(city, 'Unknown') AS city,
            COALESCE(country, 'USA') AS country,
            COALESCE(gender, 'Unknown') AS gender,
            COALESCE(income_bracket, 'Not Specified') AS income_bracket,
            COALESCE(customer_segment, 'Standard') AS customer_segment
        FROM raw_customers
        WHERE customer_id = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 5: Age Calculation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         CURRENT_DATE - INTERVAL '30' YEAR, 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        5,
        'TEST_AGE_CALCULATION',
        CASE WHEN age >= 29 AND age <= 31 THEN 'PASS' ELSE 'FAIL' END,
        '30',
        CAST(ROUND(age, 0) AS VARCHAR)
    FROM (
        SELECT (CURRENT_DATE - birth_date) / 365.0 AS age
        FROM raw_customers
        WHERE customer_id = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 6: Order Filtering - Last 365 Days
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '400' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        6,
        'TEST_ORDER_DATE_FILTER',
        CASE WHEN order_count = 2 THEN 'PASS' ELSE 'FAIL' END,
        '2',
        CAST(order_count AS VARCHAR)
    FROM (
        SELECT COUNT(*) as order_count
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 7: Order Status Aggregation - COMPLETED
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        7,
        'TEST_COMPLETED_ORDERS',
        CASE WHEN completed_count = 2 AND total_rev = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '2|300.00',
        CAST(completed_count AS VARCHAR) || '|' || CAST(total_rev AS VARCHAR)
    FROM (
        SELECT 
            COUNT(DISTINCT order_id) AS completed_count,
            SUM(total_amount) AS total_rev
        FROM orders
        WHERE status = 'COMPLETED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 8: Order Status Aggregation - CANCELLED
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'CANCELLED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        8,
        'TEST_CANCELLED_ORDERS',
        CASE WHEN cancelled_count = 2 THEN 'PASS' ELSE 'FAIL' END,
        '2',
        CAST(cancelled_count AS VARCHAR)
    FROM (
        SELECT COUNT(DISTINCT order_id) AS cancelled_count
        FROM orders
        WHERE status = 'CANCELLED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 9: Order Status Aggregation - RETURNED
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'RETURNED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'RETURNED', 150.00),
        (4, 1, CURRENT_DATE - INTERVAL '120' DAY, 'RETURNED', 175.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        9,
        'TEST_RETURNED_ORDERS',
        CASE WHEN returned_count = 3 THEN 'PASS' ELSE 'FAIL' END,
        '3',
        CAST(returned_count AS VARCHAR)
    FROM (
        SELECT COUNT(DISTINCT order_id) AS returned_count
        FROM orders
        WHERE status = 'RETURNED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 10: Revenue Last 30 Days
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '40' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        10,
        'TEST_REVENUE_LAST_30_DAYS',
        CASE WHEN revenue_30 = 300.00 AND order_count_30 = 2 THEN 'PASS' ELSE 'FAIL' END,
        '300.00|2',
        CAST(revenue_30 AS VARCHAR) || '|' || CAST(order_count_30 AS VARCHAR)
    FROM (
        SELECT 
            SUM(total_amount) AS revenue_30,
            COUNT(DISTINCT order_id) AS order_count_30
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 11: Revenue Last 90 Days
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        11,
        'TEST_REVENUE_LAST_90_DAYS',
        CASE WHEN revenue_90 = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '300.00',
        CAST(revenue_90 AS VARCHAR)
    FROM (
        SELECT SUM(total_amount) AS revenue_90
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '90' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 12: Average Order Value Calculation
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        12,
        'TEST_AVG_ORDER_VALUE',
        CASE WHEN ABS(avg_val - 150.00) < 0.01 THEN 'PASS' ELSE 'FAIL' END,
        '150.00',
        CAST(avg_val AS VARCHAR)
    FROM (
        SELECT AVG(total_amount) AS avg_val
        FROM orders
        WHERE status = 'COMPLETED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 13: Category Spend Aggregation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Electronics'),
        (3, 'Product C', 'Clothing');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 2, 50.00),
        (2, 1, 2, 1, 100.00),
        (3, 1, 3, 2, 50.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        13,
        'TEST_CATEGORY_SPEND',
        CASE WHEN electronics_spend = 200.00 AND clothing_spend = 100.00 THEN 'PASS' ELSE 'FAIL' END,
        '200.00|100.00',
        CAST(electronics_spend AS VARCHAR) || '|' || CAST(clothing_spend AS VARCHAR)
    FROM (
        SELECT 
            SUM(CASE WHEN p.category = 'Electronics' THEN oi.quantity * oi.unit_price ELSE 0 END) AS electronics_spend,
            SUM(CASE WHEN p.category = 'Clothing' THEN oi.quantity * oi.unit_price ELSE 0 END) AS clothing_spend
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE o.status = 'COMPLETED'
    ) t;
COMMIT;

-- =====================================================
-- TEST 14: Top Category Ranking - ROW_NUMBER
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 500.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing'),
        (3, 'Product C', 'Books');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 1, 300.00),
        (2, 1, 2, 1, 150.00),
        (3, 1, 3, 1, 50.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        14,
        'TEST_TOP_CATEGORY_RANKING',
        CASE WHEN top_cat = 'Electronics' AND rank_num = 1 THEN 'PASS' ELSE 'FAIL' END,
        'Electronics|1',
        top_cat || '|' || CAST(rank_num AS VARCHAR)
    FROM (
        SELECT category AS top_cat, category_rank AS rank_num
        FROM (
            SELECT 
                p.category,
                SUM(oi.quantity * oi.unit_price) AS category_spend,
                ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS category_rank
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.order_id
            JOIN products p ON oi.product_id = p.product_id
            WHERE o.status = 'COMPLETED'
            GROUP BY o.customer_id, p.category
        ) ranked
        WHERE category_rank = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 15: RFM Recency Calculation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        15,
        'TEST_RFM_RECENCY',
        CASE WHEN recency_days = 10 THEN 'PASS' ELSE 'FAIL' END,
        '10',
        CAST(recency_days AS VARCHAR)
    FROM (
        SELECT CURRENT_DATE - MAX(order_date) AS recency_days
        FROM orders
        WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 16: RFM Frequency Calculation
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        16,
        'TEST_RFM_FREQUENCY',
        CASE WHEN frequency = 3 THEN 'PASS' ELSE 'FAIL' END,
        '3',
        CAST(frequency AS VARCHAR)
    FROM (
        SELECT COUNT(DISTINCT order_id) AS frequency
        FROM orders
        WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 17: RFM Monetary Calculation
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        17,
        'TEST_RFM_MONETARY',
        CASE WHEN monetary = 450.00 THEN 'PASS' ELSE 'FAIL' END,
        '450.00',
        CAST(monetary AS VARCHAR)
    FROM (
        SELECT SUM(total_amount) AS monetary
        FROM orders
        WHERE customer_id = 1 AND status = 'COMPLETED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 18: NTILE Scoring (5 Buckets)
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Customer1', 'Test', 'c1@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (2, 'Customer2', 'Test', 'c2@test.com', '555-0002', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (3, 'Customer3', 'Test', 'c3@test.com', '555-0003', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (4, 'Customer4', 'Test', 'c4@test.com', '555-0004', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (5, 'Customer5', 'Test', 'c5@test.com', '555-0005', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 2, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 3, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00),
        (4, 4, CURRENT_DATE - INTERVAL '40' DAY, 'COMPLETED', 400.00),
        (5, 5, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 500.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        18,
        'TEST_NTILE_SCORING',
        CASE WHEN min_score = 1 AND max_score = 5 THEN 'PASS' ELSE 'FAIL' END,
        '1|5',
        CAST(min_score AS VARCHAR) || '|' || CAST(max_score AS VARCHAR)
    FROM (
        SELECT MIN(monetary_score) AS min_score, MAX(monetary_score) AS max_score
        FROM (
            SELECT 
                customer_id,
                SUM(total_amount) AS monetary,
                NTILE(5) OVER (ORDER BY SUM(total_amount) ASC) AS monetary_score
            FROM orders
            WHERE status = 'COMPLETED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
            GROUP BY customer_id
        ) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 19: RFM Segment - Champions
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 1000.00),
        (2, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 1000.00),
        (3, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 1000.00),
        (4, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 1000.00),
        (5, 1, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 1000.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        19,
        'TEST_RFM_SEGMENT_CHAMPIONS',
        CASE WHEN rfm_segment = 'Champions' THEN 'PASS' ELSE 'FAIL' END,
        'Champions',
        rfm_segment
    FROM (
        SELECT 
            CASE
                WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
                WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal Customers'
                ELSE 'Others'
            END AS rfm_segment
        FROM (
            SELECT 
                5 AS recency_score,
                5 AS frequency_score,
                5 AS monetary_score
        ) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 20: RFM Segment - At Risk
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        20,
        'TEST_RFM_SEGMENT_AT_RISK',
        CASE WHEN rfm_segment = 'At Risk' THEN 'PASS' ELSE 'FAIL' END,
        'At Risk',
        rfm_segment
    FROM (
        SELECT 
            CASE
                WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
                WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
                ELSE 'Others'
            END AS rfm_segment
        FROM (
            SELECT 
                1 AS recency_score,
                5 AS frequency_score,
                3 AS monetary_score
        ) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 21: RFM Segment - Lost
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        21,
        'TEST_RFM_SEGMENT_LOST',
        CASE WHEN rfm_segment = 'Lost' THEN 'PASS' ELSE 'FAIL' END,
        'Lost',
        rfm_segment
    FROM (
        SELECT 
            CASE
                WHEN recency_score <= 1 AND frequency_score <= 1 THEN 'Lost'
                ELSE 'Others'
            END AS rfm_segment
        FROM (
            SELECT 
                1 AS recency_score,
                1 AS frequency_score,
                1 AS monetary_score
        ) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 22: CLV - Purchase Frequency Annual
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365' DAY);
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '300' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '200' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 150.00),
        (4, 1, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 175.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        22,
        'TEST_CLV_PURCHASE_FREQUENCY',
        CASE WHEN purchase_freq >= 5.0 AND purchase_freq <= 7.0 THEN 'PASS' ELSE 'FAIL' END,
        '~6.0',
        CAST(ROUND(purchase_freq, 1) AS VARCHAR)
    FROM (
        SELECT 
            CASE 
                WHEN customer_lifespan_days > 0 THEN total_orders * 365.0 / customer_lifespan_days
                ELSE total_orders
            END AS purchase_freq
        FROM (
            SELECT 
                COUNT(DISTINCT order_id) AS total_orders,
                MAX(order_date) - MIN(order_date) AS customer_lifespan_days
            FROM orders
            WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ) base
    ) t;
COMMIT;

-- =====================================================
-- TEST 23: CLV - 3 Year Estimation
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        23,
        'TEST_CLV_3YR_ESTIMATION',
        CASE WHEN clv_3yr = 1800.00 THEN 'PASS' ELSE 'FAIL' END,
        '1800.00',
        CAST(clv_3yr AS VARCHAR)
    FROM (
        SELECT ROUND(100.00 * 6.0 * 3, 2) AS clv_3yr
    ) t;
COMMIT;

-- =====================================================
-- TEST 24: PERCENT_RANK Calculation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Customer1', 'Test', 'c1@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (2, 'Customer2', 'Test', 'c2@test.com', '555-0002', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (3, 'Customer3', 'Test', 'c3@test.com', '555-0003', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 2, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 3, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        24,
        'TEST_PERCENT_RANK',
        CASE WHEN min_rank = 0.0 AND max_rank = 1.0 THEN 'PASS' ELSE 'FAIL' END,
        '0.0|1.0',
        CAST(min_rank AS VARCHAR) || '|' || CAST(max_rank AS VARCHAR)
    FROM (
        SELECT MIN(revenue_percentile) AS min_rank, MAX(revenue_percentile) AS max_rank
        FROM (
            SELECT 
                customer_id,
                SUM(total_amount) AS lifetime_revenue,
                PERCENT_RANK() OVER (ORDER BY SUM(total_amount)) AS revenue_percentile
            FROM orders
            WHERE status = 'COMPLETED' AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
            GROUP BY customer_id
        ) ranks
    ) t;
COMMIT;

-- =====================================================
-- TEST 25: Customer Tier - Platinum
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        25,
        'TEST_CUSTOMER_TIER_PLATINUM',
        CASE WHEN customer_tier = 'Platinum' THEN 'PASS' ELSE 'FAIL' END,
        'Platinum',
        customer_tier
    FROM (
        SELECT 
            CASE
                WHEN clv_percentile >= 0.9 THEN 'Platinum'
                WHEN clv_percentile >= 0.7 THEN 'Gold'
                WHEN clv_percentile >= 0.4 THEN 'Silver'
                ELSE 'Bronze'
            END AS customer_tier
        FROM (SELECT 0.95 AS clv_percentile) t
    ) tier;
COMMIT;

-- =====================================================
-- TEST 26: Customer Tier - Gold
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        26,
        'TEST_CUSTOMER_TIER_GOLD',
        CASE WHEN customer_tier = 'Gold' THEN 'PASS' ELSE 'FAIL' END,
        'Gold',
        customer_tier
    FROM (
        SELECT 
            CASE
                WHEN clv_percentile >= 0.9 THEN 'Platinum'
                WHEN clv_percentile >= 0.7 THEN 'Gold'
                WHEN clv_percentile >= 0.4 THEN 'Silver'
                ELSE 'Bronze'
            END AS customer_tier
        FROM (SELECT 0.75 AS clv_percentile) t
    ) tier;
COMMIT;

-- =====================================================
-- TEST 27: Customer Tier - Silver
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        27,
        'TEST_CUSTOMER_TIER_SILVER',
        CASE WHEN customer_tier = 'Silver' THEN 'PASS' ELSE 'FAIL' END,
        'Silver',
        customer_tier
    FROM (
        SELECT 
            CASE
                WHEN clv_percentile >= 0.9 THEN 'Platinum'
                WHEN clv_percentile >= 0.7 THEN 'Gold'
                WHEN clv_percentile >= 0.4 THEN 'Silver'
                ELSE 'Bronze'
            END AS customer_tier
        FROM (SELECT 0.50 AS clv_percentile) t
    ) tier;
COMMIT;

-- =====================================================
-- TEST 28: Customer Tier - Bronze
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        28,
        'TEST_CUSTOMER_TIER_BRONZE',
        CASE WHEN customer_tier = 'Bronze' THEN 'PASS' ELSE 'FAIL' END,
        'Bronze',
        customer_tier
    FROM (
        SELECT 
            CASE
                WHEN clv_percentile >= 0.9 THEN 'Platinum'
                WHEN clv_percentile >= 0.7 THEN 'Gold'
                WHEN clv_percentile >= 0.4 THEN 'Silver'
                ELSE 'Bronze'
            END AS customer_tier
        FROM (SELECT 0.20 AS clv_percentile) t
    ) tier;
COMMIT;

-- =====================================================
-- TEST 29: Churn Risk - High Risk
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        29,
        'TEST_CHURN_RISK_HIGH',
        CASE WHEN churn_risk = 'High Risk' THEN 'PASS' ELSE 'FAIL' END,
        'High Risk',
        churn_risk
    FROM (
        SELECT 
            CASE
                WHEN days_since_last_order IS NULL THEN 'Active'
                WHEN days_since_last_order > 180 THEN 'High Risk'
                WHEN days_since_last_order > 90 THEN 'Medium Risk'
                WHEN days_since_last_order > 30 THEN 'Low Risk'
                ELSE 'Active'
            END AS churn_risk
        FROM (SELECT 200 AS days_since_last_order) t
    ) risk;
COMMIT;

-- =====================================================
-- TEST 30: Churn Risk - Medium Risk
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        30,
        'TEST_CHURN_RISK_MEDIUM',
        CASE WHEN churn_risk = 'Medium Risk' THEN 'PASS' ELSE 'FAIL' END,
        'Medium Risk',
        churn_risk
    FROM (
        SELECT 
            CASE
                WHEN days_since_last_order IS NULL THEN 'Active'
                WHEN days_since_last_order > 180 THEN 'High Risk'
                WHEN days_since_last_order > 90 THEN 'Medium Risk'
                WHEN days_since_last_order > 30 THEN 'Low Risk'
                ELSE 'Active'
            END AS churn_risk
        FROM (SELECT 100 AS days_since_last_order) t
    ) risk;
COMMIT;

-- =====================================================
-- TEST 31: Churn Risk - Low Risk
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        31,
        'TEST_CHURN_RISK_LOW',
        CASE WHEN churn_risk = 'Low Risk' THEN 'PASS' ELSE 'FAIL' END,
        'Low Risk',
        churn_risk
    FROM (
        SELECT 
            CASE
                WHEN days_since_last_order IS NULL THEN 'Active'
                WHEN days_since_last_order > 180 THEN 'High Risk'
                WHEN days_since_last_order > 90 THEN 'Medium Risk'
                WHEN days_since_last_order > 30 THEN 'Low Risk'
                ELSE 'Active'
            END AS churn_risk
        FROM (SELECT 50 AS days_since_last_order) t
    ) risk;
COMMIT;

-- =====================================================
-- TEST 32: Churn Risk - Active
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        32,
        'TEST_CHURN_RISK_ACTIVE',
        CASE WHEN churn_risk = 'Active' THEN 'PASS' ELSE 'FAIL' END,
        'Active',
        churn_risk
    FROM (
        SELECT 
            CASE
                WHEN days_since_last_order IS NULL THEN 'Active'
                WHEN days_since_last_order > 180 THEN 'High Risk'
                WHEN days_since_last_order > 90 THEN 'Medium Risk'
                WHEN days_since_last_order > 30 THEN 'Low Risk'
                ELSE 'Active'
            END AS churn_risk
        FROM (SELECT 10 AS days_since_last_order) t
    ) risk;
COMMIT;

-- =====================================================
-- TEST 33: LEFT JOIN Behavior - No Orders
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        33,
        'TEST_LEFT_JOIN_NO_ORDERS',
        CASE WHEN total_orders = 0 AND lifetime_revenue = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0|0',
        CAST(total_orders AS VARCHAR) || '|' || CAST(lifetime_revenue AS VARCHAR)
    FROM (
        SELECT 
            COALESCE(COUNT(DISTINCT o.order_id), 0) AS total_orders,
            COALESCE(SUM(o.total_amount), 0) AS lifetime_revenue
        FROM raw_customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id 
            AND o.status = 'COMPLETED' 
            AND o.order_date >= CURRENT_DATE - INTERVAL '365' DAY
        WHERE c.customer_id = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 34: NULLS LAST in ORDER BY
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Customer1', 'Test', 'c1@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01'),
        (2, 'Customer2', 'Test', 'c2@test.com', '555-0002', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        34,
        'TEST_NULLS_LAST_ORDERING',
        CASE WHEN first_customer_id = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(first_customer_id AS VARCHAR)
    FROM (
        SELECT customer_id AS first_customer_id
        FROM (
            SELECT 
                c.customer_id,
                SUM(o.total_amount) AS lifetime_revenue
            FROM raw_customers c
            LEFT JOIN orders o ON c.customer_id = o.customer_id 
                AND o.status = 'COMPLETED' 
                AND o.order_date >= CURRENT_DATE - INTERVAL '365' DAY
            GROUP BY c.customer_id
            ORDER BY lifetime_revenue DESC NULLS LAST
            LIMIT 1
        ) ordered
    ) t;
COMMIT;

-- =====================================================
-- TEST 35: Edge Case - Zero Division Protection
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        35,
        'TEST_ZERO_DIVISION_PROTECTION',
        CASE WHEN purchase_freq = 5 THEN 'PASS' ELSE 'FAIL' END,
        '5',
        CAST(purchase_freq AS VARCHAR)
    FROM (
        SELECT 
            CASE 
                WHEN customer_lifespan_days > 0 THEN total_orders * 365.0 / customer_lifespan_days
                ELSE total_orders
            END AS purchase_freq
        FROM (
            SELECT 5 AS total_orders, 0 AS customer_lifespan_days
        ) base
    ) t;
COMMIT;

-- =====================================================
-- TEST 36: Edge Case - Negative Days Handling
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', CURRENT_DATE + INTERVAL '10' DAY);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        36,
        'TEST_NEGATIVE_DAYS_FILTER',
        CASE WHEN customer_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0',
        CAST(customer_count AS VARCHAR)
    FROM (
        SELECT COUNT(*) AS customer_count
        FROM raw_customers
        WHERE CURRENT_DATE - signup_date >= 0
            AND signup_date > CURRENT_DATE
    ) t;
COMMIT;

-- =====================================================
-- TEST 37: Multiple Category Purchases
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 600.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing'),
        (3, 'Product C', 'Books');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 1, 300.00),
        (2, 1, 2, 1, 200.00),
        (3, 1, 3, 1, 100.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        37,
        'TEST_MULTIPLE_CATEGORIES',
        CASE WHEN category_count = 3 THEN 'PASS' ELSE 'FAIL' END,
        '3',
        CAST(category_count AS VARCHAR)
    FROM (
        SELECT COUNT(DISTINCT p.category) AS category_count
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE o.customer_id = 1 AND o.status = 'COMPLETED'
    ) t;
COMMIT;

-- =====================================================
-- TEST 38: Top 3 Categories Extraction
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-01-15', 'Male', '50-75K', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 1000.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing'),
        (3, 'Product C', 'Books'),
        (4, 'Product D', 'Sports');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 1, 400.00),
        (2, 1, 2, 1, 300.00),
        (3, 1, 3, 1, 200.00),
        (4, 1, 4, 1, 100.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        38,
        'TEST_TOP_3_CATEGORIES',
        CASE WHEN top_1 = 'Electronics' AND top_2 = 'Clothing' AND top_3 = 'Books' 
             THEN 'PASS' ELSE 'FAIL' END,
        'Electronics|Clothing|Books',
        top_1 || '|' || top_2 || '|' || top_3
    FROM (
        SELECT 
            MAX(CASE WHEN category_rank = 1 THEN category END) AS top_1,
            MAX(CASE WHEN category_rank = 2 THEN category END) AS top_2,
            MAX(CASE WHEN category_rank = 3 THEN category END) AS top_3
        FROM (
            SELECT 
                p.category,
                SUM(oi.quantity * oi.unit_price) AS category_spend,
                ROW_NUMBER() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS category_rank
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.order_id
            JOIN products p ON oi.product_id = p.product_id
            WHERE o.customer_id = 1 AND o.status = 'COMPLETED'
            GROUP BY p.category
        ) ranked
        WHERE category_rank <= 3
    ) t;
COMMIT;

-- =====================================================
-- TEST 39: RFM Cell String Concatenation
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        39,
        'TEST_RFM_CELL_CONCATENATION',
        CASE WHEN rfm_cell = '543' THEN 'PASS' ELSE 'FAIL' END,
        '543',
        rfm_cell
    FROM (
        SELECT 
            CAST(recency_score AS VARCHAR) || CAST(frequency_score AS VARCHAR) || CAST(monetary_score AS VARCHAR) AS rfm_cell
        FROM (
            SELECT 5 AS recency_score, 4 AS frequency_score, 3 AS monetary_score
        ) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 40: RFM Total Score Calculation
-- =====================================================
BEGIN;
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        40,
        'TEST_RFM_TOTAL_SCORE',
        CASE WHEN rfm_total = 12 THEN 'PASS' ELSE 'FAIL' END,
        '12',
        CAST(rfm_total AS VARCHAR)
    FROM (
        SELECT recency_score + frequency_score + monetary_score AS rfm_total
        FROM (SELECT 5 AS recency_score, 4 AS frequency_score, 3 AS monetary_score) scores
    ) t;
COMMIT;

-- =====================================================
-- TEST 41: Days Since Last Order Calculation
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 100.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        41,
        'TEST_DAYS_SINCE_LAST_ORDER',
        CASE WHEN days_since = 25 THEN 'PASS' ELSE 'FAIL' END,
        '25',
        CAST(days_since AS VARCHAR)
    FROM (
        SELECT CURRENT_DATE - MAX(order_date) AS days_since
        FROM orders
        WHERE customer_id = 1
    ) t;
COMMIT;

-- =====================================================
-- TEST 42: First Order Date Tracking
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        42,
        'TEST_FIRST_ORDER_DATE',
        CASE WHEN first_order = CURRENT_DATE - INTERVAL '100' DAY THEN 'PASS' ELSE 'FAIL' END,
        CAST(CURRENT_DATE - INTERVAL '100' DAY AS VARCHAR),
        CAST(first_order AS VARCHAR)
    FROM (
        SELECT MIN(order_date) AS first_order
        FROM orders
        WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 43: Last Order Date Tracking
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 150.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        43,
        'TEST_LAST_ORDER_DATE',
        CASE WHEN last_order = CURRENT_DATE - INTERVAL '25' DAY THEN 'PASS' ELSE 'FAIL' END,
        CAST(CURRENT_DATE - INTERVAL '25' DAY AS VARCHAR),
        CAST(last_order AS VARCHAR)
    FROM (
        SELECT MAX(order_date) AS last_order
        FROM orders
        WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ) t;
COMMIT;

-- =====================================================
-- TEST 44: Customer Lifespan Calculation
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 200.00);
    
    INSERT INTO test_results (test_id, test_name, test_status, expected_value, actual_value)
    SELECT 
        44,
        'TEST_CUSTOMER_LIFESPAN',
        CASE WHEN lifespan = 335 THEN 'PASS' ELSE 'FAIL' END,
        '335',
        CAST(lifespan AS VARCHAR)
    FROM (
        SELECT MAX(order_date) - MIN(order_date) AS life
