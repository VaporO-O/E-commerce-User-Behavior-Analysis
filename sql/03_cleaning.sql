-- 阶段 1：数据清洗
-- 清洗重点：
-- 1. 去重：完全相同的原始行只保留一条。
-- 2. event_time 从 UTC 字符串转 DATETIME，并拆出日期、小时、星期。
-- 3. 过滤异常月份、异常 event_type、price <= 0。
-- 4. category_code / brand / user_session 缺失统一填 unknown，便于聚合。

USE ecommerce_analysis;

TRUNCATE TABLE user_behavior_clean;

INSERT INTO user_behavior_clean (
  event_time_utc,
  event_date_utc,
  event_hour_utc,
  event_weekday_utc,
  event_type,
  product_id,
  category_id,
  category_code,
  brand,
  price,
  user_id,
  user_session
)
SELECT
  parsed.event_time_utc,
  DATE(parsed.event_time_utc) AS event_date_utc,
  HOUR(parsed.event_time_utc) AS event_hour_utc,
  DAYOFWEEK(parsed.event_time_utc) AS event_weekday_utc,
  parsed.event_type,
  parsed.product_id,
  parsed.category_id,
  COALESCE(NULLIF(TRIM(parsed.category_code), ''), 'unknown') AS category_code,
  COALESCE(NULLIF(TRIM(parsed.brand), ''), 'unknown') AS brand,
  parsed.price,
  parsed.user_id,
  COALESCE(NULLIF(TRIM(parsed.user_session), ''), 'unknown') AS user_session
FROM (
  SELECT DISTINCT
    STR_TO_DATE(REPLACE(event_time, ' UTC', ''), '%Y-%m-%d %H:%i:%s') AS event_time_utc,
    event_type,
    product_id,
    category_id,
    category_code,
    brand,
    price,
    user_id,
    user_session
  FROM user_behavior_raw
) AS parsed
WHERE parsed.event_time_utc >= '2019-10-01 00:00:00'
  AND parsed.event_time_utc <  '2019-12-01 00:00:00'
  AND parsed.event_type IN ('view', 'cart', 'remove_from_cart', 'purchase')
  AND parsed.price > 0;

-- 灌完数据后一次性补索引（比建表时带索引、逐行维护更快）。只保留两个真正用得上的：
-- 1. (user_id, event_time_utc)：按用户分组/排序的漏斗、留存能用上。
-- 2. (event_type, user_id, event_time_utc, price) 覆盖索引：07 RFM、06 复购都先
--    WHERE event_type='purchase'，purchase 是少数行，可只扫购买行且覆盖所需列。
ALTER TABLE user_behavior_clean
  ADD INDEX idx_clean_user_time (user_id, event_time_utc),
  ADD INDEX idx_clean_purchase_cover (event_type, user_id, event_time_utc, price);

-- 清洗结果总览：重点看 raw_rows、clean_rows、removed_rows。
SELECT
  raw_stat.raw_rows,
  clean_stat.clean_rows,
  raw_stat.raw_rows - clean_stat.clean_rows AS removed_rows
FROM
  (SELECT COUNT(*) AS raw_rows FROM user_behavior_raw) AS raw_stat
CROSS JOIN
  (SELECT COUNT(*) AS clean_rows FROM user_behavior_clean) AS clean_stat;

-- 事件类型合法性检查：应只出现四类。
SELECT
  event_type,
  COUNT(*) AS rows_cnt,
  COUNT(DISTINCT user_id) AS users_cnt
FROM user_behavior_clean
GROUP BY event_type
ORDER BY rows_cnt DESC;

-- 缺失值处理效果检查。
SELECT
  SUM(category_code = 'unknown') AS unknown_category_rows,
  SUM(brand = 'unknown') AS unknown_brand_rows,
  SUM(user_session = 'unknown') AS unknown_session_rows
FROM user_behavior_clean;

