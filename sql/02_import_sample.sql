-- 阶段 1：导入 1% 用户级抽样 CSV
-- 执行前确认：
-- 1. 已执行 sql/01_create_table.sql。
-- 2. MySQL 客户端允许 LOCAL INFILE。
--    命令行示例（从项目根目录运行，相对路径才成立）：
--    mysql --local-infile=1 -u root -p ecommerce_analysis < sql/02_import_sample.sql
-- 3. 如果 DBeaver 报 local infile 禁用，需要在驱动属性里启用 allowLoadLocalInfile。
--
-- ★★ 关于下面 LOAD DATA 的文件路径 ★★
-- 路径由“MySQL 客户端的工作目录”解析。默认用相对项目根目录的相对路径：
--   data/sample/user_behavior_sample.csv
-- · 命令行 mysql：在项目根目录启动即可正常工作。
-- · Navicat / DBeaver 等 GUI：工作目录不确定，相对路径常常找不到文件，
--   此时把下面这行换成你机器上的【绝对路径】，例如：
--   D:/你的路径/project/1/data/sample/user_behavior_sample.csv

USE ecommerce_analysis;

TRUNCATE TABLE user_behavior_raw;

LOAD DATA LOCAL INFILE 'data/sample/user_behavior_sample.csv'   -- 见上方说明：GUI 客户端请改成绝对路径
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

-- 导入后快速核对：样本摘要里应为 1,112,300 行。
SELECT COUNT(*) AS raw_rows
FROM user_behavior_raw;

