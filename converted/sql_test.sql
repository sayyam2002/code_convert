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
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) AS age,
    EXTRACT(DAY FROM CURRENT_DATE - signup_date) AS days_as_customer
  FROM filtered_customers
),
orders_filtered AS (
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
cancelled_orders AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS cancelled_orders
  FROM orders_filtered
  WHERE status = 'CANCELLED'
  GROUP BY customer_id
),
returned_orders AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS returned_orders
  FROM orders_filtered
  WHERE status = 'RETURNED'
  GROUP BY customer_id
),
revenue_last_30 AS (
  SELECT customer_id, 
    SUM(total_amount) AS revenue_last_30_days,
    COUNT(DISTINCT order_id) AS orders_last_30_days
  FROM orders_filtered
  WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY customer_id
),
revenue_last_90 AS (
  SELECT customer_id, SUM(total_amount) AS revenue_last_90_days
  FROM orders_filtered
  WHERE order_date >= CURRENT_DATE - INTERVAL '90 days'
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
    COALESCE(co.avg_order_value, 0) AS avg_order_value,
    COALESCE(can.cancelled_orders, 0) AS cancelled_orders,
    COALESCE(ret.returned_orders, 0) AS returned_orders,
    COALESCE(r30.revenue_last_30_days, 0) AS revenue_last_30_days,
    COALESCE(r90.revenue_last_90_days, 0) AS revenue_last_90_days,
    COALESCE(r30.orders_last_30_days, 0) AS orders_last_30_days
  FROM customer_order_summary cos
  LEFT JOIN completed_orders co ON cos.customer_id = co.customer_id
  LEFT JOIN cancelled_orders can ON cos.customer_id = can.customer_id
  LEFT JOIN returned_orders ret ON cos.customer_id = ret.customer_id
  LEFT JOIN revenue_last_30 r30 ON cos.customer_id = r30.customer_id
  LEFT JOIN revenue_last_90 r90 ON cos.customer_id = r90.customer_id
),
completed_order_items AS (
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
),
rfm_segments AS (
  SELECT 
    customer_id,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score AS rfm_total_score,
    CAST(recency_score AS VARCHAR) || CAST(frequency_score AS VARCHAR) || CAST(monetary_score AS VARCHAR) AS rfm_cell,
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
),
clv_final AS (
  SELECT 
    customer_id,
    total_orders,
    lifetime_revenue,
    avg_order_value,
    customer_lifespan_days,
    purchase_frequency_annual,
    days_as_customer,
    ROUND(avg_order_value * purchase_frequency_annual * 3, 2) AS estimated_clv_3yr,
    PERCENT_RANK() OVER (ORDER BY lifetime_revenue) AS revenue_percentile,
    PERCENT_RANK() OVER (ORDER BY avg_order_value * purchase_frequency_annual) AS clv_percentile
  FROM clv_calculated
),
customer_360_base AS (
  SELECT 
    cc.customer_id,
    cc.first_name,
    cc.last_name,
    cc.email,
    cc.phone,
    cc.city,
    cc.state,
    cc.country,
    cc.age,
    cc.gender,
    cc.income_bracket,
    cc.customer_segment AS original_segment,
    cc.signup_date,
    cc.days_as_customer,
    COALESCE(co.total_orders, 0) AS total_orders,
    COALESCE(co.completed_orders, 0) AS completed_orders,
    COALESCE(co.cancelled_orders, 0) AS cancelled_orders,
    COALESCE(co.returned_orders, 0) AS returned_orders,
    COALESCE(co.lifetime_revenue, 0) AS lifetime_revenue,
    COALESCE(co.avg_order_value, 0) AS avg_order_value,
    co.first_order_date,
    co.last_order_date,
    CASE WHEN co.last_order_date IS NOT NULL THEN EXTRACT(DAY FROM CURRENT_DATE - co.last_order_date) END AS days_since_last_order,
    COALESCE(co.revenue_last_30_days, 0) AS revenue_last_30_days,
    COALESCE(co.revenue_last_90_days, 0) AS revenue_last_90_days,
    COALESCE(co.orders_last_30_days, 0) AS orders_last_30_days,
    tc.top_category_1,
    tc.top_category_1_spend,
    tc.top_category_2,
    tc.top_category_2_spend,
    tc.top_category_3,
    tc.top_category_3_spend,
    rfm.recency_score,
    rfm.frequency_score,
    rfm.monetary_score,
    rfm.rfm_total_score,
    rfm.rfm_cell,
    rfm.rfm_segment,
    clv.estimated_clv_3yr,
    clv.revenue_percentile,
    clv.clv_percentile
  FROM cleaned_customers cc
  LEFT JOIN customer_orders co ON cc.customer_id = co.customer_id
  LEFT JOIN top_categories tc ON cc.customer_id = tc.customer_id
  LEFT JOIN rfm_segments rfm ON cc.customer_id = rfm.customer_id
  LEFT JOIN clv_final clv ON cc.customer_id = clv.customer_id
  WHERE cc.days_as_customer >= 0
),
customer_360_final AS (
  SELECT 
    *,
    CASE
      WHEN clv_percentile >= 0.9 THEN 'Platinum'
      WHEN clv_percentile >= 0.7 THEN 'Gold'
      WHEN clv_percentile >= 0.4 THEN 'Silver'
      ELSE 'Bronze'
    END AS customer_tier,
    CASE
      WHEN days_since_last_order IS NULL THEN 'Active'
      WHEN days_since_last_order > 180 THEN 'High Risk'
      WHEN days_since_last_order > 90 THEN 'Medium Risk'
      WHEN days_since_last_order > 30 THEN 'Low Risk'
      ELSE 'Active'
    END AS churn_risk,
    CURRENT_TIMESTAMP AS report_generated_at,
    'v2.0' AS report_version
  FROM customer_360_base
)
SELECT 
  customer_id,
  first_name,
  last_name,
  email,
  phone,
  city,
  state,
  country,
  age,
  gender,
  income_bracket,
  original_segment,
  signup_date,
  days_as_customer,
  total_orders,
  completed_orders,
  cancelled_orders,
  returned_orders,
  lifetime_revenue,
  avg_order_value,
  first_order_date,
  last_order_date,
  days_since_last_order,
  revenue_last_30_days,
  revenue_last_90_days,
  orders_last_30_days,
  top_category_1,
  top_category_1_spend,
  top_category_2,
  top_category_2_spend,
  top_category_3,
  top_category_3_spend,
  recency_score,
  frequency_score,
  monetary_score,
  rfm_total_score,
  rfm_cell,
  rfm_segment,
  estimated_clv_3yr,
  revenue_percentile,
  clv_percentile,
  customer_tier,
  churn_risk,
  report_generated_at,
  report_version
FROM customer_360_final
ORDER BY estimated_clv_3yr DESC NULLS LAST, lifetime_revenue DESC NULLS LAST;
