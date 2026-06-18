-- 阶段 1：基础探索性统计（EDA）
-- 目标：先回答数据规模、行为构成、时间分布、价格分布、热门品牌/类目。

USE ecommerce_analysis;

-- 1. 总体规模。
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT user_id) AS users,
  COUNT(DISTINCT product_id) AS products,
  COUNT(DISTINCT category_id) AS categories,
  COUNT(DISTINCT user_session) AS sessions,
  MIN(event_time_utc) AS min_event_time,
  MAX(event_time_utc) AS max_event_time
FROM user_behavior_clean;

-- 2. 行为类型占比。
SELECT
  event_type,
  COUNT(*) AS rows_cnt,
  ROUND(COUNT(*) / MAX(total_stat.total_rows), 4) AS rows_ratio,
  COUNT(DISTINCT user_id) AS users_cnt
FROM user_behavior_clean
JOIN (SELECT COUNT(*) AS total_rows FROM user_behavior_clean) AS total_stat
GROUP BY event_type
ORDER BY rows_cnt DESC;

-- 3. 按天活跃和 GMV 走势。
SELECT
  event_date_utc,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS active_users,
  SUM(event_type = 'purchase') AS purchase_events,
  ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS gmv
FROM user_behavior_clean
GROUP BY event_date_utc
ORDER BY event_date_utc;

-- 4. 按小时活跃分布。
SELECT
  event_hour_utc,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS active_users
FROM user_behavior_clean
GROUP BY event_hour_utc
ORDER BY event_hour_utc;

-- 5. 价格分布概览。
SELECT
  MIN(price) AS min_price,
  ROUND(AVG(price), 2) AS avg_price,
  ROUND(STDDEV_SAMP(price), 2) AS std_price,
  MAX(price) AS max_price
FROM user_behavior_clean;

-- 6. 热门品牌 Top 20。
SELECT
  brand,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS users,
  ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS gmv
FROM user_behavior_clean
GROUP BY brand
ORDER BY events DESC
LIMIT 20;

-- 7. 热门类目 Top 20。
SELECT
  category_code,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS users,
  ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS gmv
FROM user_behavior_clean
GROUP BY category_code
ORDER BY events DESC
LIMIT 20;
