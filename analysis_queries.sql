-- ============================================================
-- Mr. Pizza Sales Analytics — SQL Query File
-- Author  : Lakshika Dev (22f3000223)
-- Course  : BDM Capstone · IIT Madras · BS Data Science
-- Dataset : 997 transactions · Sep 2023 – Jan 2024
-- Tool    : SQLiteOnline.com
-- ============================================================
-- TABLE: sales
-- Columns: Date, Day, Category, Item, Size, Qty, UnitPrice,
--          TotalPrice, DailyTotal, Notes
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- SECTION 1: BASIC EXPLORATION
-- ────────────────────────────────────────────────────────────

-- Q1. Total number of transactions
SELECT COUNT(*) AS total_transactions
FROM sales;
-- Result: 997


-- Q2. Overall revenue summary
SELECT
    COUNT(*)                        AS total_transactions,
    SUM(TotalPrice)                 AS total_revenue,
    ROUND(AVG(TotalPrice), 2)       AS avg_order_value,
    MIN(TotalPrice)                 AS min_order,
    MAX(TotalPrice)                 AS max_order,
    SUM(Qty)                        AS total_units_sold
FROM sales;


-- Q3. Date range of the dataset
SELECT
    MIN(Date) AS first_transaction,
    MAX(Date) AS last_transaction,
    COUNT(DISTINCT Date) AS trading_days
FROM sales;
-- Result: 139 trading days, Sep 2023 – Jan 2024


-- Q4. Number of unique items and categories
SELECT
    COUNT(DISTINCT Item)     AS unique_items,
    COUNT(DISTINCT Category) AS unique_categories
FROM sales;
-- Result: 47 items, 9 categories


-- ────────────────────────────────────────────────────────────
-- SECTION 2: REVENUE ANALYSIS
-- ────────────────────────────────────────────────────────────

-- Q5. Monthly revenue summary
SELECT
    STRFTIME('%Y-%m', Date)         AS month,
    SUM(TotalPrice)                 AS monthly_revenue,
    COUNT(*)                        AS transactions,
    ROUND(AVG(TotalPrice), 2)       AS avg_order_value,
    COUNT(DISTINCT Date)            AS trading_days
FROM sales
GROUP BY STRFTIME('%Y-%m', Date)
ORDER BY month;
-- Result: Sep=34231, Oct=30661, Nov=28332, Dec=25310, Jan=34443


-- Q6. Month-over-Month revenue change using LAG window function
SELECT
    month,
    monthly_revenue,
    prev_month_revenue,
    ROUND(
        (monthly_revenue - prev_month_revenue) * 100.0 / prev_month_revenue,
        1
    ) AS mom_change_pct
FROM (
    SELECT
        STRFTIME('%Y-%m', Date) AS month,
        SUM(TotalPrice)         AS monthly_revenue,
        LAG(SUM(TotalPrice)) OVER (ORDER BY STRFTIME('%Y-%m', Date)) AS prev_month_revenue
    FROM sales
    GROUP BY STRFTIME('%Y-%m', Date)
)
ORDER BY month;
-- Result: Oct -10.4%, Nov -7.6%, Dec -10.7%, Jan +36.1%


-- Q7. Revenue by product category (ranked)
SELECT
    Category,
    SUM(TotalPrice)                                     AS revenue,
    COUNT(*)                                            AS transactions,
    SUM(Qty)                                            AS units_sold,
    ROUND(SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER (), 1) AS pct_of_total
FROM sales
GROUP BY Category
ORDER BY revenue DESC;
-- Result: Pizza 79.7%, Burger 7.8%, Shake 5.2%


-- Q8. Revenue by day of week
SELECT
    Day,
    SUM(TotalPrice)                                         AS revenue,
    COUNT(*)                                                AS transactions,
    ROUND(AVG(TotalPrice), 2)                              AS avg_order_value,
    ROUND(SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER (), 1) AS pct_of_total
FROM sales
GROUP BY Day
ORDER BY revenue DESC;
-- Result: Sunday 24.1%, Saturday 17.6%, Tuesday lowest 8.6%


-- Q9. Daily revenue summary with descriptive statistics
SELECT
    ROUND(AVG(daily_rev), 2)    AS mean_daily_revenue,
    MIN(daily_rev)              AS min_daily_revenue,
    MAX(daily_rev)              AS max_daily_revenue,
    COUNT(*)                    AS total_days
FROM (
    SELECT Date, SUM(TotalPrice) AS daily_rev
    FROM sales
    GROUP BY Date
);
-- Result: Mean=1100.55, Min=189, Max=7425, Days=139


-- ────────────────────────────────────────────────────────────
-- SECTION 3: ITEM-LEVEL ANALYSIS
-- ────────────────────────────────────────────────────────────

-- Q10. Top 10 items by revenue with RANK()
SELECT
    rank_num,
    Item,
    Category,
    revenue,
    units_sold,
    ROUND(avg_unit_price, 0)    AS avg_unit_price,
    ROUND(pct_of_total, 2)      AS pct_of_total
FROM (
    SELECT
        RANK() OVER (ORDER BY SUM(TotalPrice) DESC) AS rank_num,
        Item,
        Category,
        SUM(TotalPrice)                              AS revenue,
        SUM(Qty)                                     AS units_sold,
        AVG(UnitPrice)                               AS avg_unit_price,
        SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER () AS pct_of_total
    FROM sales
    GROUP BY Item, Category
)
WHERE rank_num <= 10
ORDER BY rank_num;


-- Q11. ABC Classification using cumulative revenue
-- Class A = top 70%, Class B = 70-90%, Class C = 90-100%
SELECT
    Item,
    Category,
    revenue,
    ROUND(pct_of_total, 2)      AS pct_of_total,
    ROUND(cumulative_pct, 1)    AS cumulative_pct,
    CASE
        WHEN cumulative_pct <= 70 THEN 'A'
        WHEN cumulative_pct <= 90 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM (
    SELECT
        Item,
        Category,
        SUM(TotalPrice) AS revenue,
        SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER () AS pct_of_total,
        SUM(SUM(TotalPrice)) OVER (
            ORDER BY SUM(TotalPrice) DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / SUM(SUM(TotalPrice)) OVER () AS cumulative_pct
    FROM sales
    GROUP BY Item, Category
)
ORDER BY revenue DESC;
-- Result: 12 Class A items (69.2%), 9 Class B (20.3%), 26 Class C (10.5%)


-- Q12. ABC class summary
SELECT
    abc_class,
    COUNT(*)            AS item_count,
    SUM(revenue)        AS class_revenue,
    ROUND(SUM(pct_of_total), 1) AS pct_of_total
FROM (
    SELECT
        Item,
        SUM(TotalPrice) AS revenue,
        SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER () AS pct_of_total,
        CASE
            WHEN SUM(SUM(TotalPrice)) OVER (
                ORDER BY SUM(TotalPrice) DESC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100.0 / SUM(SUM(TotalPrice)) OVER () <= 70 THEN 'A'
            WHEN SUM(SUM(TotalPrice)) OVER (
                ORDER BY SUM(TotalPrice) DESC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100.0 / SUM(SUM(TotalPrice)) OVER () <= 90 THEN 'B'
            ELSE 'C'
        END AS abc_class
    FROM sales
    GROUP BY Item
)
GROUP BY abc_class
ORDER BY abc_class;


-- Q13. Size-wise revenue breakdown (Pizza sizes)
SELECT
    Size,
    COUNT(*)                AS transactions,
    SUM(Qty)                AS units_sold,
    SUM(TotalPrice)         AS revenue,
    ROUND(AVG(UnitPrice), 0) AS avg_unit_price,
    ROUND(SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER (), 1) AS pct_of_total
FROM sales
WHERE Size IN ('S', 'M', 'L')
GROUP BY Size
ORDER BY revenue DESC;
-- Result: S=44814, M=36510, L=24297


-- ────────────────────────────────────────────────────────────
-- SECTION 4: TIME SERIES & FORECASTING SUPPORT
-- ────────────────────────────────────────────────────────────

-- Q14. Weekly revenue (used as input for MA4 model)
SELECT
    week_start,
    SUM(TotalPrice) AS weekly_revenue,
    COUNT(DISTINCT Date) AS trading_days_in_week
FROM (
    SELECT
        TotalPrice,
        Date,
        DATE(Date, '-' || CAST(STRFTIME('%w', Date) AS INTEGER) || ' days') AS week_start
    FROM sales
)
GROUP BY week_start
ORDER BY week_start;


-- Q15. 4-Week Moving Average (MA4) using window functions
SELECT
    week_start,
    weekly_revenue,
    ROUND(
        AVG(weekly_revenue) OVER (
            ORDER BY week_start
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 0
    ) AS ma4_forecast,
    ROUND(
        weekly_revenue - AVG(weekly_revenue) OVER (
            ORDER BY week_start
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 0
    ) AS deviation_from_ma4
FROM (
    SELECT
        DATE(Date, '-' || CAST(STRFTIME('%w', Date) AS INTEGER) || ' days') AS week_start,
        SUM(TotalPrice) AS weekly_revenue
    FROM sales
    GROUP BY week_start
)
ORDER BY week_start;
-- Confirms MA4 values matching the report weekly table


-- Q16. Identify the January outlier week (catering event)
SELECT
    Date,
    Day,
    SUM(TotalPrice) AS daily_revenue,
    COUNT(*)        AS transactions
FROM sales
WHERE STRFTIME('%Y-%m', Date) = '2024-01'
GROUP BY Date
ORDER BY daily_revenue DESC
LIMIT 5;
-- Result: Jan 8 = 7425 (outlier catering event)


-- ────────────────────────────────────────────────────────────
-- SECTION 5: BUSINESS INSIGHTS
-- ────────────────────────────────────────────────────────────

-- Q17. Weekend vs weekday revenue comparison
SELECT
    day_type,
    COUNT(DISTINCT Date)            AS days,
    SUM(TotalPrice)                 AS total_revenue,
    ROUND(AVG(daily_rev), 0)        AS avg_daily_revenue,
    ROUND(SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER (), 1) AS pct_of_total
FROM (
    SELECT
        TotalPrice,
        Date,
        CASE WHEN Day IN ('Saturday','Sunday') THEN 'Weekend' ELSE 'Weekday' END AS day_type,
        SUM(TotalPrice) OVER (PARTITION BY Date) AS daily_rev
    FROM sales
)
GROUP BY day_type;
-- Result: Weekend 41.7% of revenue, 79% more per day than weekdays


-- Q18. Sunday vs Tuesday comparison (key finding)
SELECT
    Day,
    SUM(TotalPrice)     AS total_revenue,
    COUNT(DISTINCT Date) AS num_days,
    ROUND(SUM(TotalPrice) / COUNT(DISTINCT Date), 0) AS avg_per_day,
    ROUND(SUM(TotalPrice) * 100.0 / SUM(SUM(TotalPrice)) OVER (), 1) AS pct_of_total
FROM sales
WHERE Day IN ('Sunday', 'Tuesday')
GROUP BY Day;
-- Result: Sunday 36799 (24.1%), Tuesday 13104 (8.6%) — ratio 2.8x


-- Q19. Kulhad Pizza performance (top volume item, R6 basis)
SELECT
    Item,
    COUNT(*)                AS transactions,
    SUM(Qty)                AS units_sold,
    SUM(TotalPrice)         AS total_revenue,
    ROUND(AVG(UnitPrice), 0) AS avg_unit_price,
    ROUND(SUM(TotalPrice) * 100.0 / (SELECT SUM(TotalPrice) FROM sales), 1) AS pct_of_total
FROM sales
WHERE Item = 'Kulhad Pizza'
GROUP BY Item;
-- Result: 165 units, 10.7% of revenue — basis for R6 Tuesday combo


-- Q20. Items with zero sales on Tuesday (stockout risk analysis)
SELECT DISTINCT Item
FROM sales
WHERE Item NOT IN (
    SELECT DISTINCT Item
    FROM sales
    WHERE Day = 'Tuesday'
)
ORDER BY Item;
-- Items never ordered on Tuesday — low priority for Tuesday procurement


-- ============================================================
-- END OF QUERIES
-- 20 queries covering: exploration, revenue analysis,
-- item classification, time series, and business insights
-- All results verified against final report (version 6)
-- ============================================================
