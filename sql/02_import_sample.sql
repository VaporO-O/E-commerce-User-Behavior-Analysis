-- 阶段 1：导入 1% 用户级抽样 CSV
-- 执行前确认：
-- 1. 已执行 sql/01_create_table.sql。
-- 2. MySQL 客户端允许 LOCAL INFILE。
--    命令行示例：mysql --local-infile=1 -u root -p ecommerce_analysis
-- 3. 如果 DBeaver 报 local infile 禁用，需要在驱动属性里启用 allowLoadLocalInfile。

USE ecommerce_analysis;

TRUNCATE TABLE user_behavior_raw;

LOAD DATA LOCAL INFILE 'D:/hyt/project/1/data/sample/user_behavior_sample.csv'
INTO TABLE user_behavior_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  event_time,
  event_type,
  product_id,
  category_id,
  @category_code,
  @brand,
  price,
  user_id,
  @user_session
)
SET
  category_code = NULLIF(TRIM(@category_code), ''),
  brand = NULLIF(TRIM(@brand), ''),
  user_session = NULLIF(TRIM(@user_session), '');

-- 导入后快速核对：样本摘要里应为 1,112,300 行。
SELECT COUNT(*) AS raw_rows
FROM user_behavior_raw;

