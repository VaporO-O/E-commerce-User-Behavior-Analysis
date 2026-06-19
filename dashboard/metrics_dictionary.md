# 模块 2 · 指标字典与看板搭建指南

本模块把模块 1 发现的问题"指标化、可监控"。数据源由 [`sql/08_metrics.sql`](../sql/08_metrics.sql) 产出两张表，BI 工具直接连这两张即可。

---

## 一、北极星指标

> **GMV（成交总额）** = 所有 `purchase` 事件的 `price` 之和。

选 GMV 的理由：本数据集自带真实价格，GMV 能同时体现"有没有人买"和"买得值不值"，是电商最贴合生意的单一指标。过程指标都是为了解释 GMV 怎么涨/跌。

GMV 的拆解链路：

```
GMV = 活跃用户(DAU) × 付费用户率 × 客单价
            │              │            │
        拉新/留存      转化漏斗      商品/客单运营
```

---

## 二、指标字典

### 1. 全期 KPI 表 `analysis_metrics_overview`（指标卡用，单行）

| 字段 | 指标 | 口径 / 公式 |
| --- | --- | --- |
| `active_days` | 统计天数 | 去重 `event_date_utc` |
| `total_users` | 总活跃用户 | 去重 `user_id` |
| `paying_users` | 购买用户 | 去重购买过的 `user_id` |
| `paying_user_rate` | 付费用户率 | 购买用户 / 总活跃用户 |
| `orders` | 订单数 | 购买事件去重 `user_session`（近似一单） |
| `gmv` | **GMV（北极星）** | Σ `price`（purchase 事件） |
| `avg_daily_gmv` | 日均 GMV | GMV / 统计天数 |
| `aov` | 客单价 | GMV / 订单数 |
| `arppu` | 每付费用户收入 | GMV / 购买用户 |
| `repeat_buyers` | 复购买家 | 购买过 ≥2 个不同会话的用户 |
| `repurchase_rate` | 复购率 | 复购买家 / 购买用户 |

### 2. 按天指标宽表 `analysis_metrics_daily`（趋势 / 漏斗 / 异常用，每天一行）

| 字段 | 指标 | 口径 / 公式 |
| --- | --- | --- |
| `dt` | 日期 | 主键 |
| `dau` | 日活用户 | 当天去重 `user_id` |
| `new_users` | 新用户 | 当天首次活跃的用户数 |
| `events` | 行为事件数 | 当天 `COUNT(*)` |
| `view_users` / `cart_users` / `purchase_users` | 各环节用户数 | 当天去重 `user_id`，按行为 |
| `orders` | 订单数 | 当天购买事件去重会话 |
| `gmv` | GMV | 当天 Σ `price`（purchase） |
| `paying_user_rate` | 付费用户率 | 购买用户 / DAU |
| `add_cart_rate` | 加购率 | 加购用户 / DAU |
| `view_to_cart_rate` | 浏览→加购转化 | 加购用户 / 浏览用户 |
| `cart_to_purchase_rate` | 加购→购买转化 | 购买用户 / 加购用户 |
| `view_to_purchase_rate` | 浏览→购买转化 | 购买用户 / 浏览用户 |
| `aov` | 客单价 | GMV / 订单 |
| `arppu` | 每付费用户收入 | GMV / 购买用户 |

> 说明：按天表的转化率为"当日同口径"近似（同一天内出现过某行为的用户），与模块 1 的"严格有序漏斗"口径不同，趋势监控用这个更合适。

---

## 三、看板布局建议

一页式监控大盘，从上到下四个区：

```
┌─────────────────────────────────────────────────────────────┐
│  ① KPI 指标卡（来自 overview）                                  │
│  GMV  |  购买用户  |  付费用户率  |  客单价 AOV  |  复购率        │
├──────────────────────────────┬──────────────────────────────┤
│  ② GMV / DAU 双轴趋势（按天）   │  ③ 转化漏斗                     │
│     折线 + 柱，标注异常日        │     view→cart→purchase 三段     │
├──────────────────────────────┼──────────────────────────────┤
│  ④ 转化率趋势（按天）           │  ⑤ 留存曲线 / 热力图            │
│     view→cart / cart→purchase  │     复用模块 1 的留存表          │
└──────────────────────────────┴──────────────────────────────┘
```

- **① 指标卡**：连 `analysis_metrics_overview`，5 张卡。
- **② 趋势**：连 `analysis_metrics_daily`，X=`dt`，左轴 `gmv`（柱）、右轴 `dau`（线）。
- **③ 漏斗**：用 `analysis_funnel_overview` 或 `analysis_funnel_user`（模块 1 已产出）。
- **④ 转化率趋势**：`analysis_metrics_daily` 的 `view_to_cart_rate` / `cart_to_purchase_rate`。
- **⑤ 留存**：`analysis_retention_cohort_summary` / `analysis_retention_matrix_30d`。

---

## 四、异常波动观察点（看板要标出来）

模块 1 已知主线问题——**浏览→加购仅约 19.9%** 是最大瓶颈，看板里 `view_to_cart_rate` 的趋势就是它的监控线。

在 `analysis_metrics_daily` 上要重点回答：
1. **哪天 GMV 异常高/低？** 是大促、还是数据缺口？（2019-11 可能有促销冲高）
2. GMV 波动是 **DAU 驱动**（流量）还是 **转化率/客单价驱动**（效率）？双轴趋势能一眼分辨。
3. `view_to_cart_rate` 是否有持续下滑的日子？→ 直接喂给模块 3 的 A/B 假设。

> 在 BI 里给异常日加注释标记（annotation），并在报告里写清归因，是这一模块的加分项。

---

## 五、连接方式

- **直连 MySQL（推荐）**：BI 工具新建 MySQL 数据源 → 库 `ecommerce_analysis` → 选 `analysis_metrics_daily`、`analysis_metrics_overview` 及模块 1 的 `analysis_*` 表。数据刷新后看板自动更新。
- **离线 CSV**：跑 `python scripts/export_results.py`，两张新表会一并导出到 `reports/sql_outputs/`，BI 直接连 CSV。
