-- a. Top/bottom 3 LGAs by revenue + G02 demographics (last 12 months)
WITH last_12 AS (
  SELECT (max(month) - interval '11 months')::date AS start_dt,
         max(month)::date AS end_dt
  FROM silver.fact_listing
),
lga_of_listing AS (
  SELECT listing_id, source_month,
         COALESCE(listing_lga_code, host_lga_code) AS lga_code
  FROM (
    SELECT *, row_number() OVER (PARTITION BY listing_id, source_month ORDER BY valid_ts DESC) rn
    FROM silver.dim_suburb
  ) s WHERE rn = 1
),
lga_kpi AS (
  SELECT l.lga_code,
         AVG(f.est_revenue) FILTER (WHERE f.is_active) AS avg_est_rev_per_active
  FROM silver.fact_listing f
  JOIN last_12 w ON f.month::date BETWEEN w.start_dt AND w.end_dt
  JOIN lga_of_listing l ON l.listing_id = f.listing_id AND l.source_month = f.month
  GROUP BY 1
),
top3 AS (SELECT * FROM lga_kpi ORDER BY avg_est_rev_per_active DESC NULLS LAST LIMIT 3),
bottom3 AS (SELECT * FROM lga_kpi WHERE avg_est_rev_per_active IS NOT NULL
            ORDER BY avg_est_rev_per_active ASC NULLS LAST LIMIT 3),
picked AS (
  SELECT * FROM top3
  UNION ALL
  SELECT * FROM bottom3
)
SELECT
  p.lga_code,
  g02.lga_name,
  p.avg_est_rev_per_active,
  NULLIF(regexp_replace(g02.payload ->> 'Median_age_persons','[^0-9\.]','','g'),'')::numeric AS median_age,
  NULLIF(regexp_replace(g02.payload ->> 'Average_household_size','[^0-9\.]','','g'),'')::numeric AS avg_household_size
FROM picked p
LEFT JOIN gold.ref_census_g02 g02
  ON g02.lga_code = p.lga_code
ORDER BY p.avg_est_rev_per_active DESC NULLS LAST;

-- b. Correlation between LGA median age and avg revenue per active listing (last 12 months, G02)
WITH last_12 AS (
  SELECT (max(month) - interval '11 months')::date AS start_dt,
         max(month)::date AS end_dt
  FROM silver.fact_listing
),
lga_of_listing AS (
  SELECT listing_id, source_month,
         COALESCE(listing_lga_code, host_lga_code) AS lga_code
  FROM (
    SELECT *, row_number() OVER (PARTITION BY listing_id, source_month ORDER BY valid_ts DESC) rn
    FROM silver.dim_suburb
  ) s WHERE rn = 1
),
lga_rev AS (
  SELECT l.lga_code,
         AVG(f.est_revenue) FILTER (WHERE f.is_active) AS avg_rev
  FROM silver.fact_listing f
  JOIN last_12 w ON f.month::date BETWEEN w.start_dt AND w.end_dt
  JOIN lga_of_listing l ON l.listing_id = f.listing_id AND l.source_month = f.month
  GROUP BY 1
),
age AS (
  SELECT lga_code,
         NULLIF(regexp_replace(payload ->> 'Median_age_persons','[^0-9\.]','','g'),'')::numeric AS median_age
  FROM gold.ref_census_g02
)
SELECT corr(a.median_age, r.avg_rev) AS corr_median_age_vs_revenue
FROM lga_rev r
JOIN age a ON a.lga_code = r.lga_code
WHERE r.avg_rev IS NOT NULL AND a.median_age IS NOT NULL;

-- c. Top 5 neighbourhoods by avg revenue per active listing (last 12 months)
WITH last_12 AS (
  SELECT (max(month) - interval '11 months')::date AS start_dt,
         max(month)::date AS end_dt
  FROM silver.fact_listing
),
top5_nb AS (
  SELECT d.listing_neighbourhood
  FROM gold.dm_listing_neighbourhood d
  JOIN last_12 w ON d.month::date BETWEEN w.start_dt AND w.end_dt
  WHERE d.listing_neighbourhood IS NOT NULL
  GROUP BY d.listing_neighbourhood
  ORDER BY AVG(d.avg_estimated_revenue_per_active_listings) DESC NULLS LAST
  LIMIT 5
),
n_latest AS (
  SELECT listing_id,
         COALESCE(listing_neighbourhood, host_neighbourhood) AS listing_neighbourhood,
         row_number() OVER (PARTITION BY listing_id ORDER BY valid_ts DESC) rn
  FROM silver.dim_suburb
),
p_latest AS (
  SELECT listing_id, property_type, room_type, accommodates,
         row_number() OVER (PARTITION BY listing_id ORDER BY valid_ts DESC NULLS LAST) rn
  FROM silver.dim_property_base
),
base AS (
  SELECT
    n.listing_neighbourhood,
    p.property_type,
    p.room_type,
    p.accommodates,
    SUM(CASE WHEN f.is_active THEN f.stays ELSE 0 END) AS total_stays,
    AVG(f.est_revenue) FILTER (WHERE f.is_active AND f.est_revenue > 0) AS avg_rev_tiebreak
  FROM silver.fact_listing f
  JOIN n_latest n ON n.listing_id = f.listing_id AND n.rn = 1
  LEFT JOIN p_latest p ON p.listing_id = f.listing_id AND p.rn = 1
  JOIN top5_nb t ON t.listing_neighbourhood = n.listing_neighbourhood
  JOIN last_12 w ON f.month::date BETWEEN w.start_dt AND w.end_dt
  GROUP BY 1,2,3,4
),
ranked AS (
  SELECT *,
         row_number() OVER (PARTITION BY listing_neighbourhood
                            ORDER BY total_stays DESC, avg_rev_tiebreak DESC NULLS LAST) rn
  FROM base
)
SELECT listing_neighbourhood, property_type, room_type, accommodates, total_stays,
       avg_rev_tiebreak AS avg_estimated_revenue_per_active_listings
FROM ranked
WHERE rn = 1
ORDER BY listing_neighbourhood;

-- d. Multi-listing hosts concentration by LGA
WITH lga_map AS (
  SELECT listing_id,
         COALESCE(listing_lga_code, host_lga_code) AS lga_code
  FROM (
    SELECT *, row_number() OVER (PARTITION BY listing_id ORDER BY valid_ts DESC) rn
    FROM silver.dim_suburb
  ) s WHERE rn = 1
),
host_lga AS (
  SELECT f.host_id,
         count(distinct l.lga_code) AS lga_cnt,
         count(distinct f.listing_id) AS listing_cnt
  FROM silver.fact_listing f
  JOIN lga_map l ON f.listing_id = l.listing_id
  GROUP BY 1
  HAVING count(distinct f.listing_id) > 1
)
SELECT
  SUM(CASE WHEN lga_cnt = 1 THEN 1 ELSE 0 END) AS hosts_concentrated,
  SUM(CASE WHEN lga_cnt > 1 THEN 1 ELSE 0 END) AS hosts_distributed
FROM host_lga;

-- e. Single-listing hosts: revenue 12m vs median mortgage (by LGA)
WITH last_12 AS (
  SELECT (max(month) - interval '11 months')::date AS start_dt, max(month)::date AS end_dt
  FROM silver.fact_listing
),
rev AS (
  SELECT listing_id, SUM(est_revenue)::numeric AS rev_12m
  FROM silver.fact_listing f
  JOIN last_12 w ON f.month::date BETWEEN w.start_dt AND w.end_dt
  GROUP BY 1
),
single AS (
  SELECT host_id
  FROM silver.fact_listing
  GROUP BY host_id
  HAVING count(distinct listing_id) = 1
),
lga_map AS (
  SELECT listing_id,
         COALESCE(listing_lga_code, host_lga_code) AS lga_code
  FROM (
    SELECT *, row_number() OVER (PARTITION BY listing_id ORDER BY valid_ts DESC) rn
    FROM silver.dim_suburb
  ) s WHERE rn = 1
),
mort AS (
  SELECT lga_code,
         NULLIF(regexp_replace(payload ->> 'Median_mortgage_repay_monthly','[^0-9\.]','','g'),'')::numeric * 12 AS mort_annual
  FROM gold.ref_census_g02
),
eval AS (
  SELECT lm.lga_code,
         COUNT(*) AS host_cnt,
         SUM(CASE WHEN r.rev_12m IS NOT NULL AND m.mort_annual IS NOT NULL AND r.rev_12m >= m.mort_annual THEN 1 ELSE 0 END) AS can_cover
  FROM (SELECT DISTINCT host_id, listing_id FROM silver.fact_listing) f
  JOIN single s ON f.host_id = s.host_id
  JOIN rev r ON r.listing_id = f.listing_id
  JOIN lga_map lm ON lm.listing_id = f.listing_id
  LEFT JOIN mort m ON m.lga_code = lm.lga_code
  GROUP BY lm.lga_code
),
lga_name AS (
  SELECT DISTINCT lga_code, lga_name
  FROM gold.ref_census_g02
)
SELECT e.lga_code, n.lga_name, e.host_cnt, e.can_cover,
       ROUND(100.0 * e.can_cover / NULLIF(e.host_cnt,0), 2) AS pct_cover
FROM eval e
LEFT JOIN lga_name n ON n.lga_code = e.lga_code
WHERE e.host_cnt > 0
ORDER BY pct_cover DESC NULLS LAST;
