# SQL 执行说明

当前 SQL 目标方言为 MySQL。建议先使用 1% 用户级样本：

```text
data/sample/user_behavior_sample.csv
```

## 执行顺序

1. `01_create_table.sql`
   - 创建 `ecommerce_analysis` 数据库。
   - 创建原始表 `user_behavior_raw`。
   - 创建清洗表 `user_behavior_clean`。

2. `02_import_sample.sql`
   - 将 `data/sample/user_behavior_sample.csv` 导入 `user_behavior_raw`。
   - 样本摘要里的目标行数是 `1,112,300`。

3. `03_cleaning.sql`
   - 去重。
   - 解析 UTC 时间字符串。
   - 拆出日期、小时、星期。
   - 过滤异常月份、异常行为类型、`price <= 0`。
   - 将缺失的 `category_code`、`brand`、`user_session` 填为 `unknown`。

4. `04_eda.sql`
   - 查看总体规模、行为类型占比、按天/小时活跃、价格分布、热门品牌和类目。

5. `05_funnel.sql`
   - 计算用户级和会话级转化漏斗。
   - 单独观察 `remove_from_cart` 带来的加购流失。
   - 生成 `analysis_event_distribution`、`analysis_funnel_user`、`analysis_funnel_session`、`analysis_cart_remove_summary`、`analysis_brand_funnel_top`。

6. `06_retention.sql`
   - 计算首次活跃 cohort 的 D1 / D7 / D30 留存。
   - 输出 0-30 天留存明细矩阵。
   - 计算首次购买后的复购留存。
   - 生成 `analysis_retention_cohort_summary`、`analysis_retention_matrix_30d`、`analysis_repurchase_retention`。

7. `07_rfm.sql`
   - 创建 `rfm_user_segments` 表。
   - 输出 RFM 分层规模、价值贡献和高价值用户样本。
   - 生成 `analysis_rfm_segment_summary`、`analysis_rfm_metric_summary`、`analysis_rfm_top_users`。

## 命令行执行示例

如果 MySQL 命令行可用，可以这样执行：

```powershell
mysql --local-infile=1 -u root -p < sql/01_create_table.sql
mysql --local-infile=1 --load-data-local-dir="D:/hyt/project/1/data/sample" -u root -p ecommerce_analysis < sql/02_import_sample.sql
mysql --local-infile=1 -u root -p ecommerce_analysis < sql/03_cleaning.sql
mysql --local-infile=1 -u root -p ecommerce_analysis < sql/04_eda.sql
mysql --local-infile=1 -u root -p ecommerce_analysis < sql/05_funnel.sql
mysql --local-infile=1 -u root -p ecommerce_analysis < sql/06_retention.sql
mysql --local-infile=1 -u root -p ecommerce_analysis < sql/07_rfm.sql
```

如果使用 DBeaver，先连接本地 MySQL，再按文件顺序逐个执行。若 `LOAD DATA LOCAL INFILE`
报错，需要在 MySQL 连接驱动属性里启用 `allowLoadLocalInfile` 或同名选项。

如果使用 Navicat，`02_import_sample.sql` 依赖客户端读取本地 CSV。若 Navicat 报本地文件访问限制，
优先用上面的命令行方式执行 `02_import_sample.sql`，后续 `03` 到 `07` 可以继续在 Navicat 里运行。

## 注意

`02_import_sample.sql` 中的样本路径目前写死为：

```text
D:/hyt/project/1/data/sample/user_behavior_sample.csv
```

如果项目移动到其他目录，需要同步修改该路径。
