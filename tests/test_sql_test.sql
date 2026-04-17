-- =====================================================
-- COMPLETE SQL UNIT TEST SUITE
-- Testing Framework: SQL Unit Testing with Mock Data
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
    test_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_name VARCHAR(200),
    test_category VARCHAR(100),
    status VARCHAR(20),
    expected_value VARCHAR(500),
    actual_value VARCHAR(500),
    error_message VARCHAR(1000),
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create mock tables
CREATE TABLE raw_customers (
    customer_id INT,
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
    order_id INT,
    customer_id INT,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

CREATE TABLE order_items (
    order_item_id INT,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2)
);

CREATE TABLE products (
    product_id INT,
    product_name VARCHAR(200),
    category VARCHAR(100)
);

-- =====================================================
-- TEST 1: Deduplication Logic
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    -- Insert duplicate customers with same email
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john.doe@email.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', 
         DATE '1985-05-15', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (2, 'John', 'Doe', 'john.doe@email.com', '555-0002', '456 Oak Ave', 'Boston', 'MA', 'USA', 
         DATE '1985-05-15', 'Male', '50k-75k', 'Premium', DATE '2023-06-15');
    
    -- Execute query and check deduplication
    WITH test_result AS (
        WITH deduplicated_customers AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
            FROM raw_customers
            WHERE email IS NOT NULL AND customer_id IS NOT NULL
        )
        SELECT COUNT(*) as customer_count
        FROM deduplicated_customers
        WHERE row_num = 1 AND email = 'john.doe@email.com'
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_Deduplication_KeepsLatestSignup',
        'Deduplication',
        CASE WHEN customer_count = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(customer_count AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 2: NULL Email Filtering
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'Jane', 'Smith', NULL, '555-0003', '789 Elm St', 'NYC', 'NY', 'USA', 
         DATE '1990-03-20', 'Female', '75k-100k', 'Standard', DATE '2023-01-01'),
        (2, 'Bob', 'Johnson', 'bob@email.com', '555-0004', '321 Pine St', 'LA', 'CA', 'USA', 
         DATE '1988-07-10', 'Male', '100k+', 'Premium', DATE '2023-02-01');
    
    WITH test_result AS (
        WITH deduplicated_customers AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
            FROM raw_customers
            WHERE email IS NOT NULL AND customer_id IS NOT NULL
        )
        SELECT COUNT(*) as customer_count
        FROM deduplicated_customers
        WHERE row_num = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_NullEmail_Filtered',
        'Data_Validation',
        CASE WHEN customer_count = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(customer_count AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 3: Data Cleaning - UPPER/LOWER/TRIM
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, '  john  ', '  DOE  ', '  JOHN.DOE@EMAIL.COM  ', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1985-05-15', 'Male', '50k-75k', 'Premium', DATE '2023-01-01');
    
    WITH test_result AS (
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
                LOWER(TRIM(email)) AS email
            FROM filtered_customers
        )
        SELECT 
            first_name,
            last_name,
            email
        FROM cleaned_customers
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_DataCleaning_UpperLowerTrim',
        'Data_Cleaning',
        CASE 
            WHEN first_name = 'JOHN' AND last_name = 'DOE' AND email = 'john.doe@email.com' 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END,
        'JOHN|DOE|john.doe@email.com',
        first_name || '|' || last_name || '|' || email
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 4: COALESCE Default Values
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', NULL, NULL, NULL, NULL, NULL, 
         DATE '1990-01-01', NULL, NULL, NULL, DATE '2023-01-01');
    
    WITH test_result AS (
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
                COALESCE(phone, 'N/A') AS phone,
                COALESCE(address, 'Unknown') AS address,
                COALESCE(city, 'Unknown') AS city,
                COALESCE(state, 'Unknown') AS state,
                COALESCE(country, 'USA') AS country,
                COALESCE(gender, 'Unknown') AS gender,
                COALESCE(income_bracket, 'Not Specified') AS income_bracket,
                COALESCE(customer_segment, 'Standard') AS customer_segment
            FROM filtered_customers
        )
        SELECT phone, country, gender, income_bracket, customer_segment
        FROM cleaned_customers
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_Coalesce_DefaultValues',
        'Data_Cleaning',
        CASE 
            WHEN phone = 'N/A' AND country = 'USA' AND gender = 'Unknown' 
                AND income_bracket = 'Not Specified' AND customer_segment = 'Standard'
            THEN 'PASS' 
            ELSE 'FAIL' 
        END,
        'N/A|USA|Unknown|Not Specified|Standard',
        phone || '|' || country || '|' || gender || '|' || income_bracket || '|' || customer_segment
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 5: Age Calculation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         CURRENT_DATE - INTERVAL '36500' DAY, 'Male', '50k-75k', 'Premium', DATE '2023-01-01');
    
    WITH test_result AS (
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
                (CURRENT_DATE - birth_date) / 365.0 AS age
            FROM filtered_customers
        )
        SELECT ROUND(age, 0) as age_rounded
        FROM cleaned_customers
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_AgeCalculation_Correct',
        'Calculations',
        CASE WHEN age_rounded BETWEEN 99 AND 101 THEN 'PASS' ELSE 'FAIL' END,
        '100',
        CAST(age_rounded AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 6: Order Filtering - Last 365 Days
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '400' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '180' DAY, 'COMPLETED', 150.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT *
            FROM orders
            WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        )
        SELECT COUNT(*) as order_count
        FROM orders_last_year
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_OrderFiltering_Last365Days',
        'Date_Filtering',
        CASE WHEN order_count = 2 THEN 'PASS' ELSE 'FAIL' END,
        '2',
        CAST(order_count AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 7: Order Status Aggregation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00),
        (4, 1, CURRENT_DATE - INTERVAL '120' DAY, 'RETURNED', 75.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        completed_orders_summary AS (
            SELECT customer_id, COUNT(DISTINCT order_id) AS completed_orders
            FROM orders_last_year WHERE status = 'COMPLETED' GROUP BY customer_id
        ),
        cancelled_orders_summary AS (
            SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
            FROM orders_last_year WHERE status = 'CANCELLED' GROUP BY customer_id
        ),
        returned_orders_summary AS (
            SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
            FROM orders_last_year WHERE status = 'RETURNED' GROUP BY customer_id
        )
        SELECT 
            COALESCE(comp.completed_orders, 0) as completed,
            COALESCE(canc.cancelled_orders, 0) as cancelled,
            COALESCE(ret.returned_orders, 0) as returned
        FROM (SELECT 1 as customer_id) base
        LEFT JOIN completed_orders_summary comp ON base.customer_id = comp.customer_id
        LEFT JOIN cancelled_orders_summary canc ON base.customer_id = canc.customer_id
        LEFT JOIN returned_orders_summary ret ON base.customer_id = ret.customer_id
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_OrderStatus_Aggregation',
        'Aggregation',
        CASE WHEN completed = 2 AND cancelled = 1 AND returned = 1 THEN 'PASS' ELSE 'FAIL' END,
        '2|1|1',
        CAST(completed AS VARCHAR) || '|' || CAST(cancelled AS VARCHAR) || '|' || CAST(returned AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 8: Revenue Calculations
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '45' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '120' DAY, 'COMPLETED', 300.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        completed_orders_summary AS (
            SELECT 
                customer_id,
                SUM(total_amount) AS total_revenue,
                AVG(total_amount) AS avg_order_value
            FROM orders_last_year
            WHERE status = 'COMPLETED'
            GROUP BY customer_id
        )
        SELECT 
            total_revenue,
            ROUND(avg_order_value, 2) as avg_order_value
        FROM completed_orders_summary
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_Revenue_Calculations',
        'Calculations',
        CASE WHEN total_revenue = 600.00 AND avg_order_value = 200.00 THEN 'PASS' ELSE 'FAIL' END,
        '600.00|200.00',
        CAST(total_revenue AS VARCHAR) || '|' || CAST(avg_order_value AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 9: Recent Revenue Windows (30/90 days)
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '45' DAY, 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '120' DAY, 'COMPLETED', 300.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        recent_revenue_30 AS (
            SELECT customer_id, SUM(total_amount) AS revenue_last_30_days
            FROM orders_last_year
            WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
            GROUP BY customer_id
        ),
        recent_revenue_90 AS (
            SELECT customer_id, SUM(total_amount) AS revenue_last_90_days
            FROM orders_last_year
            WHERE order_date >= CURRENT_DATE - INTERVAL '90' DAY
            GROUP BY customer_id
        )
        SELECT 
            COALESCE(r30.revenue_last_30_days, 0) as rev_30,
            COALESCE(r90.revenue_last_90_days, 0) as rev_90
        FROM (SELECT 1 as customer_id) base
        LEFT JOIN recent_revenue_30 r30 ON base.customer_id = r30.customer_id
        LEFT JOIN recent_revenue_90 r90 ON base.customer_id = r90.customer_id
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_RecentRevenue_Windows',
        'Window_Functions',
        CASE WHEN rev_30 = 100.00 AND rev_90 = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '100.00|300.00',
        CAST(rev_30 AS VARCHAR) || '|' || CAST(rev_90 AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 10: Category Spending with Joins
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 2, 100.00),
        (2, 1, 2, 1, 100.00);
    
    WITH test_result AS (
        WITH completed_order_items AS (
            SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price, o.customer_id
            FROM order_items oi
            INNER JOIN orders o ON oi.order_id = o.order_id
            WHERE o.status = 'COMPLETED'
        ),
        category_spending AS (
            SELECT 
                coi.customer_id,
                p.category,
                SUM(coi.quantity * coi.unit_price) AS category_spend
            FROM completed_order_items coi
            INNER JOIN products p ON coi.product_id = p.product_id
            GROUP BY coi.customer_id, p.category
        )
        SELECT COUNT(DISTINCT category) as category_count, SUM(category_spend) as total_spend
        FROM category_spending
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_CategorySpending_Joins',
        'Joins',
        CASE WHEN category_count = 2 AND total_spend = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '2|300.00',
        CAST(category_count AS VARCHAR) || '|' || CAST(total_spend AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 11: ROW_NUMBER Window Function for Categories
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 600.00);
    
    INSERT INTO products VALUES
        (1, 'Product A', 'Electronics'),
        (2, 'Product B', 'Clothing'),
        (3, 'Product C', 'Books');
    
    INSERT INTO order_items VALUES
        (1, 1, 1, 1, 300.00),
        (2, 1, 2, 1, 200.00),
        (3, 1, 3, 1, 100.00);
    
    WITH test_result AS (
        WITH completed_order_items AS (
            SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price, o.customer_id
            FROM order_items oi
            INNER JOIN orders o ON oi.order_id = o.order_id
            WHERE o.status = 'COMPLETED'
        ),
        category_spending AS (
            SELECT 
                coi.customer_id,
                p.category,
                SUM(coi.quantity * coi.unit_price) AS category_spend
            FROM completed_order_items coi
            INNER JOIN products p ON coi.product_id = p.product_id
            GROUP BY coi.customer_id, p.category
        ),
        ranked_categories AS (
            SELECT 
                customer_id,
                category,
                category_spend,
                ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
            FROM category_spending
        )
        SELECT category, category_rank
        FROM ranked_categories
        WHERE customer_id = 1 AND category_rank = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_RowNumber_CategoryRanking',
        'Window_Functions',
        CASE WHEN category = 'Electronics' AND category_rank = 1 THEN 'PASS' ELSE 'FAIL' END,
        'Electronics|1',
        category || '|' || CAST(category_rank AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 12: Top 3 Categories Pivot
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES (1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 600.00);
    
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
    
    WITH test_result AS (
        WITH completed_order_items AS (
            SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price, o.customer_id
            FROM order_items oi
            INNER JOIN orders o ON oi.order_id = o.order_id
            WHERE o.status = 'COMPLETED'
        ),
        category_spending AS (
            SELECT 
                coi.customer_id,
                p.category,
                SUM(coi.quantity * coi.unit_price) AS category_spend
            FROM completed_order_items coi
            INNER JOIN products p ON coi.product_id = p.product_id
            GROUP BY coi.customer_id, p.category
        ),
        ranked_categories AS (
            SELECT 
                customer_id,
                category,
                category_spend,
                ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
            FROM category_spending
        ),
        top_categories AS (
            SELECT 
                customer_id,
                MAX(CASE WHEN category_rank = 1 THEN category END) AS top_category_1,
                MAX(CASE WHEN category_rank = 2 THEN category END) AS top_category_2,
                MAX(CASE WHEN category_rank = 3 THEN category END) AS top_category_3
            FROM ranked_categories
            WHERE category_rank <= 3
            GROUP BY customer_id
        )
        SELECT top_category_1, top_category_2, top_category_3
        FROM top_categories
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_TopCategories_Pivot',
        'Aggregation',
        CASE 
            WHEN top_category_1 = 'Electronics' 
                AND top_category_2 = 'Clothing' 
                AND top_category_3 = 'Books' 
            THEN 'PASS' 
            ELSE 'FAIL' 
        END,
        'Electronics|Clothing|Books',
        COALESCE(top_category_1, 'NULL') || '|' || COALESCE(top_category_2, 'NULL') || '|' || COALESCE(top_category_3, 'NULL')
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 13: RFM Score Calculation - NTILE
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    -- Insert 10 customers with varying order patterns
    INSERT INTO raw_customers VALUES
        (1, 'Customer', '1', 'c1@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (2, 'Customer', '2', 'c2@email.com', '555-0002', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (3, 'Customer', '3', 'c3@email.com', '555-0003', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (4, 'Customer', '4', 'c4@email.com', '555-0004', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (5, 'Customer', '5', 'c5@email.com', '555-0005', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 1000.00),
        (2, 2, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 800.00),
        (3, 3, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 600.00),
        (4, 4, CURRENT_DATE - INTERVAL '200' DAY, 'COMPLETED', 400.00),
        (5, 5, CURRENT_DATE - INTERVAL '300' DAY, 'COMPLETED', 200.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT customer_id, MAX(order_date) AS last_order_date, COUNT(DISTINCT order_id) AS total_orders
            FROM orders_last_year GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT customer_id, SUM(total_amount) AS total_revenue
            FROM orders_last_year WHERE status = 'COMPLETED' GROUP BY customer_id
        ),
        rfm_base AS (
            SELECT 
                co.customer_id,
                CURRENT_DATE - co.last_order_date AS recency_days,
                co.total_orders AS frequency,
                COALESCE(comp.total_revenue, 0) AS monetary
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
            WHERE co.total_orders > 0
        ),
        rfm_quantiles AS (
            SELECT 
                customer_id,
                NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
                NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
                NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
            FROM rfm_base
        )
        SELECT COUNT(DISTINCT recency_score) as unique_scores
        FROM rfm_quantiles
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_RFM_NTILE_Calculation',
        'Window_Functions',
        CASE WHEN unique_scores >= 1 THEN 'PASS' ELSE 'FAIL' END,
        '>=1',
        CAST(unique_scores AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 14: RFM Segmentation Logic
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Champion', 'Customer', 'champion@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    -- Recent, frequent, high-value orders for Champions segment
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 500.00),
        (2, 1, CURRENT_DATE - INTERVAL '15' DAY, 'COMPLETED', 600.00),
        (3, 1, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 700.00),
        (4, 1, CURRENT_DATE - INTERVAL '35' DAY, 'COMPLETED', 800.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT customer_id, MAX(order_date) AS last_order_date, COUNT(DISTINCT order_id) AS total_orders
            FROM orders_last_year GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT customer_id, SUM(total_amount) AS total_revenue
            FROM orders_last_year WHERE status = 'COMPLETED' GROUP BY customer_id
        ),
        rfm_base AS (
            SELECT 
                co.customer_id,
                CURRENT_DATE - co.last_order_date AS recency_days,
                co.total_orders AS frequency,
                COALESCE(comp.total_revenue, 0) AS monetary
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
            WHERE co.total_orders > 0
        ),
        rfm_quantiles AS (
            SELECT 
                customer_id,
                NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
                NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
                NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
            FROM rfm_base
        ),
        rfm_scores AS (
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
            FROM rfm_quantiles
        )
        SELECT rfm_segment, recency_score, frequency_score, monetary_score
        FROM rfm_scores
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_RFM_Segmentation_Champions',
        'Business_Logic',
        CASE WHEN rfm_segment IN ('Champions', 'Loyal Customers') THEN 'PASS' ELSE 'FAIL' END,
        'Champions or Loyal Customers',
        rfm_segment || ' (R:' || CAST(recency_score AS VARCHAR) || ' F:' || CAST(frequency_score AS VARCHAR) || ' M:' || CAST(monetary_score AS VARCHAR) || ')'
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 15: CLV Calculation - Purchase Frequency
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2023-01-01');
    
    -- Orders spanning 365 days
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '183' DAY, 'COMPLETED', 100.00),
        (3, 1, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 100.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT 
                customer_id,
                COUNT(DISTINCT order_id) AS total_orders,
                MIN(order_date) AS first_order_date,
                MAX(order_date) AS last_order_date
            FROM orders_last_year
            GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT 
                customer_id,
                SUM(total_amount) AS total_revenue,
                AVG(total_amount) AS avg_order_value
            FROM orders_last_year
            WHERE status = 'COMPLETED'
            GROUP BY customer_id
        ),
        aggregated_orders AS (
            SELECT 
                co.customer_id,
                co.total_orders,
                co.first_order_date,
                co.last_order_date,
                COALESCE(comp.total_revenue, 0) AS total_revenue,
                COALESCE(comp.avg_order_value, 0) AS avg_order_value
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
        ),
        deduplicated_customers AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
            FROM raw_customers
            WHERE email IS NOT NULL AND customer_id IS NOT NULL
        ),
        filtered_customers AS (
            SELECT customer_id, signup_date
            FROM deduplicated_customers
            WHERE row_num = 1
        ),
        cleaned_customers AS (
            SELECT 
                customer_id,
                signup_date,
                CURRENT_DATE - signup_date AS days_as_customer
            FROM filtered_customers
        ),
        clv_base AS (
            SELECT 
                ao.customer_id,
                ao.total_orders,
                ao.total_revenue,
                ao.avg_order_value,
                ao.first_order_date,
                ao.last_order_date,
                cc.days_as_customer,
                ao.last_order_date - ao.first_order_date AS customer_lifespan_days
            FROM aggregated_orders ao
            INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
            WHERE ao.total_orders >= 2
        ),
        clv_calculated AS (
            SELECT 
                customer_id,
                total_orders,
                customer_lifespan_days,
                CASE 
                    WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                    ELSE total_orders
                END AS purchase_frequency_annual
            FROM clv_base
        )
        SELECT 
            customer_id,
            ROUND(purchase_frequency_annual, 2) as freq_annual
        FROM clv_calculated
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_CLV_PurchaseFrequency',
        'Calculations',
        CASE WHEN freq_annual > 0 THEN 'PASS' ELSE 'FAIL' END,
        '>0',
        CAST(freq_annual AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 16: CLV 3-Year Estimation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Test', 'User', 'test@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 100.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT 
                customer_id,
                COUNT(DISTINCT order_id) AS total_orders,
                MIN(order_date) AS first_order_date,
                MAX(order_date) AS last_order_date
            FROM orders_last_year
            GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT 
                customer_id,
                SUM(total_amount) AS total_revenue,
                AVG(total_amount) AS avg_order_value
            FROM orders_last_year
            WHERE status = 'COMPLETED'
            GROUP BY customer_id
        ),
        aggregated_orders AS (
            SELECT 
                co.customer_id,
                co.total_orders,
                co.first_order_date,
                co.last_order_date,
                COALESCE(comp.total_revenue, 0) AS total_revenue,
                COALESCE(comp.avg_order_value, 0) AS avg_order_value
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
        ),
        deduplicated_customers AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
            FROM raw_customers
            WHERE email IS NOT NULL AND customer_id IS NOT NULL
        ),
        filtered_customers AS (
            SELECT customer_id, signup_date
            FROM deduplicated_customers
            WHERE row_num = 1
        ),
        cleaned_customers AS (
            SELECT 
                customer_id,
                signup_date,
                CURRENT_DATE - signup_date AS days_as_customer
            FROM filtered_customers
        ),
        clv_base AS (
            SELECT 
                ao.customer_id,
                ao.total_orders,
                ao.total_revenue,
                ao.avg_order_value,
                ao.first_order_date,
                ao.last_order_date,
                cc.days_as_customer,
                ao.last_order_date - ao.first_order_date AS customer_lifespan_days
            FROM aggregated_orders ao
            INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
            WHERE ao.total_orders >= 2
        ),
        clv_calculated AS (
            SELECT 
                customer_id,
                total_orders,
                total_revenue,
                avg_order_value,
                customer_lifespan_days,
                days_as_customer,
                CASE 
                    WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                    ELSE total_orders
                END AS purchase_frequency_annual
            FROM clv_base
        ),
        clv_with_percentiles AS (
            SELECT 
                customer_id,
                ROUND(avg_order_value * purchase_frequency_annual * 3, 2) AS estimated_clv_3yr
            FROM clv_calculated
        )
        SELECT estimated_clv_3yr
        FROM clv_with_percentiles
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_CLV_3Year_Estimation',
        'Calculations',
        CASE WHEN estimated_clv_3yr > 0 THEN 'PASS' ELSE 'FAIL' END,
        '>0',
        CAST(estimated_clv_3yr AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 17: PERCENT_RANK Window Function
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    -- Create 5 customers with different revenue levels
    INSERT INTO raw_customers VALUES
        (1, 'Customer', '1', 'c1@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (2, 'Customer', '2', 'c2@email.com', '555-0002', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (3, 'Customer', '3', 'c3@email.com', '555-0003', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (4, 'Customer', '4', 'c4@email.com', '555-0004', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (5, 'Customer', '5', 'c5@email.com', '555-0005', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 1000.00),
        (2, 1, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 1000.00),
        (3, 2, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 800.00),
        (4, 2, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 800.00),
        (5, 3, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 600.00),
        (6, 3, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 600.00),
        (7, 4, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 400.00),
        (8, 4, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 400.00),
        (9, 5, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 200.00),
        (10, 5, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 200.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT 
                customer_id,
                COUNT(DISTINCT order_id) AS total_orders,
                MIN(order_date) AS first_order_date,
                MAX(order_date) AS last_order_date
            FROM orders_last_year
            GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT 
                customer_id,
                SUM(total_amount) AS total_revenue,
                AVG(total_amount) AS avg_order_value
            FROM orders_last_year
            WHERE status = 'COMPLETED'
            GROUP BY customer_id
        ),
        aggregated_orders AS (
            SELECT 
                co.customer_id,
                co.total_orders,
                co.first_order_date,
                co.last_order_date,
                COALESCE(comp.total_revenue, 0) AS total_revenue,
                COALESCE(comp.avg_order_value, 0) AS avg_order_value
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
        ),
        deduplicated_customers AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
            FROM raw_customers
            WHERE email IS NOT NULL AND customer_id IS NOT NULL
        ),
        filtered_customers AS (
            SELECT customer_id, signup_date
            FROM deduplicated_customers
            WHERE row_num = 1
        ),
        cleaned_customers AS (
            SELECT 
                customer_id,
                signup_date,
                CURRENT_DATE - signup_date AS days_as_customer
            FROM filtered_customers
        ),
        clv_base AS (
            SELECT 
                ao.customer_id,
                ao.total_orders,
                ao.total_revenue,
                ao.avg_order_value,
                ao.first_order_date,
                ao.last_order_date,
                cc.days_as_customer,
                ao.last_order_date - ao.first_order_date AS customer_lifespan_days
            FROM aggregated_orders ao
            INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
            WHERE ao.total_orders >= 2
        ),
        clv_calculated AS (
            SELECT 
                customer_id,
                total_orders,
                total_revenue,
                avg_order_value,
                customer_lifespan_days,
                days_as_customer,
                CASE 
                    WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                    ELSE total_orders
                END AS purchase_frequency_annual
            FROM clv_base
        ),
        clv_with_percentiles AS (
            SELECT 
                customer_id,
                total_revenue,
                PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_percentile
            FROM clv_calculated
        )
        SELECT revenue_percentile
        FROM clv_with_percentiles
        WHERE customer_id = 1
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_PercentRank_Calculation',
        'Window_Functions',
        CASE WHEN revenue_percentile = 1.0 THEN 'PASS' ELSE 'FAIL' END,
        '1.0',
        CAST(revenue_percentile AS VARCHAR)
    FROM test_result;
COMMIT;

-- =====================================================
-- TEST 18: Customer Tier Assignment
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    -- Create customers for each tier
    INSERT INTO raw_customers VALUES
        (1, 'Platinum', 'Customer', 'platinum@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (2, 'Bronze', 'Customer', 'bronze@email.com', '555-0002', '123 Main', 'Boston', 'MA', 'USA', DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 10000.00),
        (2, 1, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 10000.00),
        (3, 2, CURRENT_DATE - INTERVAL '365' DAY, 'COMPLETED', 100.00),
        (4, 2, CURRENT_DATE - INTERVAL '1' DAY, 'COMPLETED', 100.00);
    
    WITH test_result AS (
        WITH orders_last_year AS (
            SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
        ),
        customer_order_summary AS (
            SELECT 
                customer_id,
                COUNT(DISTINCT order_id) AS total_orders,
                MIN(order_date) AS first_order_date,
                MAX(order_date) AS last_order_date
            FROM orders_last_year
            GROUP BY customer_id
        ),
        completed_orders_summary AS (
            SELECT 
                customer_id,
                SUM(total_amount) AS total_revenue,
                AVG(total_amount) AS avg_order_value
            FROM orders_last_year
            WHERE status = 'COMPLETED'
            GROUP BY customer_id
        ),
        aggregated_orders AS (
            SELECT 
                co.customer_id,
                co.total_orders,
                co.first_order_date,
                co.last_order_date,
                COALESCE(comp.total_revenue, 0) AS total_revenue,
                COALESCE(comp.avg_order_value, 0) AS avg_order_value
            FROM customer_order_summary co
            LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
        ),
        deduplicated_customers AS (
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
                signup_date,
                CURRENT_DATE - signup_date AS days_as_customer
            FROM filtered_customers
        ),
        clv_base AS (
            SELECT 
                ao.customer_id,
                ao.total_orders,
                ao.total_revenue,
                ao.avg_order_value,
                ao.first_order_date,
                ao.last_order_date,
                cc.days_as_customer,
                ao.last_order_date - ao.first_order_date AS customer_lifespan_days
            FROM aggregated_orders ao
            INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
            WHERE ao.total_orders >= 2
        ),
        clv_calculated AS (
            SELECT 
                customer_id,
                total_orders,
                total_revenue,
                avg_order_value,
                customer_lifespan_days,
                days_as_customer,
                CASE 
                    WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                    ELSE total_orders
                END AS purchase_frequency_annual
            FROM clv_base
        ),
        clv_with_percentiles AS (
            SELECT 
                customer_id,
                ROUND(avg_order_value * purchase_frequency_annual * 3, 2) AS estimated_clv_3yr,
                PERCENT_RANK() OVER (ORDER BY avg_order_value * purchase_frequency_annual) AS clv_percentile
            FROM clv_calculated
        ),
        merged_data AS (
            SELECT 
                cc.customer_id,
                cc.first_name,
                clv.clv_percentile
            FROM cleaned_customers cc
            LEFT JOIN clv_with_percentiles clv ON cc.customer_id = clv.customer_id
        ),
        final_report AS (
            SELECT 
                customer_id,
                first_name,
                CASE
                    WHEN clv_percentile >= 0.9 THEN 'Platinum'
                    WHEN clv_percentile >= 0.7 THEN 'Gold'
                    WHEN clv_percentile >= 0.4 THEN 'Silver'
                    ELSE 'Bronze'
                END AS customer_tier
            FROM merged_data
        )
        SELECT customer_id, first_name, customer_tier
        FROM final_report
        ORDER BY customer_id
    )
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test_CustomerTier_Assignment',
        'Business_Logic',
        CASE 
            WHEN (SELECT customer_tier FROM test_result WHERE customer_id = 1) = 'Platinum'
                AND (SELECT customer_tier FROM test_result WHERE customer_id = 2) = 'Bronze'
            THEN 'PASS' 
            ELSE 'FAIL' 
        END,
        'Platinum|Bronze',
        (SELECT customer_tier FROM test_result WHERE customer_id = 1) || '|' || 
        (SELECT customer_tier FROM test_result WHERE customer_id = 2)
    FROM test_result
    LIMIT 1;
COMMIT;

-- =====================================================
-- TEST 19: Churn Risk Classification
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1, 'Active', 'Customer', 'active@email.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (2, 'HighRisk', 'Customer', 'highrisk@email.com', '555-0002', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01'),
        (3, 'MediumRisk', 'Customer', 'medrisk@email.com', '555-0003', '123 Main', 'Boston', 'MA', 'USA', 
         DATE '1990-01-01', 'Male', '50k-75k', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (2, 2, CURRENT
