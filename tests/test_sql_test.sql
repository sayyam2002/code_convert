-- =====================================================
-- COMPLETE SQL UNIT TEST SUITE
-- Testing Framework: SQL Unit Testing with Assertions
-- =====================================================

-- Setup: Create test schema and tables
CREATE SCHEMA IF NOT EXISTS test_schema;
SET search_path TO test_schema;

-- Drop existing test tables
DROP TABLE IF EXISTS raw_customers CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS test_results CASCADE;

-- Create test results table
CREATE TABLE test_results (
    test_id SERIAL PRIMARY KEY,
    test_name VARCHAR(255),
    test_status VARCHAR(20),
    test_message TEXT,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create base tables for testing
CREATE TABLE raw_customers (
    customer_id INTEGER,
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
    product_name VARCHAR(255),
    category VARCHAR(100)
);

-- =====================================================
-- TEST 1: Deduplication Logic - Email Duplicates
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
    v_test_name VARCHAR(255) := 'TEST_01_Deduplication_Email_Duplicates';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES 
        (1, 'test@example.com', 'John', 'Doe', '2023-01-01'),
        (2, 'test@example.com', 'John', 'Doe', '2023-06-01'),
        (3, 'test@example.com', 'John', 'Doe', '2023-12-01');
    
    -- Execute query and check result
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT COUNT(*) INTO v_count
    FROM deduplicated_customers
    WHERE row_num = 1;
    
    -- Assert
    IF v_count = 1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Correctly deduplicated to 1 record');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 1 record, got ' || v_count);
    END IF;
END $$;

-- =====================================================
-- TEST 2: Deduplication - Most Recent Record Selected
-- =====================================================
DO $$
DECLARE
    v_customer_id INTEGER;
    v_test_name VARCHAR(255) := 'TEST_02_Deduplication_Most_Recent';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES 
        (1, 'test@example.com', 'John', 'Doe', '2023-01-01'),
        (2, 'test@example.com', 'Jane', 'Smith', '2023-12-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT customer_id INTO v_customer_id
    FROM deduplicated_customers
    WHERE row_num = 1;
    
    -- Assert
    IF v_customer_id = 2 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Most recent record selected');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected customer_id 2, got ' || v_customer_id);
    END IF;
END $$;

-- =====================================================
-- TEST 3: NULL Email Filtering
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
    v_test_name VARCHAR(255) := 'TEST_03_NULL_Email_Filtering';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES 
        (1, NULL, 'John', 'Doe', '2023-01-01'),
        (2, 'valid@example.com', 'Jane', 'Smith', '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT COUNT(*) INTO v_count
    FROM deduplicated_customers;
    
    -- Assert
    IF v_count = 1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'NULL emails filtered out');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 1 record, got ' || v_count);
    END IF;
END $$;

-- =====================================================
-- TEST 4: NULL Customer ID Filtering
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
    v_test_name VARCHAR(255) := 'TEST_04_NULL_CustomerID_Filtering';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES 
        (NULL, 'test1@example.com', 'John', 'Doe', '2023-01-01'),
        (2, 'test2@example.com', 'Jane', 'Smith', '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT COUNT(*) INTO v_count
    FROM deduplicated_customers;
    
    -- Assert
    IF v_count = 1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'NULL customer_ids filtered out');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 1 record, got ' || v_count);
    END IF;
END $$;

-- =====================================================
-- TEST 5: Name Cleaning - UPPER and TRIM
-- =====================================================
DO $$
DECLARE
    v_first_name VARCHAR(100);
    v_last_name VARCHAR(100);
    v_test_name VARCHAR(255) := 'TEST_05_Name_Cleaning';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES (1, 'test@example.com', '  john  ', '  doe  ', '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT 
            UPPER(TRIM(first_name)) AS first_name,
            UPPER(TRIM(last_name)) AS last_name
        FROM filtered_customers
    )
    SELECT first_name, last_name INTO v_first_name, v_last_name
    FROM cleaned_customers;
    
    -- Assert
    IF v_first_name = 'JOHN' AND v_last_name = 'DOE' THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Names properly cleaned and uppercased');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected JOHN DOE, got ' || v_first_name || ' ' || v_last_name);
    END IF;
END $$;

-- =====================================================
-- TEST 6: Email Cleaning - LOWER and TRIM
-- =====================================================
DO $$
DECLARE
    v_email VARCHAR(255);
    v_test_name VARCHAR(255) := 'TEST_06_Email_Cleaning';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES (1, '  TEST@EXAMPLE.COM  ', 'John', 'Doe', '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT LOWER(TRIM(email)) AS email
        FROM filtered_customers
    )
    SELECT email INTO v_email
    FROM cleaned_customers;
    
    -- Assert
    IF v_email = 'test@example.com' THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Email properly cleaned and lowercased');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected test@example.com, got ' || v_email);
    END IF;
END $$;

-- =====================================================
-- TEST 7: COALESCE - Phone Default Value
-- =====================================================
DO $$
DECLARE
    v_phone VARCHAR(50);
    v_test_name VARCHAR(255) := 'TEST_07_COALESCE_Phone';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, phone, signup_date)
    VALUES (1, 'test@example.com', 'John', 'Doe', NULL, '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT COALESCE(phone, 'N/A') AS phone
        FROM filtered_customers
    )
    SELECT phone INTO v_phone
    FROM cleaned_customers;
    
    -- Assert
    IF v_phone = 'N/A' THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'NULL phone replaced with N/A');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected N/A, got ' || v_phone);
    END IF;
END $$;

-- =====================================================
-- TEST 8: COALESCE - Country Default Value
-- =====================================================
DO $$
DECLARE
    v_country VARCHAR(50);
    v_test_name VARCHAR(255) := 'TEST_08_COALESCE_Country';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, country, signup_date)
    VALUES (1, 'test@example.com', 'John', 'Doe', NULL, '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT COALESCE(country, 'USA') AS country
        FROM filtered_customers
    )
    SELECT country INTO v_country
    FROM cleaned_customers;
    
    -- Assert
    IF v_country = 'USA' THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'NULL country replaced with USA');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected USA, got ' || v_country);
    END IF;
END $$;

-- =====================================================
-- TEST 9: Age Calculation
-- =====================================================
DO $$
DECLARE
    v_age NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_09_Age_Calculation';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, birth_date, signup_date)
    VALUES (1, 'test@example.com', 'John', 'Doe', CURRENT_DATE - INTERVAL '30' YEAR, '2023-01-01');
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT (CURRENT_DATE - birth_date) / 365.0 AS age
        FROM filtered_customers
    )
    SELECT age INTO v_age
    FROM cleaned_customers;
    
    -- Assert
    IF v_age >= 29.9 AND v_age <= 30.1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Age calculated correctly: ' || v_age);
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected ~30, got ' || v_age);
    END IF;
END $$;

-- =====================================================
-- TEST 10: Days as Customer Calculation
-- =====================================================
DO $$
DECLARE
    v_days INTEGER;
    v_test_name VARCHAR(255) := 'TEST_10_Days_As_Customer';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES (1, 'test@example.com', 'John', 'Doe', CURRENT_DATE - INTERVAL '100' DAY);
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    )
    SELECT days_as_customer INTO v_days
    FROM cleaned_customers;
    
    -- Assert
    IF v_days = 100 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Days as customer calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 100, got ' || v_days);
    END IF;
END $$;

-- =====================================================
-- TEST 11: Orders Filtered by Date Range (365 days)
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
    v_test_name VARCHAR(255) := 'TEST_11_Orders_Date_Filter';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '400' DAY, 'COMPLETED', 200.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    )
    SELECT COUNT(*) INTO v_count
    FROM orders_filtered;
    
    -- Assert
    IF v_count = 1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Orders filtered to last 365 days');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 1 order, got ' || v_count);
    END IF;
END $$;

-- =====================================================
-- TEST 12: Order Count Aggregation
-- =====================================================
DO $$
DECLARE
    v_total_orders INTEGER;
    v_test_name VARCHAR(255) := 'TEST_12_Order_Count_Aggregation';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders
        FROM orders_filtered
        GROUP BY customer_id
    )
    SELECT total_orders INTO v_total_orders
    FROM customer_order_summary;
    
    -- Assert
    IF v_total_orders = 3 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Total orders counted correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 3 orders, got ' || v_total_orders);
    END IF;
END $$;

-- =====================================================
-- TEST 13: Completed Orders Count
-- =====================================================
DO $$
DECLARE
    v_completed_orders INTEGER;
    v_test_name VARCHAR(255) := 'TEST_13_Completed_Orders_Count';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    )
    SELECT completed_orders INTO v_completed_orders
    FROM completed_orders;
    
    -- Assert
    IF v_completed_orders = 2 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Completed orders counted correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 2 completed orders, got ' || v_completed_orders);
    END IF;
END $$;

-- =====================================================
-- TEST 14: Total Revenue Calculation
-- =====================================================
DO $$
DECLARE
    v_total_revenue NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_14_Total_Revenue_Calculation';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    )
    SELECT total_revenue INTO v_total_revenue
    FROM completed_orders;
    
    -- Assert
    IF v_total_revenue = 300.00 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Total revenue calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 300.00, got ' || v_total_revenue);
    END IF;
END $$;

-- =====================================================
-- TEST 15: Average Order Value Calculation
-- =====================================================
DO $$
DECLARE
    v_avg_order_value NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_15_Avg_Order_Value';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    )
    SELECT avg_order_value INTO v_avg_order_value
    FROM completed_orders;
    
    -- Assert
    IF v_avg_order_value = 150.00 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Average order value calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 150.00, got ' || v_avg_order_value);
    END IF;
END $$;

-- =====================================================
-- TEST 16: Cancelled Orders Count
-- =====================================================
DO $$
DECLARE
    v_cancelled_orders INTEGER;
    v_test_name VARCHAR(255) := 'TEST_16_Cancelled_Orders_Count';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'CANCELLED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'CANCELLED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'COMPLETED', 150.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    cancelled_orders AS (
        SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
        FROM orders_filtered
        WHERE status = 'CANCELLED'
        GROUP BY customer_id
    )
    SELECT cancelled_orders INTO v_cancelled_orders
    FROM cancelled_orders;
    
    -- Assert
    IF v_cancelled_orders = 2 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Cancelled orders counted correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 2 cancelled orders, got ' || v_cancelled_orders);
    END IF;
END $$;

-- =====================================================
-- TEST 17: Returned Orders Count
-- =====================================================
DO $$
DECLARE
    v_returned_orders INTEGER;
    v_test_name VARCHAR(255) := 'TEST_17_Returned_Orders_Count';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'RETURNED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    returned_orders AS (
        SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
        FROM orders_filtered
        WHERE status = 'RETURNED'
        GROUP BY customer_id
    )
    SELECT returned_orders INTO v_returned_orders
    FROM returned_orders;
    
    -- Assert
    IF v_returned_orders = 1 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Returned orders counted correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 1 returned order, got ' || v_returned_orders);
    END IF;
END $$;

-- =====================================================
-- TEST 18: Revenue Last 30 Days
-- =====================================================
DO $$
DECLARE
    v_revenue_30 NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_18_Revenue_Last_30_Days';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '45' DAY, 'COMPLETED', 200.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    revenue_last_30 AS (
        SELECT customer_id, 
            SUM(total_amount) AS revenue_last_30_days
        FROM orders_filtered
        WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
        GROUP BY customer_id
    )
    SELECT revenue_last_30_days INTO v_revenue_30
    FROM revenue_last_30;
    
    -- Assert
    IF v_revenue_30 = 100.00 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Revenue last 30 days calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 100.00, got ' || v_revenue_30);
    END IF;
END $$;

-- =====================================================
-- TEST 19: Revenue Last 90 Days
-- =====================================================
DO $$
DECLARE
    v_revenue_90 NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_19_Revenue_Last_90_Days';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '45' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 300.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    revenue_last_90 AS (
        SELECT customer_id, SUM(total_amount) AS revenue_last_90_days
        FROM orders_filtered
        WHERE order_date >= CURRENT_DATE - INTERVAL '90' DAY
        GROUP BY customer_id
    )
    SELECT revenue_last_90_days INTO v_revenue_90
    FROM revenue_last_90;
    
    -- Assert
    IF v_revenue_90 = 300.00 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Revenue last 90 days calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 300.00, got ' || v_revenue_90);
    END IF;
END $$;

-- =====================================================
-- TEST 20: Orders Last 30 Days Count
-- =====================================================
DO $$
DECLARE
    v_orders_30 INTEGER;
    v_test_name VARCHAR(255) := 'TEST_20_Orders_Last_30_Days';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '45' DAY, 'COMPLETED', 300.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    revenue_last_30 AS (
        SELECT customer_id, 
            COUNT(DISTINCT order_id) AS orders_last_30_days
        FROM orders_filtered
        WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
        GROUP BY customer_id
    )
    SELECT orders_last_30_days INTO v_orders_30
    FROM revenue_last_30;
    
    -- Assert
    IF v_orders_30 = 2 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Orders last 30 days counted correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 2 orders, got ' || v_orders_30);
    END IF;
END $$;

-- =====================================================
-- TEST 21: LEFT JOIN Preserves All Customers
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
    v_test_name VARCHAR(255) := 'TEST_21_LEFT_JOIN_Preserves_Customers';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers, orders;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES 
        (1, 'test1@example.com', 'John', 'Doe', '2023-01-01'),
        (2, 'test2@example.com', 'Jane', 'Smith', '2023-01-01');
    
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00);
    
    -- Execute
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT 
            customer_id,
            UPPER(TRIM(first_name)) AS first_name,
            UPPER(TRIM(last_name)) AS last_name,
            LOWER(TRIM(email)) AS email,
            COALESCE(phone, 'N/A') AS phone,
            COALESCE(address, 'Unknown') AS address,
            COALESCE(city, 'Unknown') AS city,
            COALESCE(state, 'Unknown') AS state,
            COALESCE(country, 'USA') AS country,
            COALESCE(gender, 'Unknown') AS gender,
            COALESCE(income_bracket, 'Not Specified') AS income_bracket,
            COALESCE(customer_segment, 'Standard') AS customer_segment,
            signup_date,
            (CURRENT_DATE - birth_date) / 365.0 AS age,
            CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    ),
    orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MIN(order_date) AS first_order_date,
            MAX(order_date) AS last_order_date
        FROM orders_filtered
        GROUP BY customer_id
    ),
    customer_360_base AS (
        SELECT 
            cc.customer_id,
            cc.first_name,
            COALESCE(cos.total_orders, 0) AS total_orders
        FROM cleaned_customers cc
        LEFT JOIN customer_order_summary cos ON cc.customer_id = cos.customer_id
        WHERE cc.days_as_customer >= 0
    )
    SELECT COUNT(*) INTO v_count
    FROM customer_360_base;
    
    -- Assert
    IF v_count = 2 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'LEFT JOIN preserves all customers');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 2 customers, got ' || v_count);
    END IF;
END $$;

-- =====================================================
-- TEST 22: COALESCE for Zero Orders
-- =====================================================
DO $$
DECLARE
    v_total_orders INTEGER;
    v_test_name VARCHAR(255) := 'TEST_22_COALESCE_Zero_Orders';
BEGIN
    -- Setup
    TRUNCATE TABLE raw_customers, orders;
    INSERT INTO raw_customers (customer_id, email, first_name, last_name, signup_date)
    VALUES (1, 'test@example.com', 'John', 'Doe', '2023-01-01');
    
    -- Execute (no orders for this customer)
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers
        WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT 
            customer_id,
            UPPER(TRIM(first_name)) AS first_name,
            UPPER(TRIM(last_name)) AS last_name,
            LOWER(TRIM(email)) AS email,
            COALESCE(phone, 'N/A') AS phone,
            COALESCE(address, 'Unknown') AS address,
            COALESCE(city, 'Unknown') AS city,
            COALESCE(state, 'Unknown') AS state,
            COALESCE(country, 'USA') AS country,
            COALESCE(gender, 'Unknown') AS gender,
            COALESCE(income_bracket, 'Not Specified') AS income_bracket,
            COALESCE(customer_segment, 'Standard') AS customer_segment,
            signup_date,
            (CURRENT_DATE - birth_date) / 365.0 AS age,
            CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    ),
    orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders
        FROM orders_filtered
        GROUP BY customer_id
    ),
    customer_360_base AS (
        SELECT 
            cc.customer_id,
            COALESCE(cos.total_orders, 0) AS total_orders
        FROM cleaned_customers cc
        LEFT JOIN customer_order_summary cos ON cc.customer_id = cos.customer_id
        WHERE cc.days_as_customer >= 0
    )
    SELECT total_orders INTO v_total_orders
    FROM customer_360_base;
    
    -- Assert
    IF v_total_orders = 0 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'COALESCE returns 0 for customers with no orders');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 0 orders, got ' || v_total_orders);
    END IF;
END $$;

-- =====================================================
-- TEST 23: Category Spend Calculation
-- =====================================================
DO $$
DECLARE
    v_category_spend NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_23_Category_Spend_Calculation';
BEGIN
    -- Setup
    TRUNCATE TABLE orders, order_items, products;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);
    
    INSERT INTO products (product_id, product_name, category)
    VALUES (1, 'Product A', 'Electronics');
    
    INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
    VALUES (1, 1, 1, 2, 150.00);
    
    -- Execute
    WITH completed_order_items AS (
        SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price,
            o.customer_id
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.status = 'COMPLETED'
    ),
    category_spend AS (
        SELECT 
            coi.customer_id,
            p.category,
            SUM(coi.quantity * coi.unit_price) AS category_spend
        FROM completed_order_items coi
        JOIN products p ON coi.product_id = p.product_id
        GROUP BY coi.customer_id, p.category
    )
    SELECT category_spend INTO v_category_spend
    FROM category_spend;
    
    -- Assert
    IF v_category_spend = 300.00 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Category spend calculated correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected 300.00, got ' || v_category_spend);
    END IF;
END $$;

-- =====================================================
-- TEST 24: Top Category Ranking
-- =====================================================
DO $$
DECLARE
    v_top_category VARCHAR(100);
    v_test_name VARCHAR(255) := 'TEST_24_Top_Category_Ranking';
BEGIN
    -- Setup
    TRUNCATE TABLE orders, order_items, products;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 500.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00);
    
    INSERT INTO products (product_id, product_name, category)
    VALUES 
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing');
    
    INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
    VALUES 
        (1, 1, 1, 1, 300.00),
        (2, 2, 2, 1, 100.00);
    
    -- Execute
    WITH completed_order_items AS (
        SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price,
            o.customer_id
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.status = 'COMPLETED'
    ),
    category_spend AS (
        SELECT 
            coi.customer_id,
            p.category,
            SUM(coi.quantity * coi.unit_price) AS category_spend
        FROM completed_order_items coi
        JOIN products p ON coi.product_id = p.product_id
        GROUP BY coi.customer_id, p.category
    ),
    ranked_categories AS (
        SELECT customer_id, category, category_spend,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
        FROM category_spend
    ),
    top_categories AS (
        SELECT 
            customer_id,
            MAX(CASE WHEN category_rank = 1 THEN category END) AS top_category_1
        FROM ranked_categories
        WHERE category_rank <= 3
        GROUP BY customer_id
    )
    SELECT top_category_1 INTO v_top_category
    FROM top_categories;
    
    -- Assert
    IF v_top_category = 'Electronics' THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'Top category ranked correctly');
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Expected Electronics, got ' || v_top_category);
    END IF;
END $$;

-- =====================================================
-- TEST 25: RFM Recency Score Calculation
-- =====================================================
DO $$
DECLARE
    v_recency_score INTEGER;
    v_test_name VARCHAR(255) := 'TEST_25_RFM_Recency_Score';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES (1, 1, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 100.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_filtered
        GROUP BY customer_id
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.last_order_date,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    ),
    rfm_scores AS (
        SELECT 
            customer_id,
            recency_days,
            NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score
        FROM rfm_base
    )
    SELECT recency_score INTO v_recency_score
    FROM rfm_scores;
    
    -- Assert (with single record, should get score 1-5)
    IF v_recency_score BETWEEN 1 AND 5 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'RFM recency score calculated: ' || v_recency_score);
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Invalid recency score: ' || v_recency_score);
    END IF;
END $$;

-- =====================================================
-- TEST 26: RFM Frequency Score Calculation
-- =====================================================
DO $$
DECLARE
    v_frequency_score INTEGER;
    v_test_name VARCHAR(255) := 'TEST_26_RFM_Frequency_Score';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 100.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'COMPLETED', 100.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_filtered
        GROUP BY customer_id
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.last_order_date,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    ),
    rfm_scores AS (
        SELECT 
            customer_id,
            frequency,
            NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score
        FROM rfm_base
    )
    SELECT frequency_score INTO v_frequency_score
    FROM rfm_scores;
    
    -- Assert
    IF v_frequency_score BETWEEN 1 AND 5 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'RFM frequency score calculated: ' || v_frequency_score);
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Invalid frequency score: ' || v_frequency_score);
    END IF;
END $$;

-- =====================================================
-- TEST 27: RFM Monetary Score Calculation
-- =====================================================
DO $$
DECLARE
    v_monetary_score INTEGER;
    v_test_name VARCHAR(255) := 'TEST_27_RFM_Monetary_Score';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 1000.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_filtered
        GROUP BY customer_id
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.last_order_date,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    ),
    rfm_scores AS (
        SELECT 
            customer_id,
            monetary,
            NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
        FROM rfm_base
    )
    SELECT monetary_score INTO v_monetary_score
    FROM rfm_scores;
    
    -- Assert
    IF v_monetary_score BETWEEN 1 AND 5 THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'RFM monetary score calculated: ' || v_monetary_score);
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Invalid monetary score: ' || v_monetary_score);
    END IF;
END $$;

-- =====================================================
-- TEST 28: RFM Segment - Champions
-- =====================================================
DO $$
DECLARE
    v_rfm_segment VARCHAR(50);
    v_test_name VARCHAR(255) := 'TEST_28_RFM_Segment_Champions';
BEGIN
    -- Setup
    TRUNCATE TABLE orders;
    INSERT INTO orders (order_id, customer_id, order_date, status, total_amount)
    VALUES 
        (1, 1, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 1000.00),
        (2, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 1000.00),
        (3, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 1000.00),
        (4, 1, CURRENT_DATE - INTERVAL '90' DAY, 'COMPLETED', 1000.00);
    
    -- Execute
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_filtered
        GROUP BY customer_id
    ),
    completed_orders AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.last_order_date,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    ),
    rfm_scores AS (
        SELECT 
            customer_id,
            NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
            NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
            NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
        FROM rfm_base
    ),
    rfm_segments AS (
        SELECT 
            customer_id,
            recency_score,
            frequency_score,
            monetary_score,
            CASE
                WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
                WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal Customers'
                WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'New Customers'
                WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Potential Loyalists'
                WHEN recency_score >= 3 AND frequency_score <= 2 THEN 'Promising'
                WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
                WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Needs Attention'
                WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3 THEN 'About to Sleep'
                WHEN recency_score <= 1 AND frequency_score <= 1 THEN 'Lost'
                ELSE 'Others'
            END AS rfm_segment
        FROM rfm_scores
    )
    SELECT rfm_segment INTO v_rfm_segment
    FROM rfm_segments;
    
    -- Assert
    IF v_rfm_segment IN ('Champions', 'Loyal Customers', 'Potential Loyalists') THEN
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'PASSED', 'RFM segment assigned: ' || v_rfm_segment);
    ELSE
        INSERT INTO test_results (test_name, test_status, test_message)
        VALUES (v_test_name, 'FAILED', 'Unexpected segment: ' || v_rfm_segment);
    END IF;
END $$;

-- =====================================================
-- TEST 29: CLV Calculation - Purchase Frequency
-- =====================================================
DO $$
DECLARE
    v_purchase_freq NUMERIC;
    v_test_name VARCHAR(255) := 'TEST_29_CLV_Purchase_Frequency
