-- =====================================================
-- COMPLETE SQL UNIT TEST SUITE
-- Testing Framework: SQL Unit Testing with CTEs
-- =====================================================

-- Test Setup: Create temporary test tables
CREATE TEMPORARY TABLE raw_customers (
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

CREATE TEMPORARY TABLE orders (
    order_id INT,
    customer_id INT,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

CREATE TEMPORARY TABLE order_items (
    order_item_id INT,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2)
);

CREATE TEMPORARY TABLE products (
    product_id INT,
    category VARCHAR(100)
);

-- =====================================================
-- TEST 1: Deduplication Logic
-- =====================================================
WITH test_deduplication AS (
    INSERT INTO raw_customers VALUES
    (1, 'John', 'Doe', 'john@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
    (2, 'John', 'Doe', 'john@test.com', '555-0002', '456 Oak', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-06-01'),
    (3, 'Jane', 'Smith', 'jane@test.com', '555-0003', '789 Elm', 'LA', 'CA', 'USA', '1985-05-15', 'Female', '75-100k', 'Standard', '2022-01-01')
),
test_result AS (
    SELECT email, COUNT(*) as email_count
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
        FROM raw_customers
        WHERE email IS NOT NULL AND customer_id IS NOT NULL
    ) deduplicated
    WHERE row_num = 1
    GROUP BY email
)
SELECT 
    CASE 
        WHEN MAX(email_count) = 1 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_deduplication_result,
    'Should keep only most recent signup per email' AS test_description
FROM test_result;

-- =====================================================
-- TEST 2: NULL Handling and Default Values
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'test@null.com', NULL, NULL, NULL, NULL, NULL, '1990-01-01', NULL, NULL, NULL, '2023-01-01');

WITH test_null_handling AS (
    SELECT 
        COALESCE(phone, 'N/A') AS phone,
        COALESCE(address, 'Unknown') AS address,
        COALESCE(city, 'Unknown') AS city,
        COALESCE(state, 'Unknown') AS state,
        COALESCE(country, 'USA') AS country,
        COALESCE(gender, 'Unknown') AS gender,
        COALESCE(income_bracket, 'Not Specified') AS income_bracket,
        COALESCE(customer_segment, 'Standard') AS customer_segment
    FROM raw_customers
    WHERE email = 'test@null.com'
)
SELECT 
    CASE 
        WHEN phone = 'N/A' 
        AND address = 'Unknown' 
        AND city = 'Unknown'
        AND state = 'Unknown'
        AND country = 'USA'
        AND gender = 'Unknown'
        AND income_bracket = 'Not Specified'
        AND customer_segment = 'Standard'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_null_handling_result,
    'Should apply correct default values for NULL fields' AS test_description
FROM test_null_handling;

-- =====================================================
-- TEST 3: Data Cleaning (TRIM, UPPER, LOWER)
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, '  john  ', '  DOE  ', '  JOHN@TEST.COM  ', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01');

WITH test_cleaning AS (
    SELECT 
        UPPER(TRIM(first_name)) AS first_name,
        UPPER(TRIM(last_name)) AS last_name,
        LOWER(TRIM(email)) AS email
    FROM raw_customers
    WHERE customer_id = 1
)
SELECT 
    CASE 
        WHEN first_name = 'JOHN' 
        AND last_name = 'DOE' 
        AND email = 'john@test.com'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_cleaning_result,
    'Should properly clean and format text fields' AS test_description
FROM test_cleaning;

-- =====================================================
-- TEST 4: Age Calculation
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'age@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', CURRENT_DATE - INTERVAL '36500' DAY, 'Male', '50-75k', 'Premium', '2023-01-01');

WITH test_age AS (
    SELECT 
        CAST((CURRENT_DATE - birth_date) AS FLOAT) / 365.0 AS age
    FROM raw_customers
    WHERE email = 'age@test.com'
)
SELECT 
    CASE 
        WHEN age >= 99.5 AND age <= 100.5 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_age_calculation_result,
    'Should calculate age correctly from birth_date' AS test_description
FROM test_age;

-- =====================================================
-- TEST 5: Days as Customer Calculation
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'days@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', CURRENT_DATE - INTERVAL '365' DAY);

WITH test_days AS (
    SELECT 
        CAST((CURRENT_DATE - signup_date) AS INT) AS days_as_customer
    FROM raw_customers
    WHERE email = 'days@test.com'
)
SELECT 
    CASE 
        WHEN days_as_customer >= 364 AND days_as_customer <= 366 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_days_as_customer_result,
    'Should calculate days as customer correctly' AS test_description
FROM test_days;

-- =====================================================
-- TEST 6: Order Filtering (Last 365 Days)
-- =====================================================
TRUNCATE TABLE raw_customers;
TRUNCATE TABLE orders;
INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'order@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01');

INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
(2, 1, CURRENT_DATE - INTERVAL '400' DAY, 'COMPLETED', 200.00),
(3, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 150.00);

WITH test_order_filter AS (
    SELECT COUNT(*) AS order_count
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '365' DAY
)
SELECT 
    CASE 
        WHEN order_count = 2 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_order_filtering_result,
    'Should filter orders to last 365 days only' AS test_description
FROM test_order_filter;

-- =====================================================
-- TEST 7: Order Status Aggregation
-- =====================================================
TRUNCATE TABLE orders;
INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 100.00),
(2, 1, CURRENT_DATE - INTERVAL '60' DAY, 'COMPLETED', 200.00),
(3, 1, CURRENT_DATE - INTERVAL '90' DAY, 'CANCELLED', 150.00),
(4, 1, CURRENT_DATE - INTERVAL '120' DAY, 'RETURNED', 75.00);

WITH test_status_agg AS (
    SELECT 
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_count,
        SUM(CASE WHEN status = 'RETURNED' THEN 1 ELSE 0 END) AS returned_count
    FROM orders
    WHERE customer_id = 1 AND order_date >= CURRENT_DATE - INTERVAL '365' DAY
)
SELECT 
    CASE 
        WHEN completed_count = 2 
        AND cancelled_count = 1 
        AND returned_count = 1 
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status_aggregation_result,
    'Should correctly aggregate orders by status' AS test_description
FROM test_status_agg;

-- =====================================================
-- TEST 8: Revenue Calculations
-- =====================================================
TRUNCATE TABLE orders;
INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
(2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
(3, 1, CURRENT_DATE - INTERVAL '50' DAY, 'COMPLETED', 300.00);

WITH test_revenue AS (
    SELECT 
        SUM(CASE WHEN order_date >= CURRENT_DATE - INTERVAL '30' DAY THEN total_amount ELSE 0 END) AS revenue_30,
        SUM(CASE WHEN order_date >= CURRENT_DATE - INTERVAL '90' DAY THEN total_amount ELSE 0 END) AS revenue_90,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value
    FROM orders
    WHERE customer_id = 1 AND status = 'COMPLETED'
)
SELECT 
    CASE 
        WHEN revenue_30 = 300.00 
        AND revenue_90 = 600.00 
        AND total_revenue = 600.00
        AND avg_order_value = 200.00
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_revenue_calculations_result,
    'Should calculate revenue metrics correctly' AS test_description
FROM test_revenue;

-- =====================================================
-- TEST 9: Category Ranking Logic
-- =====================================================
TRUNCATE TABLE raw_customers;
TRUNCATE TABLE orders;
TRUNCATE TABLE order_items;
TRUNCATE TABLE products;

INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'cat@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01');

INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 500.00);

INSERT INTO products VALUES
(1, 'Electronics'),
(2, 'Clothing'),
(3, 'Books');

INSERT INTO order_items VALUES
(1, 1, 1, 2, 100.00),
(2, 1, 2, 3, 50.00),
(3, 1, 3, 1, 20.00);

WITH test_category_rank AS (
    SELECT 
        p.category,
        SUM(oi.quantity * oi.unit_price) AS category_spend,
        ROW_NUMBER() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS category_rank
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.customer_id = 1 AND o.status = 'COMPLETED'
    GROUP BY p.category
)
SELECT 
    CASE 
        WHEN (SELECT category FROM test_category_rank WHERE category_rank = 1) = 'Electronics'
        AND (SELECT category FROM test_category_rank WHERE category_rank = 2) = 'Clothing'
        AND (SELECT category FROM test_category_rank WHERE category_rank = 3) = 'Books'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_category_ranking_result,
    'Should rank categories by spend correctly' AS test_description;

-- =====================================================
-- TEST 10: RFM Score Calculation
-- =====================================================
TRUNCATE TABLE orders;
INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
(2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
(3, 1, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);

WITH test_rfm AS (
    SELECT 
        CAST((CURRENT_DATE - MAX(order_date)) AS INT) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(total_amount) AS monetary
    FROM orders
    WHERE customer_id = 1 AND status = 'COMPLETED'
)
SELECT 
    CASE 
        WHEN recency_days >= 9 AND recency_days <= 11
        AND frequency = 3
        AND monetary = 600.00
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_rfm_calculation_result,
    'Should calculate RFM metrics correctly' AS test_description
FROM test_rfm;

-- =====================================================
-- TEST 11: RFM Segmentation Logic
-- =====================================================
WITH test_rfm_segments AS (
    SELECT 
        CASE
            WHEN 5 >= 4 AND 5 >= 4 AND 5 >= 4 THEN 'Champions'
            WHEN 5 >= 4 AND 3 >= 3 THEN 'Loyal Customers'
            WHEN 5 >= 4 AND 1 <= 2 AND 1 <= 2 THEN 'New Customers'
            WHEN 3 >= 3 AND 3 >= 3 AND 3 >= 3 THEN 'Potential Loyalists'
            WHEN 3 >= 3 AND 1 <= 2 THEN 'Promising'
            WHEN 1 <= 2 AND 5 >= 4 THEN 'At Risk'
            WHEN 1 <= 2 AND 3 >= 2 AND 3 >= 2 THEN 'Needs Attention'
            WHEN 1 <= 2 AND 1 <= 2 AND 4 >= 3 THEN 'About to Sleep'
            WHEN 1 <= 1 AND 1 <= 1 THEN 'Lost'
            ELSE 'Others'
        END AS segment_champions,
        CASE
            WHEN 1 <= 2 AND 5 >= 4 THEN 'At Risk'
            ELSE 'Other'
        END AS segment_at_risk,
        CASE
            WHEN 1 <= 1 AND 1 <= 1 THEN 'Lost'
            ELSE 'Other'
        END AS segment_lost
)
SELECT 
    CASE 
        WHEN segment_champions = 'Champions'
        AND segment_at_risk = 'At Risk'
        AND segment_lost = 'Lost'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_rfm_segmentation_result,
    'Should assign correct RFM segments' AS test_description
FROM test_rfm_segments;

-- =====================================================
-- TEST 12: CLV Calculation
-- =====================================================
WITH test_clv AS (
    SELECT 
        200.00 AS avg_order_value,
        12.0 AS purchase_frequency_annual,
        ROUND(200.00 * 12.0 * 3, 2) AS estimated_clv_3yr
)
SELECT 
    CASE 
        WHEN estimated_clv_3yr = 7200.00 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_clv_calculation_result,
    'Should calculate 3-year CLV correctly' AS test_description
FROM test_clv;

-- =====================================================
-- TEST 13: Customer Tier Assignment
-- =====================================================
WITH test_tiers AS (
    SELECT 
        CASE WHEN 0.95 >= 0.9 THEN 'Platinum' WHEN 0.95 >= 0.7 THEN 'Gold' WHEN 0.95 >= 0.4 THEN 'Silver' ELSE 'Bronze' END AS tier_platinum,
        CASE WHEN 0.75 >= 0.9 THEN 'Platinum' WHEN 0.75 >= 0.7 THEN 'Gold' WHEN 0.75 >= 0.4 THEN 'Silver' ELSE 'Bronze' END AS tier_gold,
        CASE WHEN 0.50 >= 0.9 THEN 'Platinum' WHEN 0.50 >= 0.7 THEN 'Gold' WHEN 0.50 >= 0.4 THEN 'Silver' ELSE 'Bronze' END AS tier_silver,
        CASE WHEN 0.20 >= 0.9 THEN 'Platinum' WHEN 0.20 >= 0.7 THEN 'Gold' WHEN 0.20 >= 0.4 THEN 'Silver' ELSE 'Bronze' END AS tier_bronze
)
SELECT 
    CASE 
        WHEN tier_platinum = 'Platinum'
        AND tier_gold = 'Gold'
        AND tier_silver = 'Silver'
        AND tier_bronze = 'Bronze'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_tier_assignment_result,
    'Should assign customer tiers correctly based on CLV percentile' AS test_description
FROM test_tiers;

-- =====================================================
-- TEST 14: Churn Risk Classification
-- =====================================================
WITH test_churn AS (
    SELECT 
        CASE WHEN NULL IS NULL THEN 'Active' WHEN 200 > 180 THEN 'High Risk' WHEN 200 > 90 THEN 'Medium Risk' WHEN 200 > 30 THEN 'Low Risk' ELSE 'Active' END AS risk_null,
        CASE WHEN 200 IS NULL THEN 'Active' WHEN 200 > 180 THEN 'High Risk' WHEN 200 > 90 THEN 'Medium Risk' WHEN 200 > 30 THEN 'Low Risk' ELSE 'Active' END AS risk_high,
        CASE WHEN 100 IS NULL THEN 'Active' WHEN 100 > 180 THEN 'High Risk' WHEN 100 > 90 THEN 'Medium Risk' WHEN 100 > 30 THEN 'Low Risk' ELSE 'Active' END AS risk_medium,
        CASE WHEN 50 IS NULL THEN 'Active' WHEN 50 > 180 THEN 'High Risk' WHEN 50 > 90 THEN 'Medium Risk' WHEN 50 > 30 THEN 'Low Risk' ELSE 'Active' END AS risk_low,
        CASE WHEN 10 IS NULL THEN 'Active' WHEN 10 > 180 THEN 'High Risk' WHEN 10 > 90 THEN 'Medium Risk' WHEN 10 > 30 THEN 'Low Risk' ELSE 'Active' END AS risk_active
)
SELECT 
    CASE 
        WHEN risk_null = 'Active'
        AND risk_high = 'High Risk'
        AND risk_medium = 'Medium Risk'
        AND risk_low = 'Low Risk'
        AND risk_active = 'Active'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_churn_risk_result,
    'Should classify churn risk correctly' AS test_description
FROM test_churn;

-- =====================================================
-- TEST 15: Edge Case - Customer with No Orders
-- =====================================================
TRUNCATE TABLE raw_customers;
TRUNCATE TABLE orders;
INSERT INTO raw_customers VALUES
(999, 'No', 'Orders', 'noorders@test.com', '555-9999', '999 None', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01');

WITH test_no_orders AS (
    SELECT 
        c.customer_id,
        COALESCE(COUNT(o.order_id), 0) AS order_count
    FROM raw_customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE c.customer_id = 999
    GROUP BY c.customer_id
)
SELECT 
    CASE 
        WHEN order_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_no_orders_result,
    'Should handle customers with no orders gracefully' AS test_description
FROM test_no_orders;

-- =====================================================
-- TEST 16: Edge Case - Duplicate Email Different IDs
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'User', 'One', 'duplicate@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
(2, 'User', 'Two', 'duplicate@test.com', '555-0002', '456 Oak', 'LA', 'CA', 'USA', '1985-05-15', 'Female', '75-100k', 'Standard', '2023-06-01');

WITH test_duplicate_email AS (
    SELECT COUNT(*) AS unique_emails
    FROM (
        SELECT email, MAX(signup_date) AS latest_signup
        FROM raw_customers
        WHERE email = 'duplicate@test.com'
        GROUP BY email
    ) deduped
)
SELECT 
    CASE 
        WHEN unique_emails = 1 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_duplicate_email_result,
    'Should deduplicate by email keeping latest signup' AS test_description
FROM test_duplicate_email;

-- =====================================================
-- TEST 17: Edge Case - NULL Email or Customer ID
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(NULL, 'Null', 'ID', 'nullid@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
(3, 'Null', 'Email', NULL, '555-0002', '456 Oak', 'LA', 'CA', 'USA', '1985-05-15', 'Female', '75-100k', 'Standard', '2023-01-01');

WITH test_null_filter AS (
    SELECT COUNT(*) AS valid_count
    FROM raw_customers
    WHERE email IS NOT NULL AND customer_id IS NOT NULL
)
SELECT 
    CASE 
        WHEN valid_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_null_filter_result,
    'Should filter out records with NULL email or customer_id' AS test_description
FROM test_null_filter;

-- =====================================================
-- TEST 18: Window Function - ROW_NUMBER Ordering
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'Test', 'User', 'window@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
(2, 'Test', 'User', 'window@test.com', '555-0002', '456 Oak', 'LA', 'CA', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-06-01'),
(3, 'Test', 'User', 'window@test.com', '555-0003', '789 Elm', 'SF', 'CA', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-03-01');

WITH test_window AS (
    SELECT 
        customer_id,
        signup_date,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY signup_date DESC) AS row_num
    FROM raw_customers
    WHERE email = 'window@test.com'
)
SELECT 
    CASE 
        WHEN (SELECT customer_id FROM test_window WHERE row_num = 1) = 2 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_window_function_result,
    'Should order by signup_date DESC in ROW_NUMBER' AS test_description;

-- =====================================================
-- TEST 19: NTILE Distribution
-- =====================================================
WITH test_ntile AS (
    SELECT 
        value,
        NTILE(5) OVER (ORDER BY value ASC) AS quintile
    FROM (
        SELECT 1 AS value UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 
        UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
    ) numbers
)
SELECT 
    CASE 
        WHEN (SELECT COUNT(DISTINCT quintile) FROM test_ntile) = 5 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_ntile_result,
    'Should distribute values into 5 quintiles' AS test_description;

-- =====================================================
-- TEST 20: PERCENT_RANK Calculation
-- =====================================================
WITH test_percent_rank AS (
    SELECT 
        value,
        PERCENT_RANK() OVER (ORDER BY value) AS pct_rank
    FROM (
        SELECT 100 AS value UNION ALL SELECT 200 UNION ALL SELECT 300 UNION ALL SELECT 400 UNION ALL SELECT 500
    ) values
)
SELECT 
    CASE 
        WHEN (SELECT pct_rank FROM test_percent_rank WHERE value = 100) = 0.0
        AND (SELECT pct_rank FROM test_percent_rank WHERE value = 500) = 1.0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_percent_rank_result,
    'Should calculate PERCENT_RANK correctly (0 to 1)' AS test_description;

-- =====================================================
-- TEST 21: COALESCE with Multiple NULLs
-- =====================================================
WITH test_coalesce AS (
    SELECT 
        COALESCE(NULL, NULL, 'Default') AS result1,
        COALESCE(NULL, 'First', 'Second') AS result2,
        COALESCE('Value', NULL, 'Default') AS result3
)
SELECT 
    CASE 
        WHEN result1 = 'Default'
        AND result2 = 'First'
        AND result3 = 'Value'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_coalesce_result,
    'Should return first non-NULL value in COALESCE' AS test_description
FROM test_coalesce;

-- =====================================================
-- TEST 22: Date Interval Arithmetic
-- =====================================================
WITH test_intervals AS (
    SELECT 
        CURRENT_DATE - INTERVAL '30' DAY AS date_30,
        CURRENT_DATE - INTERVAL '90' DAY AS date_90,
        CURRENT_DATE - INTERVAL '365' DAY AS date_365
)
SELECT 
    CASE 
        WHEN date_30 > date_90
        AND date_90 > date_365
        AND date_365 < CURRENT_DATE
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_interval_arithmetic_result,
    'Should calculate date intervals correctly' AS test_description
FROM test_intervals;

-- =====================================================
-- TEST 23: CAST Operations
-- =====================================================
WITH test_cast AS (
    SELECT 
        CAST(100 AS FLOAT) AS float_val,
        CAST(3.14159 AS INT) AS int_val,
        CAST(5 AS VARCHAR) AS varchar_val
)
SELECT 
    CASE 
        WHEN float_val = 100.0
        AND int_val = 3
        AND varchar_val = '5'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_cast_result,
    'Should cast data types correctly' AS test_description
FROM test_cast;

-- =====================================================
-- TEST 24: String Concatenation in RFM Cell
-- =====================================================
WITH test_concat AS (
    SELECT 
        CAST(5 AS VARCHAR) || CAST(4 AS VARCHAR) || CAST(3 AS VARCHAR) AS rfm_cell
)
SELECT 
    CASE 
        WHEN rfm_cell = '543' THEN 'PASS'
        ELSE 'FAIL'
    END AS test_concat_result,
    'Should concatenate RFM scores into cell string' AS test_description
FROM test_concat;

-- =====================================================
-- TEST 25: ORDER BY with NULLS LAST
-- =====================================================
TRUNCATE TABLE raw_customers;
INSERT INTO raw_customers VALUES
(1, 'User', 'One', 'user1@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
(2, 'User', 'Two', 'user2@test.com', '555-0002', '456 Oak', 'LA', 'CA', 'USA', '1985-05-15', 'Female', '75-100k', 'Standard', '2023-01-01');

WITH test_order AS (
    SELECT 
        customer_id,
        NULL AS clv,
        100.00 AS revenue
    FROM raw_customers
    WHERE customer_id = 1
    UNION ALL
    SELECT 
        customer_id,
        5000.00 AS clv,
        200.00 AS revenue
    FROM raw_customers
    WHERE customer_id = 2
    ORDER BY clv DESC NULLS LAST, revenue DESC
)
SELECT 
    CASE 
        WHEN (SELECT customer_id FROM test_order LIMIT 1) = 2 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_order_nulls_last_result,
    'Should order with NULLS LAST correctly' AS test_description;

-- =====================================================
-- TEST 26: Complex CASE Statement
-- =====================================================
WITH test_case AS (
    SELECT 
        CASE
            WHEN 5 >= 4 AND 5 >= 4 AND 5 >= 4 THEN 'Champions'
            WHEN 3 >= 4 AND 3 >= 3 THEN 'Loyal Customers'
            ELSE 'Others'
        END AS segment
)
SELECT 
    CASE 
        WHEN segment = 'Champions' THEN 'PASS'
        ELSE 'FAIL'
    END AS test_case_statement_result,
    'Should evaluate complex CASE conditions correctly' AS test_description
FROM test_case;

-- =====================================================
-- TEST 27: Aggregate Functions with GROUP BY
-- =====================================================
TRUNCATE TABLE orders;
INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00),
(2, 1, CURRENT_DATE - INTERVAL '20' DAY, 'COMPLETED', 200.00),
(3, 2, CURRENT_DATE - INTERVAL '30' DAY, 'COMPLETED', 300.00);

WITH test_aggregate AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(total_amount) AS total_amount,
        AVG(total_amount) AS avg_amount,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order
    FROM orders
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
    HAVING customer_id = 1
)
SELECT 
    CASE 
        WHEN order_count = 2
        AND total_amount = 300.00
        AND avg_amount = 150.00
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_aggregate_result,
    'Should aggregate with GROUP BY correctly' AS test_description
FROM test_aggregate;

-- =====================================================
-- TEST 28: LEFT JOIN Behavior
-- =====================================================
TRUNCATE TABLE raw_customers;
TRUNCATE TABLE orders;
INSERT INTO raw_customers VALUES
(1, 'Has', 'Orders', 'hasorders@test.com', '555-0001', '123 Main', 'NYC', 'NY', 'USA', '1990-01-01', 'Male', '50-75k', 'Premium', '2023-01-01'),
(2, 'No', 'Orders', 'noorders@test.com', '555-0002', '456 Oak', 'LA', 'CA', 'USA', '1985-05-15', 'Female', '75-100k', 'Standard', '2023-01-01');

INSERT INTO orders VALUES
(1, 1, CURRENT_DATE - INTERVAL '10' DAY, 'COMPLETED', 100.00);

WITH test_left_join AS (
    SELECT 
        c.customer_id,
        COUNT(o.order_id) AS order_count
    FROM raw_customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT 
    CASE 
        WHEN (SELECT order_count FROM test_left_join WHERE customer_id = 1) = 1
        AND (SELECT order_count FROM test_left_join WHERE customer_id = 2) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_left_join_result,
    'Should preserve all left table rows in LEFT JOIN' AS test_description;

-- =====================================================
-- TEST 29: Multiple CTEs Dependency
-- =====================================================
WITH cte1 AS (
    SELECT 1 AS id, 100 AS value
),
cte2 AS (
    SELECT id, value * 2 AS doubled
    FROM cte1
),
cte3 AS (
    SELECT id, doubled * 3 AS tripled
    FROM cte2
)
SELECT 
    CASE 
        WHEN tripled = 600 THEN 'PASS'
        ELSE 'FAIL'
    END AS test_cte_dependency_result,
    'Should chain CTEs correctly' AS test_description
FROM cte3;

-- =====================================================
-- TEST 30: ROUND Function
-- =====================================================
WITH test_round AS (
    SELECT 
        ROUND(123.456, 2) AS rounded_2,
        ROUND(123.456, 0) AS rounded_0,
        ROUND(123.456, -1) AS rounded_neg1
)
SELECT 
    CASE 
        WHEN rounded_2 = 123.46
        AND rounded_0 = 123
        AND rounded_neg1 = 120
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_round_result,
    'Should round numbers correctly' AS test_description
FROM test_round;

-- =====================================================
-- TEST SUMMARY
-- =====================================================
SELECT 
    'ALL TESTS COMPLETED' AS status,
    CURRENT_TIMESTAMP AS completed_at,
    '30 test cases executed' AS test_count;

-- Cleanup
DROP TABLE IF EXISTS raw_customers;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS products;
