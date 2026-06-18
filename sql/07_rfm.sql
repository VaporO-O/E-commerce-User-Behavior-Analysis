-- 模块 1：RFM 用户分层
-- 口径说明：
-- 1. 仅针对发生过 purchase 的用户。
-- 2. Recency = 分析日期 - 最近一次购买日期；分析日期取样本最大日期的下一天。
-- 3. Frequency = 购买事件数。
-- 4. Monetary = purchase 事件价格之和。
-- 5. R/F/M 均按五分位打分，分数越高表示越好。
-- 6. 本脚本会将关键结果落表，表名统一以 analysis_ 开头。

USE ecommerce_analysis;

DROP TABLE IF EXISTS rfm_user_segments;
DROP TABLE IF EXISTS analysis_rfm_segment_summary;
DROP TABLE IF EXISTS analysis_rfm_metric_summary;
DROP TABLE IF EXISTS analysis_rfm_top_users;

CREATE TABLE rfm_user_segments AS
SELECT
  scored.user_id,
  scored.analysis_date,
  scored.last_purchase_date,
  scored.recency_days,
  scored.frequency,
  scored.monetary,
  scored.recency_score,
  scored.frequency_score,
  scored.monetary_score,
  CONCAT(scored.recency_score, scored.frequency_score, scored.monetary_score) AS rfm_score,
  CASE
    WHEN scored.recency_score >= 4 AND scored.frequency_score >= 4 AND scored.monetary_score >= 4
      THEN '重要价值用户'
    WHEN scored.recency_score >= 4 AND scored.frequency_score <= 2
      THEN '新近低频用户'
    WHEN scored.recency_score <= 2 AND scored.frequency_score >= 4
      THEN '重要唤回用户'
    WHEN scored.recency_score <= 2 AND scored.frequency_score <= 2
      THEN '流失风险用户'
    WHEN scored.monetary_score >= 4
      THEN '高消费潜力用户'
    ELSE '一般用户'
  END AS user_segment
FROM (
  SELECT
    rfm.*,
    NTILE(5) OVER (ORDER BY rfm.recency_days DESC) AS recency_score,
    NTILE(5) OVER (ORDER BY rfm.frequency ASC) AS frequency_score,
    NTILE(5) OVER (ORDER BY rfm.monetary ASC) AS monetary_score
  FROM (
    SELECT
      b.user_id,
      d.analysis_date,
      MAX(DATE(b.event_time_utc)) AS last_purchase_date,
      DATEDIFF(d.analysis_date, MAX(DATE(b.event_time_utc))) AS recency_days,
      COUNT(*) AS frequency,
      ROUND(SUM(b.price), 2) AS monetary
    FROM user_behavior_clean AS b
    CROSS JOIN (
      SELECT DATE_ADD(MAX(event_date_utc), INTERVAL 1 DAY) AS analysis_date
      FROM user_behavior_clean
    ) AS d
    WHERE b.event_type = 'purchase'
    GROUP BY b.user_id, d.analysis_date
  ) AS rfm
) AS scored;

ALTER TABLE rfm_user_segments
  ADD PRIMARY KEY (user_id),
  ADD KEY idx_rfm_segment (user_segment),
  ADD KEY idx_rfm_score (rfm_score),
  ADD KEY idx_rfm_recency (recency_days),
  ADD KEY idx_rfm_monetary (monetary);

-- 1. RFM 分层规模和价值贡献。
CREATE TABLE analysis_rfm_segment_summary AS
SELECT
  user_segment,
  COUNT(*) AS users,
  ROUND(COUNT(*) / total_stat.total_users, 4) AS user_ratio,
  ROUND(SUM(monetary), 2) AS segment_monetary,
  ROUND(SUM(monetary) / total_stat.total_monetary, 4) AS monetary_ratio,
  ROUND(AVG(recency_days), 2) AS avg_recency_days,
  ROUND(AVG(frequency), 2) AS avg_frequency,
  ROUND(AVG(monetary), 2) AS avg_monetary
FROM rfm_user_segments
CROSS JOIN (
  SELECT
    COUNT(*) AS total_users,
    SUM(monetary) AS total_monetary
  FROM rfm_user_segments
) AS total_stat
GROUP BY user_segment, total_stat.total_users, total_stat.total_monetary
ORDER BY segment_monetary DESC;

ALTER TABLE analysis_rfm_segment_summary
  ADD PRIMARY KEY (user_segment);

-- 2. RFM 原始指标概览。
CREATE TABLE analysis_rfm_metric_summary AS
SELECT
  COUNT(*) AS purchase_users,
  MIN(recency_days) AS min_recency_days,
  ROUND(AVG(recency_days), 2) AS avg_recency_days,
  MAX(recency_days) AS max_recency_days,
  MIN(frequency) AS min_frequency,
  ROUND(AVG(frequency), 2) AS avg_frequency,
  MAX(frequency) AS max_frequency,
  MIN(monetary) AS min_monetary,
  ROUND(AVG(monetary), 2) AS avg_monetary,
  MAX(monetary) AS max_monetary
FROM rfm_user_segments;

-- 3. 高价值用户 Top 50，可作为后续画像或运营策略样本。
CREATE TABLE analysis_rfm_top_users AS
SELECT
  user_id,
  user_segment,
  rfm_score,
  recency_days,
  frequency,
  monetary,
  last_purchase_date
FROM rfm_user_segments
ORDER BY monetary DESC, frequency DESC, recency_days ASC
LIMIT 50;

ALTER TABLE analysis_rfm_top_users
  ADD PRIMARY KEY (user_id);

-- 执行后查看结果。
SELECT * FROM analysis_rfm_segment_summary ORDER BY segment_monetary DESC;
SELECT * FROM analysis_rfm_metric_summary;
SELECT * FROM analysis_rfm_top_users ORDER BY monetary DESC, frequency DESC, recency_days ASC;
