-- 模块 1：用户留存分析
-- 口径说明：
-- 1. cohort_date = 用户首次活跃日期。
-- 2. retention_day = 活跃日期 - 首次活跃日期。
-- 3. 次日 / 7 日 / 30 日留存只在观察窗口足够时计算，否则置为 NULL。

USE ecommerce_analysis;

-- 1. 首次活跃 cohort 的 D1 / D7 / D30 留存。
WITH first_active AS (
  SELECT
    user_id,
    MIN(event_date_utc) AS cohort_date
  FROM user_behavior_clean
  GROUP BY user_id
),
activity AS (
  SELECT DISTINCT
    user_id,
    event_date_utc AS active_date
  FROM user_behavior_clean
),
cohort_activity AS (
  SELECT
    f.cohort_date,
    DATEDIFF(a.active_date, f.cohort_date) AS retention_day,
    f.user_id
  FROM first_active AS f
  JOIN activity AS a
    ON f.user_id = a.user_id
   AND a.active_date >= f.cohort_date
),
cohort_size AS (
  SELECT
    cohort_date,
    COUNT(*) AS cohort_users
  FROM first_active
  GROUP BY cohort_date
),
date_bound AS (
  SELECT MAX(event_date_utc) AS max_event_date
  FROM user_behavior_clean
)
SELECT
  c.cohort_date,
  c.cohort_users,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 1 THEN ca.user_id END) AS d1_users,
  CASE
    WHEN c.cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 1 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 1 THEN ca.user_id END) / c.cohort_users, 4)
    ELSE NULL
  END AS d1_retention,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 7 THEN ca.user_id END) AS d7_users,
  CASE
    WHEN c.cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 7 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 7 THEN ca.user_id END) / c.cohort_users, 4)
    ELSE NULL
  END AS d7_retention,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 30 THEN ca.user_id END) AS d30_users,
  CASE
    WHEN c.cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 30 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 30 THEN ca.user_id END) / c.cohort_users, 4)
    ELSE NULL
  END AS d30_retention
FROM cohort_size AS c
LEFT JOIN cohort_activity AS ca
  ON c.cohort_date = ca.cohort_date
CROSS JOIN date_bound AS d
GROUP BY c.cohort_date, c.cohort_users, d.max_event_date
ORDER BY c.cohort_date;

-- 2. 0-30 天留存明细矩阵，适合导出做热力图。
WITH first_active AS (
  SELECT
    user_id,
    MIN(event_date_utc) AS cohort_date
  FROM user_behavior_clean
  GROUP BY user_id
),
activity AS (
  SELECT DISTINCT
    user_id,
    event_date_utc AS active_date
  FROM user_behavior_clean
),
cohort_activity AS (
  SELECT
    f.cohort_date,
    DATEDIFF(a.active_date, f.cohort_date) AS retention_day,
    f.user_id
  FROM first_active AS f
  JOIN activity AS a
    ON f.user_id = a.user_id
   AND a.active_date >= f.cohort_date
   AND DATEDIFF(a.active_date, f.cohort_date) BETWEEN 0 AND 30
),
cohort_size AS (
  SELECT
    cohort_date,
    COUNT(*) AS cohort_users
  FROM first_active
  GROUP BY cohort_date
)
SELECT
  ca.cohort_date,
  ca.retention_day,
  cs.cohort_users,
  COUNT(DISTINCT ca.user_id) AS retained_users,
  ROUND(COUNT(DISTINCT ca.user_id) / cs.cohort_users, 4) AS retention_rate
FROM cohort_activity AS ca
JOIN cohort_size AS cs
  ON ca.cohort_date = cs.cohort_date
GROUP BY ca.cohort_date, ca.retention_day, cs.cohort_users
ORDER BY ca.cohort_date, ca.retention_day;

-- 3. 购买用户复购留存：首次购买后 D1 / D7 / D30 是否再次购买。
WITH first_purchase AS (
  SELECT
    user_id,
    MIN(event_date_utc) AS purchase_cohort_date
  FROM user_behavior_clean
  WHERE event_type = 'purchase'
  GROUP BY user_id
),
purchase_activity AS (
  SELECT DISTINCT
    user_id,
    event_date_utc AS purchase_date
  FROM user_behavior_clean
  WHERE event_type = 'purchase'
),
cohort_activity AS (
  SELECT
    f.purchase_cohort_date,
    DATEDIFF(p.purchase_date, f.purchase_cohort_date) AS retention_day,
    f.user_id
  FROM first_purchase AS f
  JOIN purchase_activity AS p
    ON f.user_id = p.user_id
   AND p.purchase_date >= f.purchase_cohort_date
),
cohort_size AS (
  SELECT
    purchase_cohort_date,
    COUNT(*) AS purchase_users
  FROM first_purchase
  GROUP BY purchase_cohort_date
),
date_bound AS (
  SELECT MAX(event_date_utc) AS max_event_date
  FROM user_behavior_clean
)
SELECT
  c.purchase_cohort_date,
  c.purchase_users,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 1 THEN ca.user_id END) AS d1_repurchase_users,
  CASE
    WHEN c.purchase_cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 1 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 1 THEN ca.user_id END) / c.purchase_users, 4)
    ELSE NULL
  END AS d1_repurchase_rate,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 7 THEN ca.user_id END) AS d7_repurchase_users,
  CASE
    WHEN c.purchase_cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 7 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 7 THEN ca.user_id END) / c.purchase_users, 4)
    ELSE NULL
  END AS d7_repurchase_rate,
  COUNT(DISTINCT CASE WHEN ca.retention_day = 30 THEN ca.user_id END) AS d30_repurchase_users,
  CASE
    WHEN c.purchase_cohort_date <= DATE_SUB(d.max_event_date, INTERVAL 30 DAY)
    THEN ROUND(COUNT(DISTINCT CASE WHEN ca.retention_day = 30 THEN ca.user_id END) / c.purchase_users, 4)
    ELSE NULL
  END AS d30_repurchase_rate
FROM cohort_size AS c
LEFT JOIN cohort_activity AS ca
  ON c.purchase_cohort_date = ca.purchase_cohort_date
CROSS JOIN date_bound AS d
GROUP BY c.purchase_cohort_date, c.purchase_users, d.max_event_date
ORDER BY c.purchase_cohort_date;

