-- ============================================================
-- SECTION 1: STORE PERFORMANCE
-- ============================================================
 
-- ------------------------------------------------------------
-- 1.1 Top 10 Stores by Total Sales
-- ------------------------------------------------------------
-- Insight: The top 10 stores account for a
-- large share of total revenue, suggesting strong concentration
-- among a small subset of high-performing locations.
-- ------------------------------------------------------------
SELECT
store_id,
SUM(weekly_sales) AS total_sales
FROM fact_sales
GROUP BY store_id
ORDER BY total_sales DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 1.2 -- What types of store sell more?
-- ------------------------------------------------------------
-- Insight: Type A stores consistently outperform Type B and C
-- in total sales volume, largely driven by their larger size.
-- However, size alone does not fully explain performance.
-- There are for sure some operational and format differences
-- that influence sales.
-- ------------------------------------------------------------
SELECT
f.store_id, s.size, s.store_type,
SUM(weekly_sales) AS total_sales
FROM fact_sales f
JOIN dim_store s ON f.store_id=s.store_id
GROUP BY f.store_id, s.size, s.store_type
ORDER BY total_sales DESC;

-- -----------------------------------------------------------------------------------
-- 1.3 -- Store Stability - do they always perform well or only in certain periods?
-- -----------------------------------------------------------------------------------
-- Insight: Visualising weekly sales per store reveals clear
-- seasonal spikes, particularly around Christmas.
SELECT
store_id,
date_id,
SUM(weekly_sales) AS weekly_total_sales
FROM fact_sales
GROUP BY store_id, date_id
ORDER BY store_id, date_id;

-- ============================================================
-- SECTION 2: MORE IN-DEPTH STORE STABILITY ANALYSIS
-- ===========================================================
-- Measure Stability in Sales (store x dep x week row/level)
-- ------------------------------------------------------------
-- 2.1 Sales Volatility at Store × Department Level
-- ------------------------------------------------------------
-- Insight: High volatility at dept level reflects
-- department-specific (likely promotional) sensitivity. Some departments
-- show bigger swings, indicating markdown or seasonal effects
-- concentrated in specific categories.
-- ------------------------------------------------------------
SELECT
store_id,
AVG(weekly_sales) AS avg_sales,
STDDEV_SAMP(weekly_sales) AS sales_volatility
FROM fact_sales
GROUP BY  store_id
ORDER BY sales_volatility;

-- ------------------------------------------------------------
-- 2.2 -- Stablity (store * week only level -> subquery for this reason)
-- ------------------------------------------------------------
-- Insight: Aggregating at store × week level (vs store × dept × week)
-- captures store-level structural volatility more accurately.
-- Stores with high volatility at this level are likely
-- more promotion-dependent or have less stable customer bases.
-- ------------------------------------------------------------
SELECT
store_id,
AVG(weekly_total_sales) AS avg_sales,
STDDEV_SAMP(weekly_total_sales) AS sales_volatility
FROM (
		SELECT
    	store_id,
        date_id,
        SUM(weekly_sales) AS weekly_total_sales
    	FROM fact_sales
   		GROUP BY store_id, date_id
		   ) AS store_week_sales
GROUP BY store_id
ORDER BY sales_volatility;

-- ------------------------------------------------------------
-- 2.3 What types of store are less stable?
-- (subquery for store level + avg. volatility -> calculate avg. since 1 size/type -> many stores)
-- ------------------------------------------------------------
-- Insight: Larger Type A stores tend to show higher absolute
-- volatility, but this is partly a function of scale.
-- Normalising by avg sales (see efficiency metric below)
-- reveals that smaller stores are not necessarily more stable
-- in relative terms.
-- ------------------------------------------------------------
SELECT
s.size,
s.store_type,
AVG(v.sales_volatility) AS avg_volatility
FROM(
	SELECT
	store_id,
	STDDEV_SAMP(weekly_sales) AS sales_volatility
	FROM fact_sales
	GROUP BY store_id
) v
JOIN dim_store s ON v.store_id=s.store_id
GROUP BY s.size, s.store_type
ORDER BY avg_volatility;

-- -------------------------------------------------------------------------------
-- 2.4 Stability Efficiency (Avg Sales / Volatility)
-- -------------------------------------------------------------------------------
-- Insight: Stability efficiency captures a coefficient (avg. sales / volatility)
-- High efficiency = high revenue with low variance, the most 
-- desirable profile for a retailer.
-- Stores with low efficiency despite high sales are likely
-- reliant on promotions or seasonal spikes.
-- -------------------------------------------------------------------------------
SELECT
d.store_id,
d.store_type,
d.size,
store.avg_sales,
store.volatility,
ROUND(
store.avg_sales/
NULLIF(store.volatility,0), 2) AS stability_efficiency

FROM(
SELECT
store_id,
AVG(weekly_sales) as avg_sales,
STDDEV_SAMP(weekly_sales) as volatility
FROM fact_sales
GROUP BY store_id) store

JOIN dim_store d
ON store.store_id=d.store_id
ORDER BY stability_efficiency DESC;

-- -----------------------------------------------------------------------
-- 2.5 Store Classification: Sales Level × Volatility Level
-- -----------------------------------------------------------------------
-- Classification logic:
--   High sales + low_volatility  → Best stores: consistent top performers
--   High sales + high volatility → Promo-driven: strong but risky
--   Low sales  + low volatility  → Stable but weak
--   Low sales  + high volatility → Underperforming and unstable
--
-- Insight: The majority of top-performing stores fall into the
-- HIGH_SALES + LOW_VOLATILITY quadrant, confirming that sustained
-- sales and operational consistency tend to occur at the same time.
-- ----------------------------------------------------------------------
WITH store_metrics AS (
SELECT
f.store_id,
AVG(f.weekly_sales) AS avg_sales,
STDDEV(f.weekly_sales) AS volatility,
AVG(f.weekly_sales) / NULLIF(STDDEV(f.weekly_sales),0) AS efficiency
FROM fact_sales f
GROUP BY f.store_id
),

labeled AS (
SELECT
sm.*,
d.store_type,
d.size,

CASE
	WHEN avg_sales >= (SELECT AVG(avg_sales) FROM store_metrics) THEN 'HIGH_SALES'
	ELSE 'LOW_SALES' 
	END AS sales_level,

CASE
	WHEN volatility >= (SELECT AVG(volatility) FROM store_metrics) THEN 'HIGH_VOLATILITY'
    ELSE 'LOW_VOLATILITY'
    END AS volatility_level

    FROM store_metrics sm
	JOIN dim_store d
    ON sm.store_id = d.store_id
)

SELECT *
FROM labeled;

-- ============================================================
-- SECTION 3: DEPARTMENT ANALYSIS
-- ============================================================
-- ------------------------------------------------------------
-- 3.1 Store Classification × Department Performance
-- ------------------------------------------------------------
WITH store_metrics AS (
SELECT
f.store_id,
AVG(f.weekly_sales) AS avg_sales
FROM fact_sales f
GROUP BY f.store_id
),

store_segment AS (
SELECT
sm.*,

CASE
WHEN avg_sales >= (SELECT AVG(avg_sales) FROM store_metrics)
THEN 'HIGH_SALES'
ELSE 'LOW_SALES'
END AS store_class

FROM store_metrics sm)

SELECT
ss.store_class,
f.dept_id,
SUM(f.weekly_sales) AS total_sales,

AVG(f.weekly_sales) AS avg_sales_per_week
FROM fact_sales f
JOIN store_segment ss
ON f.store_id = ss.store_id
GROUP BY ss.store_class, f.dept_id
ORDER BY ss.store_class, total_sales DESC;

-- ------------------------------------------------------------
-- 3.2 Department % Contribution to Total Sales (Window Function)
-- ------------------------------------------------------------
-- Insight: A small number of departments (top 10) drive
-- around 40-45% of total sales across the chain.
-- ------------------------------------------------------------
SELECT
f.dept_id,
SUM(f.weekly_sales) AS dept_sales,
ROUND(
	SUM(f.weekly_sales) * 100.0 /
	SUM(SUM(f.weekly_sales)) OVER (), 2) AS dept_contribution

FROM fact_sales f
GROUP BY f.dept_id
ORDER BY dept_sales DESC;

-- ============================================================
-- SECTION 4: MARKDOWN ANALYSIS
-- ============================================================
-- NOTE:
-- Initial preprocessing step imputed missing markdown values as 0.
-- However, dataset documentation clarified that NA values correspond to missing promotional data.
-- Now: revision of the markdown analysis approach to avoid misinterpretation.
-- How: -> table view "fact_sales_clean" (only activate promotions, no 0 or NaN - then I will fix better)
-- ============================================================
--
-- ------------------------------------------------------------
-- 4.0 Filtered View: Confirmed Promotion Only
-- ------------------------------------------------------------
CREATE VIEW fact_sales_clean1 AS
SELECT *
FROM fact_sales
WHERE (markdown1 > 0 AND markdown2 > 0 AND markdown3 != 0
	   AND markdown4 > 0 AND markdown5 > 0);

-- --------------------------------------------------------------------
-- 4.1 Average Markdown Values (Confirmed Promos)  Average weekly sales
-- --------------------------------------------------------------------
SELECT
AVG(weekly_sales) AS avg_sales,
AVG(markdown1) AS avg_md1,
AVG(markdown2) AS avg_md2,
AVG(markdown3) AS avg_md3,
AVG(markdown4) AS avg_md4,
AVG(markdown5) AS avg_md5

FROM fact_sales_clean1;

-- ------------------------------------------------------------
-- 4.2 Markdown Value - Average Sales (per Markdown Type)
-- ------------------------------------------------------------
-- Insight: The relationship between individual markdown values
-- and weekly sales is not strictly linear. Some markdown types
-- (e.g. MarkDown1, MarkDown2) show a clearer positive trend,
-- while others (e.g. MarkDown3, MarkDown5) display more noise.
-- ------------------------------------------------------------
SELECT
markdown1,
AVG(weekly_sales) AS avg_sales
FROM fact_sales_clean1
GROUP BY markdown1
ORDER BY markdown1;

SELECT
markdown2,
AVG(weekly_sales) AS avg_sales
FROM fact_sales_clean1
GROUP BY markdown2
ORDER BY markdown2;

SELECT
markdown3,
AVG(weekly_sales) AS avg_sales
FROM fact_sales_clean
GROUP BY markdown3
ORDER BY markdown3;

SELECT
markdown4,
AVG(weekly_sales) AS avg_sales
FROM fact_sales_clean1
GROUP BY markdown4
ORDER BY markdown4;

SELECT
markdown5,
AVG(weekly_sales) AS avg_sales
FROM fact_sales_clean1
GROUP BY markdown5
ORDER BY markdown5;

-- ----------------------------------------------------------------------------------
-- Data Check:
-- Markdown3 contains a small number of 
-- negative values (approximately 250 records, with a minimum value of -29). 
-- Given their low proportion relative to the overall dataset, these observations
-- were retained in the analysis as they do not introduce 
-- significant noise or distort overall distribution patterns. 
-- No evidence from the dataset documentation suggests a clear business definition
-- for negative markdown values, therefore they are treated as low-impact anomalies.
-- ----------------------------------------------------------------------------------
SELECT MIN(markdown3), MAX(markdown3)
FROM fact_sales;
-- Negative frequency
SELECT COUNT(*) 
FROM fact_sales
WHERE markdown3 < 0;


-- (Not possible promo vs no promo (0/Nan -> not 'no promo' but missing data)
-- ---------------------------------------------------------------------------
-- 4.4 -- Total Markdown Intensity èer Class Effect
-- ---------------------------------------------------------------------------
-- Rationale: Rather than analysing each markdown in isolation,
-- total markdown intensity (sum of all 5 channels) provides a
-- complete measure of total promotional investment per week.
--
-- Insight: Higher total markdown intensity is associated with
-- higher average weekly sales. The 'High' tier (total > 5000)
-- shows the strongest avg sales, suggesting that weeks with
-- sustained (different) promotional activity drive the most
-- revenue. However, it must be noted that actual causality cannot be
-- precisily inferred from this alone, as + promotions may coincide with
-- high-demand periods like Christmas (or maybe it's this + promotions on
-- these days that also -> + demand, anyway 2 strong effects.)
-- ---------------------------------------------------------------------------
WITH total_markdown AS (
SELECT
weekly_sales,
(markdown1 + markdown2 + markdown3 + markdown4 + markdown5) as markdown_total
FROM fact_sales_clean1)

SELECT
CASE
WHEN markdown_total < 1000 THEN 'LOW'
WHEN markdown_total BETWEEN 1000 AND 5000 THEN 'Medium'
WHEN markdown_total > 5000 THEN 'High'
END as markdown_tier,
AVG(weekly_sales) as avg_sales,
COUNT(*) as num_rows
FROM total_markdown
GROUP BY markdown_tier;