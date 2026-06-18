-- 阶段 1：导入 1% 用户级抽样 CSV
-- 执行前确认：
-- 1. 已执行 sql/01_create_table.sql。
-- 2. MySQL 客户端允许 LOCAL INFILE。
--    命令行示例：mysql --local-infile=1 -u root -p ecommerce_analysis
-- 3. 如果 DBeaver 报 local infile 禁用，需要在驱动属性里启用 allowLoadLocalInfile。

USE ecommerce_analysis;

TRUNCATE TABLE user_behavior_raw;

-- 批量导入提速：单事务提交 + 关闭唯一性/外键校验，减少每行的事务与校验开销。
SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

LOAD DATA LOCAL INFILE 'D:/hyt/project/1/data/sample/user_behavior_sample.csv'
INTO TABLE user_behavior_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
-- 抽样脚本用 Python csv 模块写出，默认行终止符为 \r\n；
-- 这里必须按 \r\n 切行，否则行尾的 \r 会粘在最后一列 user_session 上。
LINES TERMINATED BY '\r\n'
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

-- 提交本次导入并恢复会话设置。
COMMIT;
SET unique_checks = 1;
SET foreign_key_checks = 1;
SET autocommit = 1;

-- 导入后快速核对：样本摘要里应为 1,112,300 行。
SELECT COUNT(*) AS raw_rows
FROM user_behavior_raw;

