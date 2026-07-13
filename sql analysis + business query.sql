select * from funnel_events;

--- Section A: Data Validation

-- Q1. Total rows, distinct sessions, distinct users
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT user_id) AS total_users
FROM funnel_events;

--Q2. Duplicate rows
SELECT 
    user_id, session_id, event, event_timestamp,
    COUNT(*) AS occurrence_count
FROM funnel_events
GROUP BY user_id, session_id, event, event_timestamp
HAVING COUNT(*) > 1;

--Q3. NULLs in critical columns
SELECT
    COUNT(*) FILTER (WHERE session_id IS NULL) AS null_session_id,
    COUNT(*) FILTER (WHERE event IS NULL) AS null_event,
    COUNT(*) FILTER (WHERE event_timestamp IS NULL) AS null_timestamp,
    COUNT(*) FILTER (WHERE revenue IS NULL) AS null_revenue
FROM funnel_events;

--Q4. Distinct event values (checking for typos/inconsistency)
SELECT event, COUNT(*) AS event_count
FROM funnel_events
GROUP BY event
ORDER BY event_count DESC;

--Q5. Date range check
SELECT 
    MIN(event_timestamp) AS earliest_event,
    MAX(event_timestamp) AS latest_event
FROM funnel_events;

--Q6. Revenue/event logic mismatch
SELECT 
    event,
    COUNT(*) FILTER (WHERE revenue > 0) AS rows_with_revenue,
    COUNT(*) FILTER (WHERE revenue = 0 OR revenue IS NULL) AS rows_without_revenue
FROM funnel_events
GROUP BY event;

---Section B: Session Analysis

-- Q1. How many events does a typical session have, and what's the distribution?
SELECT 
    session_id,
    COUNT(*) AS events_in_session
FROM funnel_events
GROUP BY session_id
ORDER BY events_in_session DESC;

--- Section C: Funnel Analysis

--Q1. Sessions reaching each funnel stage, with conversion % from the previous stage
WITH stage_reach AS (
    SELECT 
        session_id,
        MAX(CASE WHEN event = 'Browse' THEN 1 ELSE 0 END) AS reached_browse,
        MAX(CASE WHEN event = 'Add to Cart' THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN event = 'Checkout' THEN 1 ELSE 0 END) AS reached_checkout,
        MAX(CASE WHEN event = 'Purchase' THEN 1 ELSE 0 END) AS reached_purchase
    FROM funnel_events
    GROUP BY session_id
)
SELECT
    SUM(reached_browse) AS browse_sessions,
    SUM(reached_cart) AS cart_sessions,
    SUM(reached_checkout) AS checkout_sessions,
    SUM(reached_purchase) AS purchase_sessions,
    ROUND(SUM(reached_cart)::numeric / SUM(reached_browse) * 100, 2) AS browse_to_cart_pct,
    ROUND(SUM(reached_checkout)::numeric / SUM(reached_cart) * 100, 2) AS cart_to_checkout_pct,
    ROUND(SUM(reached_purchase)::numeric / SUM(reached_checkout) * 100, 2) AS checkout_to_purchase_pct
FROM stage_reach;

--Q2. Overall conversion rate (Browse → Purchase)
SELECT 
    ROUND(COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END)::numeric 
        / COUNT(DISTINCT session_id) * 100, 2) AS overall_conversion_rate
FROM funnel_events;

--- Section D: Revenue Analysis

--Q1. Total revenue, total orders, and average order value (AOV)
SELECT 
    SUM(revenue) AS total_revenue,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END) AS total_orders,
    ROUND(SUM(revenue) / COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END), 2) AS avg_order_value
FROM funnel_events;



--Q2. Which channel has the highest revenue per session, not just total revenue?
SELECT 
    channel,
    COUNT(DISTINCT session_id) AS total_sessions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue) / COUNT(DISTINCT session_id), 2) AS revenue_per_session
FROM funnel_events
GROUP BY channel
ORDER BY revenue_per_session DESC;

--- Section E: Customer Behaviour

--Q1. How many users are one-time vs. repeat visitors, and does repeat visiting improve conversion?
WITH user_sessions AS (
    SELECT 
        user_id,
        COUNT(DISTINCT session_id) AS session_count,
        MAX(CASE WHEN event = 'Purchase' THEN 1 ELSE 0 END) AS ever_purchased
    FROM funnel_events
    GROUP BY user_id
)
SELECT 
    CASE WHEN session_count = 1 THEN 'One-time visitor' ELSE 'Repeat visitor' END AS visitor_type,
    COUNT(*) AS num_users,
    ROUND(AVG(ever_purchased) * 100, 2) AS conversion_rate_pct
FROM user_sessions
GROUP BY CASE WHEN session_count = 1 THEN 'One-time visitor' ELSE 'Repeat visitor' END;

--Q2. Users who abandoned at checkout (reached Checkout but never Purchase) — how many, and what's their total "lost" cart value?
SELECT 
    COUNT(DISTINCT session_id) AS abandoned_sessions,
    SUM(revenue) AS lost_potential_value
FROM funnel_events e
WHERE session_id IN (
    SELECT session_id FROM funnel_events WHERE event = 'Checkout'
)
AND session_id NOT IN (
    SELECT session_id FROM funnel_events WHERE event = 'Purchase'
);

--- Section F: Marketing Analysis

--Q1. Full funnel breakdown by channel (conversion rate per channel, ranked)
WITH session_attribution AS (
    SELECT DISTINCT ON (session_id)
        session_id, channel, device, region
    FROM funnel_events
    ORDER BY session_id, event_timestamp ASC
)
SELECT 
    sa.channel,
    COUNT(DISTINCT sa.session_id) AS total_sessions,
    SUM(e.revenue) AS total_revenue,
    COUNT(DISTINCT CASE WHEN e.event = 'Purchase' THEN e.session_id END) AS purchases,
    ROUND(COUNT(DISTINCT CASE WHEN e.event = 'Purchase' THEN e.session_id END)::numeric 
        / COUNT(DISTINCT sa.session_id) * 100, 2) AS conversion_rate_pct
FROM session_attribution sa
JOIN funnel_events e ON sa.session_id = e.session_id
GROUP BY sa.channel
ORDER BY conversion_rate_pct DESC;

--Q2. Which channel has the highest checkout-to-purchase rate specifically (i.e., best at closing, not just attracting)?
SELECT 
    channel,
    COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN session_id END) AS checkout_sessions,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END) AS purchase_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END)::numeric 
        / NULLIF(COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN session_id END), 0) * 100, 2) AS checkout_to_purchase_pct
FROM funnel_events
GROUP BY channel
ORDER BY checkout_to_purchase_pct DESC;

--- Section G: Regional Analysis
--Q1. Which region-device combination performs best? (two-dimensional grouping)
SELECT 
    region,
    device,
    COUNT(DISTINCT session_id) AS total_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END)::numeric 
        / COUNT(DISTINCT session_id) * 100, 2) AS conversion_rate_pct
FROM funnel_events
GROUP BY region, device
ORDER BY conversion_rate_pct DESC
LIMIT 10;

--- Section H: Product Analysis

--Q1. Revenue, sessions, and conversion rate by product category, ranked
SELECT 
    product_category,
    COUNT(DISTINCT session_id) AS total_sessions,
    SUM(revenue) AS total_revenue,
    ROUND(COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END)::numeric 
        / COUNT(DISTINCT session_id) * 100, 2) AS conversion_rate_pct
FROM funnel_events
GROUP BY product_category
ORDER BY total_revenue DESC;

--Q2. Which product category has the highest revenue per session (efficiency, not just volume)?
SELECT 
    product_category,
    ROUND(SUM(revenue) / COUNT(DISTINCT session_id), 2) AS revenue_per_session
FROM funnel_events
GROUP BY product_category
ORDER BY revenue_per_session DESC;

--- Section I: Device Analysis

- Q1. Where in the funnel does each device lose the most sessions? (stage-by-device breakdown)
SELECT 
    device,
    COUNT(DISTINCT CASE WHEN event = 'Browse' THEN session_id END) AS browse,
    COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN session_id END) AS add_to_cart,
    COUNT(DISTINCT CASE WHEN event = 'Checkout' THEN session_id END) AS checkout,
    COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END) AS purchase
FROM funnel_events
GROUP BY device;

--- Section J: Time Analysi

--Q1. Conversion rate by day of week
SELECT 
    TO_CHAR(event_timestamp, 'Day') AS day_of_week,
    COUNT(DISTINCT session_id) AS total_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END)::numeric 
        / COUNT(DISTINCT session_id) * 100, 2) AS conversion_rate_pct
FROM funnel_events
GROUP BY TO_CHAR(event_timestamp, 'Day'), EXTRACT(DOW FROM event_timestamp)
ORDER BY EXTRACT(DOW FROM event_timestamp);

--- Section K: Advanced KPIs.

-- Q1. Cart abandonment rate (industry-standard KPI)
SELECT 
    ROUND(
        (COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN session_id END) 
         - COUNT(DISTINCT CASE WHEN event = 'Purchase' THEN session_id END))::numeric
        / NULLIF(COUNT(DISTINCT CASE WHEN event = 'Add to Cart' THEN session_id END), 0) * 100, 2
    ) AS cart_abandonment_rate_pct
FROM funnel_events;

--Q2. Average Revenue Per User (ARPU) — using a nested subquery
SELECT 
    ROUND(AVG(user_revenue), 2) AS avg_revenue_per_user
FROM (
    SELECT user_id, SUM(revenue) AS user_revenue
    FROM funnel_events
    GROUP BY user_id
) AS user_totals;

--Q3. Average time from first Browse to Purchase, for sessions that converted
SELECT 
    ROUND(AVG(EXTRACT(EPOCH FROM (purchase_time - browse_time)) / 60), 2) AS avg_minutes_to_purchase
FROM (
    SELECT 
        session_id,
        MIN(CASE WHEN event = 'Browse' THEN event_timestamp END) AS browse_time,
        MIN(CASE WHEN event = 'Purchase' THEN event_timestamp END) AS purchase_time
    FROM funnel_events
    GROUP BY session_id
    HAVING MIN(CASE WHEN event = 'Purchase' THEN event_timestamp END) IS NOT NULL
) AS session_times;

--- Section L: Window Functions

--Q1. Running total of daily revenue (cumulative revenue over time)
SELECT 
    DATE(event_timestamp) AS event_date,
    SUM(revenue) AS daily_revenue,
    SUM(SUM(revenue)) OVER (ORDER BY DATE(event_timestamp)) AS running_total_revenue
FROM funnel_events
GROUP BY DATE(event_timestamp)
ORDER BY event_date;

--Q2. Rank sessions within each channel by revenue, and flag the top 3 per channel
WITH session_revenue AS (
    SELECT 
        session_id,
        channel,
        SUM(revenue) AS session_revenue
    FROM funnel_events
    GROUP BY session_id, channel
)
SELECT *
FROM (
    SELECT 
        session_id,
        channel,
        session_revenue,
        RANK() OVER (PARTITION BY channel ORDER BY session_revenue DESC) AS revenue_rank
    FROM session_revenue
) ranked
WHERE revenue_rank <= 3;

--Section M: CTEs

--Q1. Multi-CTE query: identify the "problem segment" — the channel + device combination with the worst checkout-to-purchase rate, but only among segments with meaningful traffic (>200 sessions)
WITH session_attribution AS (
    SELECT DISTINCT ON (session_id)
        session_id, channel, device
    FROM funnel_events
    ORDER BY session_id, event_timestamp ASC
),
segment_funnel AS (
    SELECT 
        sa.channel,
        sa.device,
        COUNT(DISTINCT sa.session_id) AS total_sessions,
        COUNT(DISTINCT CASE WHEN e.event = 'Checkout' THEN e.session_id END) AS checkout_sessions,
        COUNT(DISTINCT CASE WHEN e.event = 'Purchase' THEN e.session_id END) AS purchase_sessions
    FROM session_attribution sa
    JOIN funnel_events e ON sa.session_id = e.session_id
    GROUP BY sa.channel, sa.device
)
SELECT *,
    ROUND(purchase_sessions::numeric / NULLIF(checkout_sessions, 0) * 100, 2) AS checkout_to_purchase_pct
FROM segment_funnel
WHERE total_sessions > 200
ORDER BY checkout_to_purchase_pct ASC
LIMIT 5;
