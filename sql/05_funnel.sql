-- 模块 1：转化漏斗分析
-- 口径说明：
-- 1. user-level strict funnel：同一用户在样本窗口内按 view -> cart -> purchase 顺序发生。
-- 2. session-level strict funnel：同一会话内按 view -> cart -> purchase 顺序发生。
-- 3. remove_from_cart 不作为主漏斗节点，单独观察“加购流失”。

USE ecommerce_analysis;

-- 1. 行为事件整体分布。
SELECT
  event_type,
  COUNT(*) AS events,
  COUNT(DISTINCT user_id) AS users,
  COUNT(DISTINCT user_session) AS sessions
FROM user_behavior_clean
GROUP BY event_type
ORDER BY events DESC;

-- 2. 用户级严格漏斗：view -> cart -> purchase。
WITH first_event AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_type = 'view' THEN event_time_utc END) AS first_view_time,
    MIN(CASE WHEN event_type = 'cart' THEN event_time_utc END) AS first_cart_time,
    MIN(CASE WHEN event_type = 'purchase' THEN event_time_utc END) AS first_purchase_time
  FROM user_behavior_clean
  GROUP BY user_id
),
funnel_counts AS (
  SELECT
    SUM(first_view_time IS NOT NULL) AS view_users,
    SUM(first_view_time IS NOT NULL
        AND first_cart_time IS NOT NULL
        AND first_cart_time >= first_view_time) AS cart_users,
    SUM(first_view_time IS NOT NULL
        AND first_cart_time IS NOT NULL
        AND first_purchase_time IS NOT NULL
        AND first_cart_time >= first_view_time
        AND first_purchase_time >= first_cart_time) AS purchase_users
  FROM first_event
)
SELECT
  1 AS stage_order,
  'view' AS stage,
  view_users AS users,
  1.0000 AS previous_stage_rate,
  1.0000 AS view_to_stage_rate
FROM funnel_counts
UNION ALL
SELECT
  2 AS stage_order,
  'cart_after_view' AS stage,
  cart_users AS users,
  ROUND(cart_users / NULLIF(view_users, 0), 4) AS previous_stage_rate,
  ROUND(cart_users / NULLIF(view_users, 0), 4) AS view_to_stage_rate
FROM funnel_counts
UNION ALL
SELECT
  3 AS stage_order,
  'purchase_after_cart' AS stage,
  purchase_users AS users,
  ROUND(purchase_users / NULLIF(cart_users, 0), 4) AS previous_stage_rate,
  ROUND(purchase_users / NULLIF(view_users, 0), 4) AS view_to_stage_rate
FROM funnel_counts
ORDER BY stage_order;

-- 3. 会话级严格漏斗：同一个 user_session 内 view -> cart -> purchase。
WITH first_event AS (
  SELECT
    user_session,
    MIN(CASE WHEN event_type = 'view' THEN event_time_utc END) AS first_view_time,
    MIN(CASE WHEN event_type = 'cart' THEN event_time_utc END) AS first_cart_time,
    MIN(CASE WHEN event_type = 'purchase' THEN event_time_utc END) AS first_purchase_time
  FROM user_behavior_clean
  WHERE user_session <> 'unknown'
  GROUP BY user_session
),
funnel_counts AS (
  SELECT
    SUM(first_view_time IS NOT NULL) AS view_sessions,
    SUM(first_view_time IS NOT NULL
        AND first_cart_time IS NOT NULL
        AND first_cart_time >= first_view_time) AS cart_sessions,
    SUM(first_view_time IS NOT NULL
        AND first_cart_time IS NOT NULL
        AND first_purchase_time IS NOT NULL
        AND first_cart_time >= first_view_time
        AND first_purchase_time >= first_cart_time) AS purchase_sessions
  FROM first_event
)
SELECT
  1 AS stage_order,
  'view' AS stage,
  view_sessions AS sessions,
  1.0000 AS previous_stage_rate,
  1.0000 AS view_to_stage_rate
FROM funnel_counts
UNION ALL
SELECT
  2 AS stage_order,
  'cart_after_view' AS stage,
  cart_sessions AS sessions,
  ROUND(cart_sessions / NULLIF(view_sessions, 0), 4) AS previous_stage_rate,
  ROUND(cart_sessions / NULLIF(view_sessions, 0), 4) AS view_to_stage_rate
FROM funnel_counts
UNION ALL
SELECT
  3 AS stage_order,
  'purchase_after_cart' AS stage,
  purchase_sessions AS sessions,
  ROUND(purchase_sessions / NULLIF(cart_sessions, 0), 4) AS previous_stage_rate,
  ROUND(purchase_sessions / NULLIF(view_sessions, 0), 4) AS view_to_stage_rate
FROM funnel_counts
ORDER BY stage_order;

-- 4. 加购流失辅助观察：发生过 cart 的用户中，有多少也发生 remove_from_cart。
WITH user_flags AS (
  SELECT
    user_id,
    MAX(event_type = 'cart') AS has_cart,
    MAX(event_type = 'remove_from_cart') AS has_remove_from_cart,
    MAX(event_type = 'purchase') AS has_purchase
  FROM user_behavior_clean
  GROUP BY user_id
)
SELECT
  SUM(has_cart) AS cart_users,
  SUM(has_cart AND has_remove_from_cart) AS cart_users_with_remove,
  ROUND(SUM(has_cart AND has_remove_from_cart) / NULLIF(SUM(has_cart), 0), 4) AS remove_among_cart_users_rate,
  SUM(has_cart AND has_remove_from_cart AND has_purchase) AS removed_but_purchased_users
FROM user_flags;

-- 5. 品牌维度漏斗：用于找出“流量大但转化弱”的品牌。
WITH user_brand_flags AS (
  SELECT
    brand,
    user_id,
    MAX(event_type = 'view') AS has_view,
    MAX(event_type = 'cart') AS has_cart,
    MAX(event_type = 'purchase') AS has_purchase
  FROM user_behavior_clean
  WHERE brand <> 'unknown'
  GROUP BY brand, user_id
),
brand_funnel AS (
  SELECT
    brand,
    SUM(has_view) AS view_users,
    SUM(has_cart) AS cart_users,
    SUM(has_purchase) AS purchase_users
  FROM user_brand_flags
  GROUP BY brand
)
SELECT
  brand,
  view_users,
  cart_users,
  purchase_users,
  ROUND(cart_users / NULLIF(view_users, 0), 4) AS view_to_cart_rate,
  ROUND(purchase_users / NULLIF(cart_users, 0), 4) AS cart_to_purchase_rate,
  ROUND(purchase_users / NULLIF(view_users, 0), 4) AS view_to_purchase_rate
FROM brand_funnel
WHERE view_users >= 100
ORDER BY view_users DESC
LIMIT 30;

