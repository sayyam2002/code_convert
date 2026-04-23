-- ============================================================================
-- COMPLETE SQL UNIT TEST SUITE FOR CUSTOMER 360 QUERY
-- Testing Framework: pgTAP (PostgreSQL Test Anything Protocol)
-- ============================================================================

BEGIN;

-- Load pgTAP extension
CREATE EXTENSION IF NOT EXISTS pgtap;

-- ============================================================================
-- TEST SETUP: Create test tables and sample data
-- ============================================================================

CREATE TEMP TABLE raw_customers (
    customer_id INTEGER,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
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

CREATE TEMP TABLE orders (
    order_id INTEGER,
    customer_id INTEGER,
    order_date DATE,
    status VARCHAR(50),
    total_amount NUMERIC(10,2)
);

CREATE TEMP TABLE order_items (
    order_item_id INTEGER,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    unit_price NUMERIC(10,2)
);

CREATE TEMP TABLE products (
    product_id INTEGER,
    category VARCHAR(100)
);

-- ============================================================================
-- TEST 1: Deduplication Logic - Email-based deduplication
-- ============================================================================

CREATE FUNCTION test_deduplication_by_email()
RETURNS SETOF TEXT AS $$
BEGIN
    -- Setup: Insert duplicate customers with same email
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main St', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01'),
        (2, 'John', 'Doe', 'john@example.com', '555-0002', '456 Oak Ave', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-06-01');
    
    -- Execute query and store result
    CREATE TEMP TABLE test_result_dedup AS
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT customer_id, email, signup_date, row_num
    FROM deduplicated_customers;
    
    -- Test: Only most recent signup should have row_num = 1
    RETURN NEXT ok(
        (SELECT COUNT(*) FROM test_result_dedup WHERE row_num = 1) = 1,
        'Should have exactly one record with row_num = 1 per email'
    );
    
    RETURN NEXT is(
        (SELECT customer_id FROM test_result_dedup WHERE row_num = 1),
        2,
        'Most recent signup (customer_id 2) should be selected'
    );
    
    DROP TABLE test_result_dedup;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 2: NULL Handling - Email and customer_id filtering
-- ============================================================================

CREATE FUNCTION test_null_filtering()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'Valid', 'Customer', 'valid@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01'),
        (NULL, 'Null', 'ID', 'nullid@example.com', '555-0002', '456 Oak', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01'),
        (3, 'Null', 'Email', NULL, '555-0003', '789 Pine', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    CREATE TEMP TABLE test_result_nulls AS
    WITH deduplicated_customers AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    )
    SELECT customer_id, email FROM deduplicated_customers WHERE row_num = 1;
    
    RETURN NEXT is(
        (SELECT COUNT(*) FROM test_result_nulls),
        1::BIGINT,
        'Should exclude records with NULL email or customer_id'
    );
    
    RETURN NEXT is(
        (SELECT customer_id FROM test_result_nulls),
        1,
        'Only valid customer should remain'
    );
    
    DROP TABLE test_result_nulls;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 3: Data Cleaning - TRIM and UPPER/LOWER transformations
-- ============================================================================

CREATE FUNCTION test_data_cleaning()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, '  john  ', '  DOE  ', '  JOHN@EXAMPLE.COM  ', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    CREATE TEMP TABLE test_result_clean AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers WHERE row_num = 1
    )
    SELECT 
        UPPER(TRIM(first_name)) AS first_name,
        UPPER(TRIM(last_name)) AS last_name,
        LOWER(TRIM(email)) AS email
    FROM filtered_customers;
    
    RETURN NEXT is(
        (SELECT first_name FROM test_result_clean),
        'JOHN',
        'First name should be trimmed and uppercased'
    );
    
    RETURN NEXT is(
        (SELECT last_name FROM test_result_clean),
        'DOE',
        'Last name should be trimmed and uppercased'
    );
    
    RETURN NEXT is(
        (SELECT email FROM test_result_clean),
        'john@example.com',
        'Email should be trimmed and lowercased'
    );
    
    DROP TABLE test_result_clean;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 4: COALESCE Default Values
-- ============================================================================

CREATE FUNCTION test_coalesce_defaults()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', NULL, NULL, NULL, NULL, NULL, '1980-01-01', NULL, NULL, NULL, '2023-01-01');
    
    CREATE TEMP TABLE test_result_coalesce AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers WHERE row_num = 1
    )
    SELECT 
        COALESCE(phone, 'N/A') AS phone,
        COALESCE(address, 'Unknown') AS address,
        COALESCE(city, 'Unknown') AS city,
        COALESCE(state, 'Unknown') AS state,
        COALESCE(country, 'USA') AS country,
        COALESCE(gender, 'Unknown') AS gender,
        COALESCE(income_bracket, 'Not Specified') AS income_bracket,
        COALESCE(customer_segment, 'Standard') AS customer_segment
    FROM filtered_customers;
    
    RETURN NEXT is((SELECT phone FROM test_result_coalesce), 'N/A', 'NULL phone should default to N/A');
    RETURN NEXT is((SELECT address FROM test_result_coalesce), 'Unknown', 'NULL address should default to Unknown');
    RETURN NEXT is((SELECT city FROM test_result_coalesce), 'Unknown', 'NULL city should default to Unknown');
    RETURN NEXT is((SELECT state FROM test_result_coalesce), 'Unknown', 'NULL state should default to Unknown');
    RETURN NEXT is((SELECT country FROM test_result_coalesce), 'USA', 'NULL country should default to USA');
    RETURN NEXT is((SELECT gender FROM test_result_coalesce), 'Unknown', 'NULL gender should default to Unknown');
    RETURN NEXT is((SELECT income_bracket FROM test_result_coalesce), 'Not Specified', 'NULL income_bracket should default to Not Specified');
    RETURN NEXT is((SELECT customer_segment FROM test_result_coalesce), 'Standard', 'NULL customer_segment should default to Standard');
    
    DROP TABLE test_result_coalesce;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 5: Age Calculation
-- ============================================================================

CREATE FUNCTION test_age_calculation()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', CURRENT_DATE - INTERVAL '30 years', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    CREATE TEMP TABLE test_result_age AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers WHERE row_num = 1
    )
    SELECT 
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS age
    FROM filtered_customers;
    
    RETURN NEXT ok(
        (SELECT age FROM test_result_age) BETWEEN 29 AND 31,
        'Age should be approximately 30 years'
    );
    
    DROP TABLE test_result_age;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 6: Days as Customer Calculation
-- ============================================================================

CREATE FUNCTION test_days_as_customer()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '100 days');
    
    CREATE TEMP TABLE test_result_days AS
    WITH deduplicated_customers AS (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ),
    filtered_customers AS (
        SELECT customer_id, first_name, last_name, email, phone, address, city, state, country, 
            birth_date, gender, income_bracket, customer_segment, signup_date
        FROM deduplicated_customers WHERE row_num = 1
    )
    SELECT 
        EXTRACT(DAY FROM CURRENT_DATE - signup_date) AS days_as_customer
    FROM filtered_customers;
    
    RETURN NEXT is(
        (SELECT days_as_customer FROM test_result_days),
        100::NUMERIC,
        'Days as customer should be 100'
    );
    
    DROP TABLE test_result_days;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 7: Order Filtering - Last 365 Days
-- ============================================================================

CREATE FUNCTION test_order_filtering_365_days()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '400 days', 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '200 days', 'COMPLETED', 150.00);
    
    CREATE TEMP TABLE test_result_filter AS
    SELECT customer_id, order_id, order_date
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '365 days';
    
    RETURN NEXT is(
        (SELECT COUNT(*) FROM test_result_filter),
        2::BIGINT,
        'Should include only orders from last 365 days'
    );
    
    RETURN NEXT ok(
        NOT EXISTS(SELECT 1 FROM test_result_filter WHERE order_id = 2),
        'Order from 400 days ago should be excluded'
    );
    
    DROP TABLE test_result_filter;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 8: Customer Order Summary Aggregation
-- ============================================================================

CREATE FUNCTION test_customer_order_summary()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90 days', 'COMPLETED', 150.00);
    
    CREATE TEMP TABLE test_result_summary AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS total_orders,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date
    FROM orders_filtered
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT total_orders FROM test_result_summary),
        3::BIGINT,
        'Should count 3 total orders'
    );
    
    RETURN NEXT is(
        (SELECT first_order_date FROM test_result_summary),
        CURRENT_DATE - INTERVAL '90 days',
        'First order date should be 90 days ago'
    );
    
    RETURN NEXT is(
        (SELECT last_order_date FROM test_result_summary),
        CURRENT_DATE - INTERVAL '30 days',
        'Last order date should be 30 days ago'
    );
    
    DROP TABLE test_result_summary;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 9: Completed Orders Aggregation
-- ============================================================================

CREATE FUNCTION test_completed_orders()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90 days', 'CANCELLED', 150.00);
    
    CREATE TEMP TABLE test_result_completed AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS completed_orders,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value
    FROM orders_filtered
    WHERE status = 'COMPLETED'
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT completed_orders FROM test_result_completed),
        2::BIGINT,
        'Should count 2 completed orders'
    );
    
    RETURN NEXT is(
        (SELECT total_revenue FROM test_result_completed),
        300.00::NUMERIC,
        'Total revenue should be 300.00'
    );
    
    RETURN NEXT is(
        (SELECT avg_order_value FROM test_result_completed),
        150.00::NUMERIC,
        'Average order value should be 150.00'
    );
    
    DROP TABLE test_result_completed;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 10: Cancelled and Returned Orders
-- ============================================================================

CREATE FUNCTION test_cancelled_returned_orders()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'CANCELLED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '90 days', 'CANCELLED', 150.00),
        (4, 1, CURRENT_DATE - INTERVAL '120 days', 'RETURNED', 75.00);
    
    CREATE TEMP TABLE test_result_cancelled AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
    FROM orders_filtered
    WHERE status = 'CANCELLED'
    GROUP BY customer_id;
    
    CREATE TEMP TABLE test_result_returned AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
    FROM orders_filtered
    WHERE status = 'RETURNED'
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT cancelled_orders FROM test_result_cancelled),
        2::BIGINT,
        'Should count 2 cancelled orders'
    );
    
    RETURN NEXT is(
        (SELECT returned_orders FROM test_result_returned),
        1::BIGINT,
        'Should count 1 returned order'
    );
    
    DROP TABLE test_result_cancelled;
    DROP TABLE test_result_returned;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 11: Revenue Last 30 Days
-- ============================================================================

CREATE FUNCTION test_revenue_last_30_days()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '15 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '25 days', 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '45 days', 'COMPLETED', 150.00);
    
    CREATE TEMP TABLE test_result_30days AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT customer_id, 
        SUM(total_amount) AS revenue_last_30_days,
        COUNT(DISTINCT order_id) AS orders_last_30_days
    FROM orders_filtered
    WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT revenue_last_30_days FROM test_result_30days),
        300.00::NUMERIC,
        'Revenue last 30 days should be 300.00'
    );
    
    RETURN NEXT is(
        (SELECT orders_last_30_days FROM test_result_30days),
        2::BIGINT,
        'Orders last 30 days should be 2'
    );
    
    DROP TABLE test_result_30days;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 12: Revenue Last 90 Days
-- ============================================================================

CREATE FUNCTION test_revenue_last_90_days()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '15 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 200.00),
        (3, 1, CURRENT_DATE - INTERVAL '100 days', 'COMPLETED', 150.00);
    
    CREATE TEMP TABLE test_result_90days AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    )
    SELECT customer_id, SUM(total_amount) AS revenue_last_90_days
    FROM orders_filtered
    WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT revenue_last_90_days FROM test_result_90days),
        300.00::NUMERIC,
        'Revenue last 90 days should be 300.00'
    );
    
    DROP TABLE test_result_90days;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 13: Customer Orders Join with COALESCE
-- ============================================================================

CREATE FUNCTION test_customer_orders_coalesce()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01'),
        (2, 'Jane', 'Smith', 'jane@example.com', '555-0002', '456 Oak', 'Boston', 'MA', 'USA', '1985-01-01', 'Female', '75-100K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00);
    
    CREATE TEMP TABLE test_result_coalesce_join AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
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
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    )
    SELECT 
        cos.customer_id,
        COALESCE(co.completed_orders, 0) AS completed_orders,
        COALESCE(co.total_revenue, 0) AS lifetime_revenue
    FROM customer_order_summary cos
    LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id;
    
    RETURN NEXT is(
        (SELECT completed_orders FROM test_result_coalesce_join WHERE customer_id = 1),
        1::BIGINT,
        'Customer 1 should have 1 completed order'
    );
    
    RETURN NEXT is(
        (SELECT lifetime_revenue FROM test_result_coalesce_join WHERE customer_id = 1),
        100.00::NUMERIC,
        'Customer 1 should have 100.00 lifetime revenue'
    );
    
    DROP TABLE test_result_coalesce_join;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 14: Category Spend Calculation
-- ============================================================================

CREATE FUNCTION test_category_spend()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00);
    
    INSERT INTO products VALUES
        (101, 'Electronics'),
        (102, 'Clothing');
    
    INSERT INTO order_items VALUES
        (1, 1, 101, 2, 50.00),
        (2, 1, 102, 3, 25.00);
    
    CREATE TEMP TABLE test_result_category AS
    WITH completed_order_items AS (
        SELECT oi.order_item_id, oi.order_id, oi.product_id, oi.quantity, oi.unit_price,
            o.customer_id
        FROM order_items oi
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.status = 'COMPLETED'
    )
    SELECT 
        coi.customer_id,
        p.category,
        COUNT(DISTINCT coi.order_item_id) AS items_purchased,
        SUM(coi.quantity) AS total_quantity,
        SUM(coi.quantity * coi.unit_price) AS category_spend
    FROM completed_order_items coi
    JOIN products p ON coi.product_id = p.product_id
    GROUP BY coi.customer_id, p.category;
    
    RETURN NEXT is(
        (SELECT COUNT(*) FROM test_result_category),
        2::BIGINT,
        'Should have 2 categories'
    );
    
    RETURN NEXT is(
        (SELECT category_spend FROM test_result_category WHERE category = 'Electronics'),
        100.00::NUMERIC,
        'Electronics spend should be 100.00'
    );
    
    RETURN NEXT is(
        (SELECT category_spend FROM test_result_category WHERE category = 'Clothing'),
        75.00::NUMERIC,
        'Clothing spend should be 75.00'
    );
    
    DROP TABLE test_result_category;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 15: Top Categories Ranking
-- ============================================================================

CREATE FUNCTION test_top_categories_ranking()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00);
    
    INSERT INTO products VALUES
        (101, 'Electronics'),
        (102, 'Clothing'),
        (103, 'Books'),
        (104, 'Toys');
    
    INSERT INTO order_items VALUES
        (1, 1, 101, 1, 100.00),
        (2, 1, 102, 1, 75.00),
        (3, 1, 103, 1, 50.00),
        (4, 1, 104, 1, 25.00);
    
    CREATE TEMP TABLE test_result_ranking AS
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
            COUNT(DISTINCT coi.order_item_id) AS items_purchased,
            SUM(coi.quantity) AS total_quantity,
            SUM(coi.quantity * coi.unit_price) AS category_spend
        FROM completed_order_items coi
        JOIN products p ON coi.product_id = p.product_id
        GROUP BY coi.customer_id, p.category
    ),
    ranked_categories AS (
        SELECT customer_id, category, category_spend,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY category_spend DESC) AS category_rank
        FROM category_spend
    )
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
    GROUP BY customer_id;
    
    RETURN NEXT is(
        (SELECT top_category_1 FROM test_result_ranking),
        'Electronics',
        'Top category 1 should be Electronics'
    );
    
    RETURN NEXT is(
        (SELECT top_category_1_spend FROM test_result_ranking),
        100.00::NUMERIC,
        'Top category 1 spend should be 100.00'
    );
    
    RETURN NEXT is(
        (SELECT top_category_2 FROM test_result_ranking),
        'Clothing',
        'Top category 2 should be Clothing'
    );
    
    DROP TABLE test_result_ranking;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 16: RFM Scores - NTILE Calculation
-- ============================================================================

CREATE FUNCTION test_rfm_scores()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john1@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01'),
        (2, 'Jane', 'Smith', 'jane2@example.com', '555-0002', '456 Oak', 'Boston', 'MA', 'USA', '1985-01-01', 'Female', '75-100K', 'Premium', '2023-01-01'),
        (3, 'Bob', 'Johnson', 'bob3@example.com', '555-0003', '789 Pine', 'Boston', 'MA', 'USA', '1990-01-01', 'Male', '100K+', 'Premium', '2023-01-01'),
        (4, 'Alice', 'Williams', 'alice4@example.com', '555-0004', '321 Elm', 'Boston', 'MA', 'USA', '1975-01-01', 'Female', '50-75K', 'Premium', '2023-01-01'),
        (5, 'Charlie', 'Brown', 'charlie5@example.com', '555-0005', '654 Maple', 'Boston', 'MA', 'USA', '1988-01-01', 'Male', '75-100K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '10 days', 'COMPLETED', 1000.00),
        (2, 2, CURRENT_DATE - INTERVAL '50 days', 'COMPLETED', 500.00),
        (3, 3, CURRENT_DATE - INTERVAL '100 days', 'COMPLETED', 250.00),
        (4, 4, CURRENT_DATE - INTERVAL '150 days', 'COMPLETED', 100.00),
        (5, 5, CURRENT_DATE - INTERVAL '200 days', 'COMPLETED', 50.00);
    
    CREATE TEMP TABLE test_result_rfm AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
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
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.first_order_date,
            cos.last_order_date,
            COALESCE(co.completed_orders, 0) AS completed_orders,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue,
            COALESCE(co.avg_order_value, 0) AS avg_order_value
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            EXTRACT(DAY FROM CURRENT_DATE - last_order_date) AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    )
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
    FROM rfm_base;
    
    RETURN NEXT ok(
        (SELECT recency_score FROM test_result_rfm WHERE customer_id = 1) >= 1 AND
        (SELECT recency_score FROM test_result_rfm WHERE customer_id = 1) <= 5,
        'Recency score should be between 1 and 5'
    );
    
    RETURN NEXT ok(
        (SELECT frequency_score FROM test_result_rfm WHERE customer_id = 1) >= 1 AND
        (SELECT frequency_score FROM test_result_rfm WHERE customer_id = 1) <= 5,
        'Frequency score should be between 1 and 5'
    );
    
    RETURN NEXT ok(
        (SELECT monetary_score FROM test_result_rfm WHERE customer_id = 1) >= 1 AND
        (SELECT monetary_score FROM test_result_rfm WHERE customer_id = 1) <= 5,
        'Monetary score should be between 1 and 5'
    );
    
    DROP TABLE test_result_rfm;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 17: RFM Segmentation Logic
-- ============================================================================

CREATE FUNCTION test_rfm_segmentation()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'Champion', 'Customer', 'champion@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', '2023-01-01');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '5 days', 'COMPLETED', 1000.00),
        (2, 1, CURRENT_DATE - INTERVAL '10 days', 'COMPLETED', 1000.00),
        (3, 1, CURRENT_DATE - INTERVAL '15 days', 'COMPLETED', 1000.00),
        (4, 1, CURRENT_DATE - INTERVAL '20 days', 'COMPLETED', 1000.00);
    
    CREATE TEMP TABLE test_result_segment AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
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
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.first_order_date,
            cos.last_order_date,
            COALESCE(co.completed_orders, 0) AS completed_orders,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue,
            COALESCE(co.avg_order_value, 0) AS avg_order_value
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    rfm_base AS (
        SELECT 
            customer_id,
            EXTRACT(DAY FROM CURRENT_DATE - last_order_date) AS recency_days,
            total_orders AS frequency,
            lifetime_revenue AS monetary
        FROM customer_orders
        WHERE total_orders > 0
    ),
    rfm_scores AS (
        SELECT 
            customer_id,
            recency_days,
            frequency,
            monetary,
            NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
            NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
            NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score
        FROM rfm_base
    )
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
    FROM rfm_scores;
    
    RETURN NEXT ok(
        (SELECT rfm_segment FROM test_result_segment) IN ('Champions', 'Loyal Customers', 'Potential Loyalists'),
        'High-value customer should be in premium segment'
    );
    
    DROP TABLE test_result_segment;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 18: CLV Calculation - Purchase Frequency
-- ============================================================================

CREATE FUNCTION test_clv_purchase_frequency()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 100.00);
    
    CREATE TEMP TABLE test_result_clv_freq AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
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
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.first_order_date,
            cos.last_order_date,
            COALESCE(co.completed_orders, 0) AS completed_orders,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue,
            COALESCE(co.avg_order_value, 0) AS avg_order_value
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    deduplicated_customers AS (
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
            COALESCE(customer_segment, 'Standard') AS customer_segment,
            signup_date,
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS age,
            EXTRACT(DAY FROM CURRENT_DATE - signup_date) AS days_as_customer
        FROM filtered_customers
    ),
    clv_base AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            co.lifetime_revenue,
            co.avg_order_value,
            EXTRACT(DAY FROM co.last_order_date - co.first_order_date) AS customer_lifespan_days,
            cc.days_as_customer
        FROM customer_orders co
        JOIN cleaned_customers cc ON co.customer_id = cc.customer_id
        WHERE co.total_orders >= 2
    )
    SELECT 
        customer_id,
        total_orders,
        customer_lifespan_days,
        CASE 
            WHEN customer_lifespan_days > 0 THEN total_orders * 365.0 / customer_lifespan_days
            ELSE total_orders
        END AS purchase_frequency_annual
    FROM clv_base;
    
    RETURN NEXT ok(
        (SELECT purchase_frequency_annual FROM test_result_clv_freq) > 0,
        'Purchase frequency should be positive'
    );
    
    RETURN NEXT ok(
        (SELECT customer_lifespan_days FROM test_result_clv_freq) = 30,
        'Customer lifespan should be 30 days'
    );
    
    DROP TABLE test_result_clv_freq;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 19: CLV 3-Year Estimation
-- ============================================================================

CREATE FUNCTION test_clv_3year_estimation()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    INSERT INTO raw_customers VALUES
        (1, 'John', 'Doe', 'john@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 100.00);
    
    CREATE TEMP TABLE test_result_clv_3yr AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
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
    completed_orders AS (
        SELECT 
            customer_id,
            COUNT(DISTINCT order_id) AS completed_orders,
            SUM(total_amount) AS total_revenue,
            AVG(total_amount) AS avg_order_value
        FROM orders_filtered
        WHERE status = 'COMPLETED'
        GROUP BY customer_id
    ),
    customer_orders AS (
        SELECT 
            cos.customer_id,
            cos.total_orders,
            cos.first_order_date,
            cos.last_order_date,
            COALESCE(co.completed_orders, 0) AS completed_orders,
            COALESCE(co.total_revenue, 0) AS lifetime_revenue,
            COALESCE(co.avg_order_value, 0) AS avg_order_value
        FROM customer_order_summary cos
        LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
    ),
    deduplicated_customers AS (
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
            COALESCE(customer_segment, 'Standard') AS customer_segment,
            signup_date,
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS age,
            EXTRACT(DAY FROM CURRENT_DATE - signup_date) AS days_as_customer
        FROM filtered_customers
    ),
    clv_base AS (
        SELECT 
            co.customer_id,
            co.total_orders,
            co.lifetime_revenue,
            co.avg_order_value,
            EXTRACT(DAY FROM co.last_order_date - co.first_order_date) AS customer_lifespan_days,
            cc.days_as_customer
        FROM customer_orders co
        JOIN cleaned_customers cc ON co.customer_id = cc.customer_id
        WHERE co.total_orders >= 2
    ),
    clv_calculated AS (
        SELECT 
            customer_id,
            total_orders,
            lifetime_revenue,
            avg_order_value,
            customer_lifespan_days,
            days_as_customer,
            CASE 
                WHEN customer_lifespan_days > 0 THEN total_orders * 365.0 / customer_lifespan_days
                ELSE total_orders
            END AS purchase_frequency_annual
        FROM clv_base
    )
    SELECT 
        customer_id,
        avg_order_value,
        purchase_frequency_annual,
        ROUND(avg_order_value * purchase_frequency_annual * 3, 2) AS estimated_clv_3yr
    FROM clv_calculated;
    
    RETURN NEXT ok(
        (SELECT estimated_clv_3yr FROM test_result_clv_3yr) > 0,
        'Estimated 3-year CLV should be positive'
    );
    
    DROP TABLE test_result_clv_3yr;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TEST 20: Customer Tier Assignment
-- ============================================================================

CREATE FUNCTION test_customer_tier_assignment()
RETURNS SETOF TEXT AS $$
BEGIN
    TRUNCATE raw_customers, orders, order_items, products;
    
    -- Create 10 customers with varying CLV values
    INSERT INTO raw_customers VALUES
        (1, 'Platinum', 'Customer', 'plat@example.com', '555-0001', '123 Main', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (2, 'Gold', 'Customer', 'gold@example.com', '555-0002', '456 Oak', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (3, 'Silver', 'Customer', 'silver@example.com', '555-0003', '789 Pine', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (4, 'Bronze', 'Customer', 'bronze@example.com', '555-0004', '321 Elm', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (5, 'Customer5', 'Test', 'cust5@example.com', '555-0005', '654 Maple', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (6, 'Customer6', 'Test', 'cust6@example.com', '555-0006', '987 Birch', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (7, 'Customer7', 'Test', 'cust7@example.com', '555-0007', '147 Cedar', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (8, 'Customer8', 'Test', 'cust8@example.com', '555-0008', '258 Spruce', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (9, 'Customer9', 'Test', 'cust9@example.com', '555-0009', '369 Willow', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days'),
        (10, 'Customer10', 'Test', 'cust10@example.com', '555-0010', '741 Ash', 'Boston', 'MA', 'USA', '1980-01-01', 'Male', '50-75K', 'Premium', CURRENT_DATE - INTERVAL '365 days');
    
    INSERT INTO orders VALUES
        (1, 1, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 1000.00),
        (2, 1, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 1000.00),
        (3, 2, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 700.00),
        (4, 2, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 700.00),
        (5, 3, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 400.00),
        (6, 3, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 400.00),
        (7, 4, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 100.00),
        (8, 4, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 100.00),
        (9, 5, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 500.00),
        (10, 5, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 500.00),
        (11, 6, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 600.00),
        (12, 6, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 600.00),
        (13, 7, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 300.00),
        (14, 7, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 300.00),
        (15, 8, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 200.00),
        (16, 8, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 200.00),
        (17, 9, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 800.00),
        (18, 9, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 800.00),
        (19, 10, CURRENT_DATE - INTERVAL '30 days', 'COMPLETED', 900.00),
        (20, 10, CURRENT_DATE - INTERVAL '60 days', 'COMPLETED', 900.00);
    
    CREATE TEMP TABLE test_result_tier AS
    WITH orders_filtered AS (
        SELECT customer_id, order_id, order_date, status, total_amount
        FROM orders
        WHERE order_date >= CURRENT_DATE - INTERVAL '365 days'
    ),
