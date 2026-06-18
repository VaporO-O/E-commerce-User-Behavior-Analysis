-- 阶段 1：MySQL 建库建表
-- 目标：先用 raw 表完整承接 CSV 字符串，再通过清洗脚本生成 typed clean 表。

CREATE DATABASE IF NOT EXISTS ecommerce_analysis
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE ecommerce_analysis;

DROP TABLE IF EXISTS user_behavior_raw;

CREATE TABLE user_behavior_raw (
  event_time     VARCHAR(32)  NOT NULL COMMENT 'UTC 时间字符串，形如 2019-10-01 00:00:00 UTC',
  event_type     VARCHAR(32)  NOT NULL COMMENT '行为类型：view/cart/remove_from_cart/purchase',
  product_id     BIGINT UNSIGNED NOT NULL COMMENT '商品 ID',
  category_id    BIGINT UNSIGNED NOT NULL COMMENT '商品类目 ID',
  category_code  VARCHAR(255) NULL COMMENT '类目层级名，原始数据可能为空',
  brand          VARCHAR(255) NULL COMMENT '品牌，原始数据可能为空',
  price          DECIMAL(12,2) NOT NULL COMMENT '价格',
  user_id        BIGINT UNSIGNED NOT NULL COMMENT '用户 ID',
  user_session   VARCHAR(64) NULL COMMENT '会话 ID',
  KEY idx_raw_user_id (user_id),
  KEY idx_raw_event_type (event_type),
  KEY idx_raw_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='原始抽样行为表';

DROP TABLE IF EXISTS user_behavior_clean;

CREATE TABLE user_behavior_clean (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '清洗后自增主键',
  event_time_utc     DATETIME NOT NULL COMMENT 'UTC 行为时间',
  event_date_utc     DATE NOT NULL COMMENT 'UTC 行为日期',
  event_hour_utc     TINYINT UNSIGNED NOT NULL COMMENT 'UTC 行为小时',
  event_weekday_utc  TINYINT UNSIGNED NOT NULL COMMENT 'UTC 星期，1=周日，7=周六',
  event_type         VARCHAR(32) NOT NULL COMMENT '行为类型',
  product_id         BIGINT UNSIGNED NOT NULL COMMENT '商品 ID',
  category_id        BIGINT UNSIGNED NOT NULL COMMENT '商品类目 ID',
  category_code      VARCHAR(255) NOT NULL COMMENT '类目层级名，缺失填 unknown',
  brand              VARCHAR(255) NOT NULL COMMENT '品牌，缺失填 unknown',
  price              DECIMAL(12,2) NOT NULL COMMENT '价格，仅保留 price > 0',
  user_id            BIGINT UNSIGNED NOT NULL COMMENT '用户 ID',
  user_session       VARCHAR(64) NOT NULL COMMENT '会话 ID，缺失填 unknown',
  PRIMARY KEY (id),
  KEY idx_clean_time (event_time_utc),
  KEY idx_clean_date (event_date_utc),
  KEY idx_clean_user_time (user_id, event_time_utc),
  KEY idx_clean_event_type (event_type),
  KEY idx_clean_session (user_session),
  KEY idx_clean_product (product_id),
  KEY idx_clean_category (category_id),
  KEY idx_clean_brand (brand)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='清洗后的用户行为表';
