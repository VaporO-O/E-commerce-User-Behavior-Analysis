-- 模块 2：指标体系 —— BI 看板数据源
-- 目标：从 user_behavior_clean 直接产出两张 BI 友好的结果表，供 Tableau / Power BI / FineBI 连接：
--   1. analysis_metrics_daily    —— 按天的指标宽表（趋势、漏斗、异常监控都用它）
--   2. analysis_metrics_overview —— 全期单行 KPI（指标卡用它）
-- 口径说明：
--   · 北极星指标 = GMV（购买事件的 price 之和，本数据集自带真实价格）。
--   · 订单数 orders 用 purchase 事件去重 user_session 近似（一个会话内的多件购买算一单）。
--   · 复购率在 overview 里按"购买过 >=2 个不同会话的用户 / 购买用户"计算（全期口径）。
--   · 各比率分母为 0 时用 NULLIF 保护，避免除零。

USE ecommerce_analysis;

DROP TABLE IF EXISTS analysis_metrics_daily;
DROP TABLE IF EXISTS analysis_metrics_overview;

-- ============================================================
-- 1. 按天指标宽表
-- ============================================================
CREATE TABLE analysis_metrics_daily AS
WITH daily AS (
  SELECT
    event_date_utc                                                        AS dt,
    COUNT(DISTINCT user_id)                                               AS dau,            -- 日活用户
    COUNT(*)                                                              AS events,         -- 行为事件数
    COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN user_id END)    AS view_users,     -- 浏览用户
    COUNT(DISTINCT CASE WHEN event_type = 'cart'     THEN user_id END)    AS cart_users,     -- 加购用户
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END)    AS purchase_users, -- 购买用户
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS orders,       -- 订单数（会话近似）
    ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2) AS gmv            -- 北极星：GMV
  FROM user_behavior_clean
  GROUP BY event_date_utc
),
new_user AS (   -- 当天首次活跃的新用户数
  SELECT cohort_date AS dt, COUNT(*) AS new_users
  FROM (
    SELECT user_id, MIN(event_date_utc) AS cohort_date
    FROM user_behavior_clean
    GROUP BY user_id
  ) AS f
  GROUP BY cohort_date
)
SELECT
  d.dt,
  d.dau,
  COALESCE(n.new_users, 0)                                  AS new_users,
  d.events,
  d.view_users,
  d.cart_users,
  d.purchase_users,
  d.orders,
  d.gmv,
  ROUND(d.purchase_users / NULLIF(d.dau, 0), 4)            AS paying_user_rate,      -- 付费用户率 = 购买用户/DAU
  ROUND(d.cart_users     / NULLIF(d.dau, 0), 4)            AS add_cart_rate,         -- 加购率 = 加购用户/DAU
  ROUND(d.cart_users     / NULLIF(d.view_users, 0), 4)     AS view_to_cart_rate,     -- 浏览→加购
  ROUND(d.purchase_users / NULLIF(d.cart_users, 0), 4)     AS cart_to_purchase_rate, -- 加购→购买
  ROUND(d.purchase_users / NULLIF(d.view_users, 0), 4)     AS view_to_purchase_rate, -- 浏览→购买
  ROUND(d.gmv / NULLIF(d.orders, 0), 2)                    AS aov,                   -- 客单价 = GMV/订单
  ROUND(d.gmv / NULLIF(d.purchase_users, 0), 2)            AS arppu                  -- 每付费用户收入 = GMV/购买用户
FROM daily AS d
LEFT JOIN new_user AS n ON d.dt = n.dt
ORDER BY d.dt;

ALTER TABLE analysis_metrics_daily
  ADD PRIMARY KEY (dt);

-- ============================================================
-- 2. 全期 KPI（单行，指标卡用）
-- ============================================================
CREATE TABLE analysis_metrics_overview AS
SELECT
  base.active_days,
  base.total_users,
  base.paying_users,
  ROUND(base.paying_users / NULLIF(base.total_users, 0), 4)  AS paying_user_rate,   -- 整体付费用户率
  base.orders,
  base.gmv,
  ROUND(base.gmv / NULLIF(base.active_days, 0), 2)           AS avg_daily_gmv,      -- 日均 GMV
  ROUND(base.gmv / NULLIF(base.orders, 0), 2)                AS aov,                -- 客单价
  ROUND(base.gmv / NULLIF(base.paying_users, 0), 2)          AS arppu,             -- 每付费用户收入
  rep.repeat_buyers,
  ROUND(rep.repeat_buyers / NULLIF(base.paying_users, 0), 4) AS repurchase_rate     -- 复购率 = 多单买家/买家
FROM (
  SELECT
    COUNT(DISTINCT event_date_utc)                                          AS active_days,
    COUNT(DISTINCT user_id)                                                 AS total_users,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END)      AS paying_users,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_session END) AS orders,
    ROUND(SUM(CASE WHEN event_type = 'purchase' THEN price ELSE 0 END), 2)  AS gmv
  FROM user_behavior_clean
) AS base
CROSS JOIN (
  SELECT SUM(CASE WHEN order_cnt >= 2 THEN 1 ELSE 0 END) AS repeat_buyers
  FROM (
    SELECT user_id, COUNT(DISTINCT user_session) AS order_cnt
    FROM user_behavior_clean
    WHERE event_type = 'purchase'
    GROUP BY user_id
  ) AS uo
) AS rep;

-- ============================================================
-- 执行后查看结果
-- ============================================================
SELECT * FROM analysis_metrics_overview;
SELECT * FROM analysis_metrics_daily ORDER BY dt;

-- 异常观察提示：按 GMV / view_to_cart_rate 找掉得最狠或冲高的日子
SELECT dt, dau, gmv, view_to_cart_rate, cart_to_purchase_rate, view_to_purchase_rate
FROM analysis_metrics_daily
ORDER BY gmv DESC
LIMIT 5;
