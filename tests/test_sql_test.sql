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
         DATE '1985-05-15', 'Male', '50K-75K', 'Premium', DATE '2022-01-01'),
        (2, 'John', 'Doe', 'john.doe@email.com', '555-0002', '456 Oak Ave', 'Boston', 'MA', 'USA', 
         DATE '1985-05-15', 'Male', '50K-75K', 'Premium', DATE '2023-06-15');
    
    -- Execute query and check deduplication
    CREATE TEMP TABLE test1_result AS
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT COUNT(*) as customer_count, MAX(customer_id) as kept_customer_id
    FROM deduplicated_customers
    WHERE row_num = 1 AND email = 'john.doe@email.com';
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Deduplication - Keep Latest Signup',
        'Deduplication',
        CASE WHEN customer_count = 1 AND kept_customer_id = 2 THEN 'PASS' ELSE 'FAIL' END,
        'count=1, customer_id=2',
        'count=' || customer_count || ', customer_id=' || kept_customer_id
    FROM test1_result;
    
    DROP TABLE test1_result;
ROLLBACK;

-- =====================================================
-- TEST 2: NULL Handling and Data Cleaning
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (100, '  john  ', '  DOE  ', 'JOHN.DOE@EMAIL.COM', NULL, NULL, NULL, NULL, NULL,
         DATE '1990-01-01', NULL, NULL, NULL, DATE '2023-01-01');
    
    CREATE TEMP TABLE test2_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers WHERE row_num = 1
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
            COALESCE(customer_segment, 'Standard') AS customer_segment
        FROM filtered_customers
    )
    SELECT * FROM cleaned_customers WHERE customer_id = 100;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test NULL Coalescing - Phone',
        'Data Cleaning',
        CASE WHEN phone = 'N/A' THEN 'PASS' ELSE 'FAIL' END,
        'N/A',
        phone
    FROM test2_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test String Trimming and Case - First Name',
        'Data Cleaning',
        CASE WHEN first_name = 'JOHN' THEN 'PASS' ELSE 'FAIL' END,
        'JOHN',
        first_name
    FROM test2_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Email Lowercase',
        'Data Cleaning',
        CASE WHEN email = 'john.doe@email.com' THEN 'PASS' ELSE 'FAIL' END,
        'john.doe@email.com',
        email
    FROM test2_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Default Country',
        'Data Cleaning',
        CASE WHEN country = 'USA' THEN 'PASS' ELSE 'FAIL' END,
        'USA',
        country
    FROM test2_result;
    
    DROP TABLE test2_result;
ROLLBACK;

-- =====================================================
-- TEST 3: Order Aggregation Logic
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (200, 'Jane', 'Smith', 'jane@email.com', '555-1000', '789 Elm St', 'NYC', 'NY', 'USA',
         DATE '1988-03-20', 'Female', '75K-100K', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (1001, 200, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (1002, 200, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
        (1003, 200, CURRENT_DATE - INTERVAL '400' DAY, 'COMPLETED', 150.00),
        (1004, 200, CURRENT_DATE - INTERVAL '15' DAY, 'CANCELLED', 50.00),
        (1005, 200, CURRENT_DATE - INTERVAL '25' DAY, 'RETURNED', 75.00);
    
    CREATE TEMP TABLE test3_result AS
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
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_last_year
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    cancelled_orders_summary AS (
        SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
        FROM orders_last_year WHERE status = 'CANCELLED'
        GROUP BY customer_id
    ),
    returned_orders_summary AS (
        SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
        FROM orders_last_year WHERE status = 'RETURNED'
        GROUP BY customer_id
    )
    SELECT 
        co.customer_id,
        co.total_orders,
        COALESCE(comp.completed_orders, 0) AS completed_orders,
        COALESCE(comp.total_revenue, 0) AS total_revenue,
        COALESCE(canc.cancelled_orders, 0) AS cancelled_orders,
        COALESCE(ret.returned_orders, 0) AS returned_orders
    FROM customer_order_summary co
    LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
    LEFT JOIN cancelled_orders_summary canc ON co.customer_id = canc.customer_id
    LEFT JOIN returned_orders_summary ret ON co.customer_id = ret.customer_id
    WHERE co.customer_id = 200;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Order Count - Last Year Only',
        'Order Aggregation',
        CASE WHEN total_orders = 4 THEN 'PASS' ELSE 'FAIL' END,
        '4',
        CAST(total_orders AS VARCHAR)
    FROM test3_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Completed Orders Count',
        'Order Aggregation',
        CASE WHEN completed_orders = 2 THEN 'PASS' ELSE 'FAIL' END,
        '2',
        CAST(completed_orders AS VARCHAR)
    FROM test3_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Total Revenue - Completed Only',
        'Order Aggregation',
        CASE WHEN total_revenue = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '300.00',
        CAST(total_revenue AS VARCHAR)
    FROM test3_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Cancelled Orders',
        'Order Aggregation',
        CASE WHEN cancelled_orders = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(cancelled_orders AS VARCHAR)
    FROM test3_result;
    
    DROP TABLE test3_result;
ROLLBACK;

-- =====================================================
-- TEST 4: Recent Revenue Calculations (30 and 90 days)
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (2001, 300, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 100.00),
        (2002, 300, CURRENT_DATE - INTERVAL '25' DAY, 'COMPLETED', 200.00),
        (2003, 300, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 300.00),
        (2004, 300, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 400.00);
    
    CREATE TEMP TABLE test4_result AS
    WITH orders_last_year AS (
        SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    recent_revenue_30 AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS revenue_last_30_days,
            COUNT(DISTINCT order_id) AS orders_last_30_days
        FROM orders_last_year
        WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
        GROUP BY customer_id
    ),
    recent_revenue_90 AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS revenue_last_90_days
        FROM orders_last_year
        WHERE order_date >= CURRENT_DATE - INTERVAL '90' DAY
        GROUP BY customer_id
    )
    SELECT 
        r30.customer_id,
        r30.revenue_last_30_days,
        r30.orders_last_30_days,
        r90.revenue_last_90_days
    FROM recent_revenue_30 r30
    LEFT JOIN recent_revenue_90 r90 ON r30.customer_id = r90.customer_id
    WHERE r30.customer_id = 300;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Revenue Last 30 Days',
        'Recent Revenue',
        CASE WHEN revenue_last_30_days = 300.00 THEN 'PASS' ELSE 'FAIL' END,
        '300.00',
        CAST(revenue_last_30_days AS VARCHAR)
    FROM test4_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Revenue Last 90 Days',
        'Recent Revenue',
        CASE WHEN revenue_last_90_days = 600.00 THEN 'PASS' ELSE 'FAIL' END,
        '600.00',
        CAST(revenue_last_90_days AS VARCHAR)
    FROM test4_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Orders Last 30 Days',
        'Recent Revenue',
        CASE WHEN orders_last_30_days = 2 THEN 'PASS' ELSE 'FAIL' END,
        '2',
        CAST(orders_last_30_days AS VARCHAR)
    FROM test4_result;
    
    DROP TABLE test4_result;
ROLLBACK;

-- =====================================================
-- TEST 5: Category Spending and Top Categories
-- =====================================================
BEGIN;
    DELETE FROM orders;
    DELETE FROM order_items;
    DELETE FROM products;
    
    INSERT INTO orders VALUES
        (3001, 400, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 500.00),
        (3002, 400, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 300.00);
    
    INSERT INTO products VALUES
        (101, 'Laptop', 'Electronics'),
        (102, 'Mouse', 'Electronics'),
        (103, 'Shirt', 'Clothing'),
        (104, 'Book', 'Books');
    
    INSERT INTO order_items VALUES
        (1, 3001, 101, 1, 400.00),
        (2, 3001, 102, 2, 50.00),
        (3, 3002, 103, 3, 100.00);
    
    CREATE TEMP TABLE test5_result AS
    WITH completed_order_items AS (
        SELECT 
            oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price, o.customer_id
        FROM order_items oi
        INNER JOIN orders o ON oi.order_id = o.order_id
        WHERE o.status = 'COMPLETED'
    ),
    category_spending AS (
        SELECT 
            coi.customer_id,
            p.category,
            COUNT(DISTINCT coi.order_item_id) AS items_purchased,
            SUM(coi.quantity) AS total_quantity,
            SUM(coi.quantity * coi.unit_price) AS category_spend
        FROM completed_order_items coi
        INNER JOIN products p ON coi.product_id = p.product_id
        GROUP BY coi.customer_id, p.category
    ),
    ranked_categories AS (
        SELECT 
            customer_id, category, category_spend,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
        FROM category_spending
    ),
    top_categories AS (
        SELECT 
            customer_id,
            MAX(CASE WHEN category_rank = 1 THEN category END) AS top_category_1,
            MAX(CASE WHEN category_rank = 1 THEN category_spend END) AS top_category_1_spend,
            MAX(CASE WHEN category_rank = 2 THEN category END) AS top_category_2,
            MAX(CASE WHEN category_rank = 2 THEN category_spend END) AS top_category_2_spend
        FROM ranked_categories
        WHERE category_rank <= 3
        GROUP BY customer_id
    )
    SELECT * FROM top_categories WHERE customer_id = 400;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Top Category Identification',
        'Category Analysis',
        CASE WHEN top_category_1 = 'Electronics' THEN 'PASS' ELSE 'FAIL' END,
        'Electronics',
        COALESCE(top_category_1, 'NULL')
    FROM test5_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Top Category Spend Calculation',
        'Category Analysis',
        CASE WHEN top_category_1_spend = 500.00 THEN 'PASS' ELSE 'FAIL' END,
        '500.00',
        CAST(COALESCE(top_category_1_spend, 0) AS VARCHAR)
    FROM test5_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Second Category',
        'Category Analysis',
        CASE WHEN top_category_2 = 'Clothing' THEN 'PASS' ELSE 'FAIL' END,
        'Clothing',
        COALESCE(top_category_2, 'NULL')
    FROM test5_result;
    
    DROP TABLE test5_result;
ROLLBACK;

-- =====================================================
-- TEST 6: RFM Scoring Logic
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (500, 'Alice', 'Johnson', 'alice@email.com', '555-2000', '100 Park Ave', 'LA', 'CA', 'USA',
         DATE '1992-07-10', 'Female', '100K+', 'VIP', DATE '2020-01-01'),
        (501, 'Bob', 'Williams', 'bob@email.com', '555-2001', '200 Main St', 'SF', 'CA', 'USA',
         DATE '1985-11-25', 'Male', '50K-75K', 'Standard', DATE '2021-06-01');
    
    -- Alice: Recent, frequent, high value (Champion)
    INSERT INTO orders VALUES
        (4001, 500, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 1000.00),
        (4002, 500, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 1200.00),
        (4003, 500, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 1100.00),
        (4004, 500, CURRENT_DATE - INTERVAL '90' DAY, 'COMPLETED', 900.00);
    
    -- Bob: Old, infrequent, low value (At Risk)
    INSERT INTO orders VALUES
        (4005, 501, CURRENT_DATE - INTERVAL '200' DAY, 'COMPLETED', 100.00),
        (4006, 501, CURRENT_DATE - INTERVAL '250' DAY, 'COMPLETED', 150.00);
    
    CREATE TEMP TABLE test6_result AS
    WITH orders_last_year AS (
        SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_last_year
        GROUP BY customer_id
    ),
    completed_orders_summary AS (
        SELECT 
            customer_id,
            SUM(total_amount) AS total_revenue
        FROM orders_last_year
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    aggregated_orders AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            co.last_order_date,
            COALESCE(comp.total_revenue, 0) AS total_revenue
        FROM customer_order_summary co
        LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            total_revenue AS monetary
        FROM aggregated_orders
        WHERE total_orders > 0
    ),
    rfm_quantiles AS (
        SELECT 
            customer_id,
            recency_days,
            frequency,
            monetary,
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
            recency_score + frequency_score + monetary_score AS rfm_total_score,
            CASE
                WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
                WHEN recency_score >= 4 AND frequency_score >= 3 THEN 'Loyal Customers'
                WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
                WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Needs Attention'
                ELSE 'Others'
            END AS rfm_segment
        FROM rfm_quantiles
    )
    SELECT * FROM rfm_scores ORDER BY customer_id;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test RFM Segment - Champion Customer',
        'RFM Analysis',
        CASE WHEN rfm_segment IN ('Champions', 'Loyal Customers') THEN 'PASS' ELSE 'FAIL' END,
        'Champions or Loyal Customers',
        rfm_segment
    FROM test6_result
    WHERE customer_id = 500;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test RFM Total Score Range',
        'RFM Analysis',
        CASE WHEN rfm_total_score BETWEEN 3 AND 15 THEN 'PASS' ELSE 'FAIL' END,
        '3-15',
        CAST(rfm_total_score AS VARCHAR)
    FROM test6_result
    WHERE customer_id = 500;
    
    DROP TABLE test6_result;
ROLLBACK;

-- =====================================================
-- TEST 7: CLV Calculation
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (600, 'Charlie', 'Brown', 'charlie@email.com', '555-3000', '300 Elm St', 'Chicago', 'IL', 'USA',
         DATE '1990-04-15', 'Male', '75K-100K', 'Premium', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (5001, 600, DATE '2023-01-15', 'COMPLETED', 200.00),
        (5002, 600, DATE '2023-04-20', 'COMPLETED', 250.00),
        (5003, 600, DATE '2023-07-10', 'COMPLETED', 300.00),
        (5004, 600, DATE '2023-10-05', 'COMPLETED', 350.00);
    
    CREATE TEMP TABLE test7_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, signup_date FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT customer_id, signup_date, CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    ),
    orders_last_year AS (
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
            CASE 
                WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                ELSE total_orders
            END AS purchase_frequency_annual
        FROM clv_base
    ),
    clv_with_percentiles AS (
        SELECT 
            customer_id,
            avg_order_value,
            purchase_frequency_annual,
            ROUND(avg_order_value * purchase_frequency_annual * 3, 2) AS estimated_clv_3yr
        FROM clv_calculated
    )
    SELECT * FROM clv_with_percentiles WHERE customer_id = 600;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test CLV Calculation - Non-Zero',
        'CLV Analysis',
        CASE WHEN estimated_clv_3yr > 0 THEN 'PASS' ELSE 'FAIL' END,
        '> 0',
        CAST(estimated_clv_3yr AS VARCHAR)
    FROM test7_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Purchase Frequency Calculation',
        'CLV Analysis',
        CASE WHEN purchase_frequency_annual > 0 THEN 'PASS' ELSE 'FAIL' END,
        '> 0',
        CAST(purchase_frequency_annual AS VARCHAR)
    FROM test7_result;
    
    DROP TABLE test7_result;
ROLLBACK;

-- =====================================================
-- TEST 8: Customer Tier Assignment
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (700, 'Diana', 'Prince', 'diana@email.com', '555-4000', '400 Hero Ln', 'Metropolis', 'NY', 'USA',
         DATE '1987-09-30', 'Female', '100K+', 'VIP', DATE '2020-01-01'),
        (701, 'Bruce', 'Wayne', 'bruce@email.com', '555-4001', '500 Gotham St', 'Gotham', 'NY', 'USA',
         DATE '1980-02-19', 'Male', '100K+', 'VIP', DATE '2020-01-01');
    
    -- High CLV customer
    INSERT INTO orders VALUES
        (6001, 700, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 5000.00),
        (6002, 700, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 6000.00),
        (6003, 700, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 5500.00);
    
    -- Low CLV customer
    INSERT INTO orders VALUES
        (6004, 701, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 50.00),
        (6005, 701, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 60.00);
    
    CREATE TEMP TABLE test8_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, signup_date FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT customer_id, CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    ),
    orders_last_year AS (
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
    clv_base AS (
        SELECT 
            ao.customer_id,
            ao.total_orders,
            ao.total_revenue,
            ao.avg_order_value,
            ao.last_order_date - ao.first_order_date AS customer_lifespan_days
        FROM aggregated_orders ao
        INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
        WHERE ao.total_orders >= 2
    ),
    clv_calculated AS (
        SELECT 
            customer_id,
            avg_order_value,
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
    )
    SELECT 
        customer_id,
        estimated_clv_3yr,
        clv_percentile,
        CASE
            WHEN clv_percentile >= 0.9 THEN 'Platinum'
            WHEN clv_percentile >= 0.7 THEN 'Gold'
            WHEN clv_percentile >= 0.4 THEN 'Silver'
            ELSE 'Bronze'
        END AS customer_tier
    FROM clv_with_percentiles
    ORDER BY customer_id;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Customer Tier - High Value',
        'Customer Tier',
        CASE WHEN customer_tier IN ('Platinum', 'Gold') THEN 'PASS' ELSE 'FAIL' END,
        'Platinum or Gold',
        customer_tier
    FROM test8_result
    WHERE customer_id = 700;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Customer Tier - Low Value',
        'Customer Tier',
        CASE WHEN customer_tier IN ('Bronze', 'Silver') THEN 'PASS' ELSE 'FAIL' END,
        'Bronze or Silver',
        customer_tier
    FROM test8_result
    WHERE customer_id = 701;
    
    DROP TABLE test8_result;
ROLLBACK;

-- =====================================================
-- TEST 9: Churn Risk Classification
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (800, 'Active', 'Customer', 'active@email.com', '555-5000', '600 Active St', 'Boston', 'MA', 'USA',
         DATE '1995-01-01', 'Male', '50K-75K', 'Standard', DATE '2022-01-01'),
        (801, 'AtRisk', 'Customer', 'atrisk@email.com', '555-5001', '700 Risk Ave', 'Boston', 'MA', 'USA',
         DATE '1995-01-01', 'Female', '50K-75K', 'Standard', DATE '2022-01-01'),
        (802, 'HighRisk', 'Customer', 'highrisk@email.com', '555-5002', '800 Danger Rd', 'Boston', 'MA', 'USA',
         DATE '1995-01-01', 'Male', '50K-75K', 'Standard', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (7001, 800, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
        (7002, 801, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 200.00),
        (7003, 802, CURRENT_DATE - INTERVAL '200' DAY, 'COMPLETED', 300.00);
    
    CREATE TEMP TABLE test9_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT customer_id, CURRENT_DATE - signup_date AS days_as_customer
        FROM raw_customers
    ),
    orders_last_year AS (
        SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT customer_id, MAX(order_date) AS last_order_date
        FROM orders_last_year
        GROUP BY customer_id
    ),
    aggregated_orders AS (
        SELECT customer_id, last_order_date
        FROM customer_order_summary
    ),
    merged_data AS (
        SELECT 
            cc.customer_id,
            ao.last_order_date,
            CASE WHEN ao.last_order_date IS NOT NULL THEN CURRENT_DATE - ao.last_order_date END AS days_since_last_order
        FROM cleaned_customers cc
        LEFT JOIN aggregated_orders ao ON cc.customer_id = ao.customer_id
    )
    SELECT 
        customer_id,
        days_since_last_order,
        CASE
            WHEN days_since_last_order IS NULL THEN 'Active'
            WHEN days_since_last_order > 180 THEN 'High Risk'
            WHEN days_since_last_order > 90 THEN 'Medium Risk'
            WHEN days_since_last_order > 30 THEN 'Low Risk'
            ELSE 'Active'
        END AS churn_risk
    FROM merged_data
    ORDER BY customer_id;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Churn Risk - Active Customer',
        'Churn Risk',
        CASE WHEN churn_risk = 'Active' THEN 'PASS' ELSE 'FAIL' END,
        'Active',
        churn_risk
    FROM test9_result
    WHERE customer_id = 800;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Churn Risk - Medium Risk',
        'Churn Risk',
        CASE WHEN churn_risk = 'Medium Risk' THEN 'PASS' ELSE 'FAIL' END,
        'Medium Risk',
        churn_risk
    FROM test9_result
    WHERE customer_id = 801;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Churn Risk - High Risk',
        'Churn Risk',
        CASE WHEN churn_risk = 'High Risk' THEN 'PASS' ELSE 'FAIL' END,
        'High Risk',
        churn_risk
    FROM test9_result
    WHERE customer_id = 802;
    
    DROP TABLE test9_result;
ROLLBACK;

-- =====================================================
-- TEST 10: Edge Case - Customer with No Orders
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (900, 'NoOrder', 'Customer', 'noorder@email.com', '555-6000', '900 Empty St', 'Seattle', 'WA', 'USA',
         DATE '1993-06-15', 'Male', '50K-75K', 'Standard', DATE '2023-01-01');
    
    CREATE TEMP TABLE test10_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, signup_date
        FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT 
            customer_id,
            UPPER(TRIM(first_name)) AS first_name,
            UPPER(TRIM(last_name)) AS last_name,
            LOWER(TRIM(email)) AS email,
            signup_date,
            CURRENT_DATE - signup_date AS days_as_customer
        FROM filtered_customers
    ),
    orders_last_year AS (
        SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT customer_id, COUNT(DISTINCT order_id) AS total_orders
        FROM orders_last_year
        GROUP BY customer_id
    ),
    completed_orders_summary AS (
        SELECT customer_id, SUM(total_amount) AS total_revenue
        FROM orders_last_year WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    aggregated_orders AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            COALESCE(comp.total_revenue, 0) AS total_revenue
        FROM customer_order_summary co
        LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
    ),
    merged_data AS (
        SELECT 
            cc.customer_id,
            cc.first_name,
            cc.last_name,
            cc.email,
            cc.days_as_customer,
            COALESCE(ao.total_orders, 0) AS total_orders,
            COALESCE(ao.total_revenue, 0) AS lifetime_revenue
        FROM cleaned_customers cc
        LEFT JOIN aggregated_orders ao ON cc.customer_id = ao.customer_id
    )
    SELECT * FROM merged_data WHERE customer_id = 900;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Edge Case - Zero Orders',
        'Edge Cases',
        CASE WHEN total_orders = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0',
        CAST(total_orders AS VARCHAR)
    FROM test10_result;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Edge Case - Zero Revenue',
        'Edge Cases',
        CASE WHEN lifetime_revenue = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0',
        CAST(lifetime_revenue AS VARCHAR)
    FROM test10_result;
    
    DROP TABLE test10_result;
ROLLBACK;

-- =====================================================
-- TEST 11: Edge Case - NULL Email Filtering
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1000, 'Valid', 'Customer', 'valid@email.com', '555-7000', '1000 Valid St', 'Portland', 'OR', 'USA',
         DATE '1991-08-20', 'Female', '75K-100K', 'Premium', DATE '2022-06-01'),
        (1001, 'Invalid', 'Customer', NULL, '555-7001', '1001 Invalid St', 'Portland', 'OR', 'USA',
         DATE '1991-08-20', 'Male', '75K-100K', 'Premium', DATE '2022-06-01');
    
    CREATE TEMP TABLE test11_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT COUNT(*) as valid_customer_count
    FROM deduplicated_customers
    WHERE row_num = 1;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test NULL Email Filtering',
        'Edge Cases',
        CASE WHEN valid_customer_count = 1 THEN 'PASS' ELSE 'FAIL' END,
        '1',
        CAST(valid_customer_count AS VARCHAR)
    FROM test11_result;
    
    DROP TABLE test11_result;
ROLLBACK;

-- =====================================================
-- TEST 12: Window Function - ROW_NUMBER Ordering
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1100, 'First', 'Signup', 'duplicate@email.com', '555-8000', '1100 First St', 'Denver', 'CO', 'USA',
         DATE '1989-12-05', 'Male', '50K-75K', 'Standard', DATE '2021-01-01'),
        (1101, 'Second', 'Signup', 'duplicate@email.com', '555-8001', '1101 Second St', 'Denver', 'CO', 'USA',
         DATE '1989-12-05', 'Male', '50K-75K', 'Standard', DATE '2022-06-01'),
        (1102, 'Third', 'Signup', 'duplicate@email.com', '555-8002', '1102 Third St', 'Denver', 'CO', 'USA',
         DATE '1989-12-05', 'Male', '50K-75K', 'Standard', DATE '2023-12-01');
    
    CREATE TEMP TABLE test12_result AS
    WITH deduplicated_customers AS (
        SELECT 
            customer_id,
            first_name,
            signup_date,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT customer_id, first_name, signup_date
    FROM deduplicated_customers
    WHERE row_num = 1 AND customer_id IN (1100, 1101, 1102);
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test ROW_NUMBER Keeps Latest Signup',
        'Window Functions',
        CASE WHEN customer_id = 1102 AND first_name = 'Third' THEN 'PASS' ELSE 'FAIL' END,
        'customer_id=1102, first_name=Third',
        'customer_id=' || customer_id || ', first_name=' || first_name
    FROM test12_result;
    
    DROP TABLE test12_result;
ROLLBACK;

-- =====================================================
-- TEST 13: NTILE Window Function for RFM Scoring
-- =====================================================
BEGIN;
    DELETE FROM orders;
    
    INSERT INTO orders VALUES
        (8001, 1200, CURRENT_DATE - INTERVAL '5' DAY, 'COMPLETED', 1000.00),
        (8002, 1201, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 500.00),
        (8003, 1202, CURRENT_DATE - INTERVAL '100' DAY, 'COMPLETED', 200.00),
        (8004, 1203, CURRENT_DATE - INTERVAL '150' DAY, 'COMPLETED', 100.00),
        (8005, 1204, CURRENT_DATE - INTERVAL '200' DAY, 'COMPLETED', 50.00);
    
    CREATE TEMP TABLE test13_result AS
    WITH orders_last_year AS (
        SELECT * FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
    ),
    customer_order_summary AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS total_orders,
            MAX(order_date) AS last_order_date
        FROM orders_last_year
        GROUP BY customer_id
    ),
    completed_orders_summary AS (
        SELECT customer_id, SUM(total_amount) AS total_revenue
        FROM orders_last_year WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    aggregated_orders AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            co.last_order_date,
            COALESCE(comp.total_revenue, 0) AS total_revenue
        FROM customer_order_summary co
        LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            CURRENT_DATE - last_order_date AS recency_days,
            total_orders AS frequency,
            total_revenue AS monetary
        FROM aggregated_orders
        WHERE total_orders > 0
    ),
    rfm_quantiles AS (
        SELECT 
            customer_id,
            NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
            NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
            NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
        FROM rfm_base
    )
    SELECT 
        customer_id,
        recency_score,
        frequency_score,
        monetary_score
    FROM rfm_quantiles
    ORDER BY customer_id;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test NTILE Scores Range 1-5',
        'Window Functions',
        CASE WHEN recency_score BETWEEN 1 AND 5 
             AND frequency_score BETWEEN 1 AND 5 
             AND monetary_score BETWEEN 1 AND 5 THEN 'PASS' ELSE 'FAIL' END,
        'All scores between 1-5',
        'R=' || recency_score || ', F=' || frequency_score || ', M=' || monetary_score
    FROM test13_result
    LIMIT 1;
    
    DROP TABLE test13_result;
ROLLBACK;

-- =====================================================
-- TEST 14: PERCENT_RANK for CLV Percentiles
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1300, 'Low', 'CLV', 'low@email.com', '555-9000', '1300 Low St', 'Austin', 'TX', 'USA',
         DATE '1992-03-10', 'Male', '50K-75K', 'Standard', DATE '2022-01-01'),
        (1301, 'High', 'CLV', 'high@email.com', '555-9001', '1301 High St', 'Austin', 'TX', 'USA',
         DATE '1992-03-10', 'Female', '100K+', 'VIP', DATE '2022-01-01');
    
    INSERT INTO orders VALUES
        (9001, 1300, DATE '2023-01-01', 'COMPLETED', 100.00),
        (9002, 1300, DATE '2023-06-01', 'COMPLETED', 100.00),
        (9003, 1301, DATE '2023-01-01', 'COMPLETED', 5000.00),
        (9004, 1301, DATE '2023-06-01', 'COMPLETED', 5000.00);
    
    CREATE TEMP TABLE test14_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT customer_id, CURRENT_DATE - signup_date AS days_as_customer
        FROM raw_customers
    ),
    orders_last_year AS (
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
        FROM orders_last_year WHERE status = 'COMPLETED'
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
    clv_base AS (
        SELECT 
            ao.customer_id,
            ao.total_orders,
            ao.avg_order_value,
            ao.last_order_date - ao.first_order_date AS customer_lifespan_days
        FROM aggregated_orders ao
        INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
        WHERE ao.total_orders >= 2
    ),
    clv_calculated AS (
        SELECT 
            customer_id,
            avg_order_value,
            CASE 
                WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                ELSE total_orders
            END AS purchase_frequency_annual
        FROM clv_base
    ),
    clv_with_percentiles AS (
        SELECT 
            customer_id,
            PERCENT_RANK() OVER (ORDER BY avg_order_value * purchase_frequency_annual) AS clv_percentile
        FROM clv_calculated
    )
    SELECT customer_id, clv_percentile
    FROM clv_with_percentiles
    ORDER BY customer_id;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test PERCENT_RANK Range 0-1',
        'Window Functions',
        CASE WHEN clv_percentile >= 0 AND clv_percentile <= 1 THEN 'PASS' ELSE 'FAIL' END,
        '0 <= percentile <= 1',
        CAST(clv_percentile AS VARCHAR)
    FROM test14_result
    LIMIT 1;
    
    DROP TABLE test14_result;
ROLLBACK;

-- =====================================================
-- TEST 15: Negative Test - Invalid Date Calculations
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    
    INSERT INTO raw_customers VALUES
        (1400, 'Future', 'Customer', 'future@email.com', '555-1400', '1400 Future St', 'Miami', 'FL', 'USA',
         DATE '2050-01-01', 'Male', '50K-75K', 'Standard', DATE '2023-01-01');
    
    CREATE TEMP TABLE test15_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, birth_date FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT 
            customer_id,
            (CURRENT_DATE - birth_date) / 365.0 AS age
        FROM filtered_customers
    )
    SELECT customer_id, age
    FROM cleaned_customers
    WHERE customer_id = 1400;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Negative Age Detection',
        'Negative Tests',
        CASE WHEN age < 0 THEN 'PASS' ELSE 'FAIL' END,
        'age < 0',
        CAST(age AS VARCHAR)
    FROM test15_result;
    
    DROP TABLE test15_result;
ROLLBACK;

-- =====================================================
-- TEST 16: Negative Test - Division by Zero Protection
-- =====================================================
BEGIN;
    DELETE FROM raw_customers;
    DELETE FROM orders;
    
    INSERT INTO raw_customers VALUES
        (1500, 'Same', 'Day', 'sameday@email.com', '555-1500', '1500 Same St', 'Phoenix', 'AZ', 'USA',
         DATE '1990-01-01', 'Male', '50K-75K', 'Standard', DATE '2023-01-01');
    
    INSERT INTO orders VALUES
        (10001, 1500, DATE '2023-06-01', 'COMPLETED', 100.00),
        (10002, 1500, DATE '2023-06-01', 'COMPLETED', 200.00);
    
    CREATE TEMP TABLE test16_result AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id FROM deduplicated_customers WHERE row_num = 1
    ),
    cleaned_customers AS (
        SELECT customer_id, CURRENT_DATE - signup_date AS days_as_customer
        FROM raw_customers
    ),
    orders_last_year AS (
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
            AVG(total_amount) AS avg_order_value
        FROM orders_last_year WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    aggregated_orders AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            co.first_order_date,
            co.last_order_date,
            COALESCE(comp.avg_order_value, 0) AS avg_order_value
        FROM customer_order_summary co
        LEFT JOIN completed_orders_summary comp ON co.customer_id = comp.customer_id
    ),
    clv_base AS (
        SELECT 
            ao.customer_id,
            ao.total_orders,
            ao.avg_order_value,
            ao.last_order_date - ao.first_order_date AS customer_lifespan_days
        FROM aggregated_orders ao
        INNER JOIN cleaned_customers cc ON ao.customer_id = cc.customer_id
        WHERE ao.total_orders >= 2
    ),
    clv_calculated AS (
        SELECT 
            customer_id,
            customer_lifespan_days,
            CASE 
                WHEN customer_lifespan_days > 0 THEN (total_orders * 365.0 / customer_lifespan_days)
                ELSE total_orders
            END AS purchase_frequency_annual
        FROM clv_base
    )
    SELECT customer_id, customer_lifespan_days, purchase_frequency_annual
    FROM clv_calculated
    WHERE customer_id = 1500;
    
    INSERT INTO test_results (test_name, test_category, status, expected_value, actual_value)
    SELECT 
        'Test Division by Zero Protection',
        'Negative Tests',
        CASE WHEN customer_lifespan_days = 0 AND purchase_frequency_annual IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
        'No NULL or error when lifespan=0',
        'lifespan=' || customer_lifespan_days || ', freq=' || COALESCE(CAST(purchase_frequency_annual AS VARCHAR
