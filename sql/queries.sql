-- Top 10 Stores -> Total Sales
SELECT
store_id,
SUM(weekly_sales) AS total_sales
FROM fact_sales
GROUP BY store_id
ORDER BY total_sales DESC
LIMIT 10;

-- What types of store sell more?
SELECT
f.store_id, s.size, s.store_type,
SUM(weekly_sales) AS total_sales
FROM fact_sales f
JOIN dim_store s ON f.store_id=s.store_id
GROUP BY f.store_id, s.size, s.store_type
ORDER BY total_sales DESC;

-- Store Stability - do they always perform well or only in certain periods?
SELECT
store_id,
date_id,
SUM(weekly_sales) AS weekly_total_sales
FROM fact_sales
GROUP BY store_id, date_id
ORDER BY store_id, date_id;

-- Measure Stability in Sales (store x dep x week row/level)
SELECT
store_id,
AVG(weekly_sales) AS avg_sales,
STDDEV_SAMP(weekly_sales) AS sales_volatility
FROM fact_sales
GROUP BY  store_id
ORDER BY sales_volatility;

-- Stablity (store * week only level -> subquery for this reason)
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

-- What types of store are less stable?
-- (subquery for store level + avg. volatility -> calculate avg. since 1 size/type -> many stores)
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

-- Do + volatily mean + revenue? (avg. sales vs volatilty)
-- Stability efficiency (avg. sales/volatility -> the higher the better)
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

-- Classification:
-- High sales + low volatility → best stores
-- High sales + high volatility → promo-driven/risky
-- Low sales + low volatility → stable but weak
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

-- Store Classification x Department -> Performance
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

-- Department % Sales Contribution(window function)
SELECT
f.dept_id,
SUM(f.weekly_sales) AS dept_sales,
ROUND(
	SUM(f.weekly_sales) * 100.0 /
	SUM(SUM(f.weekly_sales)) OVER (), 2) AS dept_contribution

FROM fact_sales f
GROUP BY f.dept_id
ORDER BY dept_sales DESC;

-- Initial preprocessing step imputed missing markdown values as 0.
-- However, dataset documentation clarified that NA values correspond to missing promotional data.
-- Now: revision of the markdown analysis approach to avoid misinterpretation
-- How: -> table view "fact_sales_clean" (only activate promotions, no 0 or NaN - then I will fix better for ML)
CREATE VIEW fact_sales_clean1 AS
SELECT *
FROM fact_sales
WHERE (markdown1 > 0 AND markdown2 > 0 AND markdown3 != 0
	   AND markdown4 > 0 AND markdown5 > 0);
-- Does Markdown increase sales
-- Average Promotion
SELECT
AVG(weekly_sales) AS avg_sales,
AVG(markdown1) AS avg_md1,
AVG(markdown2) AS avg_md2,
AVG(markdown3) AS avg_md3,
AVG(markdown4) AS avg_md4,
AVG(markdown5) AS avg_md5

FROM fact_sales_clean1;

-- Markdown vs Sales
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

-- Data Check
SELECT MIN(markdown3), MAX(markdown3)
FROM fact_sales;
-- Negative frequency
SELECT COUNT(*) 
FROM fact_sales
WHERE markdown3 < 0;

-- Markdown3 contains a small number of negative values (approximately 250 records, with a minimum value of -29). 
--Given their low proportion relative to the overall dataset, these observations were retained in the analysis as they do not introduce significant noise or distort overall distribution patterns. 
--No evidence from the dataset documentation suggests a clear business definition for negative markdown values, therefore they are treated as low-impact anomalies.

-- Not possible promo vs no promo (0/Nan -> not 'no promo' but missing data)

-- Total Markdown Intensity Class Effect
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