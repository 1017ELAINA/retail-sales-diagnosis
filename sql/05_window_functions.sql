-- ============================================================
-- 05 · 窗口函数查询（排名 / 环比 / 累计 / 分组 Top N / 份额占比）
-- 核心三件套：JOIN / ROW_NUMBER() / LAG()，全部是 MySQL 8.0 窗口函数
-- 口诀：窗口函数 = 先分组(PARTITION BY) + 组内排序(ORDER BY) + 算数
--       它不减少行数，只是给每行"多算一列"
-- ============================================================
USE retail_project;

-- T1 门店月度销售额 + 每月内排名
SELECT ym, store_id, sales,
       ROW_NUMBER() OVER (PARTITION BY ym ORDER BY sales DESC) AS rn
FROM (
  SELECT DATE_FORMAT(order_date,'%Y-%m') AS ym, store_id,
         ROUND(SUM(sales_amount),2) AS sales
  FROM orders
  GROUP BY ym, store_id
) t
ORDER BY ym, rn;
-- 结论示例：三个月排名纹丝不动（ST002>ST003>ST001），说明门店基本盘稳定；
--          但 9 月 ST002 与第二名的差距从 6.4 万缩到 4.3 万，领先优势在收窄。

-- T2 门店月度环比【今天的主线题】
SELECT store_id, ym, sales,
       LAG(sales,1) OVER (PARTITION BY store_id ORDER BY ym) AS prev_sales,
       ROUND( (sales - LAG(sales,1) OVER (PARTITION BY store_id ORDER BY ym))
              / LAG(sales,1) OVER (PARTITION BY store_id ORDER BY ym) * 100, 2) AS mom_pct
FROM (
  SELECT store_id, DATE_FORMAT(order_date,'%Y-%m') AS ym,
         ROUND(SUM(sales_amount),2) AS sales
  FROM orders
  GROUP BY store_id, ym
) t
ORDER BY store_id, ym;
-- 结论示例：6 个环比里有 5 个在 ±3% 内属正常波动，唯独 ST002 9 月 -11.76%（少卖 2.58 万）
--          是唯一异常点，应作为下钻对象；这是后面诊断报告的主线。

-- T3 品类销售额排名
SELECT p.category,
       ROUND(SUM(o.sales_amount),2) AS sales,
       ROUND(SUM(o.sales_amount) / (SELECT SUM(sales_amount) FROM orders) * 100, 1) AS pct,
       ROW_NUMBER() OVER (ORDER BY SUM(o.sales_amount) DESC) AS rn
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category
ORDER BY sales DESC;
-- 结论示例：女装 70.76 万（46.6%）是第一品类，男装 39.2%，配饰仅 14.3%；
--          女装+男装占 85.8%，配饰是"顺带卖"的角色，资源投放应聚焦前两类。

-- T4 月度累计销售（running total）
SELECT DATE_FORMAT(order_date,'%Y-%m') AS ym,
       ROUND(SUM(sales_amount),2) AS month_sales,
       ROUND(SUM(SUM(sales_amount)) OVER (ORDER BY DATE_FORMAT(order_date,'%Y-%m')),2) AS running_total
FROM orders
GROUP BY ym
ORDER BY ym;
-- 结论示例：三季度累计 151.94 万；7、8 月基本持平（51.5 万上下），9 月回落到 48.5 万，
--          9 月是唯一环比下滑的月份，与 ST002 的异常同步。

-- T5 连带率门店对比
SELECT store_id,
       SUM(quantity) AS total_qty,
       COUNT(*)      AS orders_cnt,
       ROUND(SUM(quantity) / COUNT(*), 3) AS upt
FROM orders
GROUP BY store_id
ORDER BY upt DESC;
-- 结论示例：整体连带率 2.049（平均一单买 2 件）；ST002 以 2.013 垫底——
--          它订单数最多（862 单）却件数最少（1735 件），说明"单量不缺、每单买得少"，
--          这是 ST002 9 月下滑的头号嫌疑：问题出在连带，不在客流。

-- T6 各门店商品 Top3（分组取前 N）
SELECT store_id, product_id, sales, rn
FROM (
  SELECT o.store_id, o.product_id,
         ROUND(SUM(o.sales_amount),2) AS sales,
         ROW_NUMBER() OVER (PARTITION BY o.store_id ORDER BY SUM(o.sales_amount) DESC) AS rn
  FROM orders o
  GROUP BY o.store_id, o.product_id
) t
WHERE rn <= 3
ORDER BY store_id, rn;
-- 结论示例：三家店 Top1 各不相同（ST001 连衣裙 / ST002 西装 / ST003 连衣裙）；
--          ST002 靠高价西装撑起单店第一（西装单店 17.65 万），但也意味着
--          一旦高价品类卖不动，销售额波动最大——与它 9 月大跌吻合。

-- T7 品类月度环比
SELECT category, ym, sales,
       ROUND( (sales - LAG(sales,1) OVER (PARTITION BY category ORDER BY ym))
              / LAG(sales,1) OVER (PARTITION BY category ORDER BY ym) * 100, 2) AS mom_pct
FROM (
  SELECT p.category, DATE_FORMAT(o.order_date,'%Y-%m') AS ym,
         ROUND(SUM(o.sales_amount),2) AS sales
  FROM orders o
  JOIN products p ON o.product_id = p.product_id
  GROUP BY p.category, ym
) t
ORDER BY category, ym;
-- 结论示例：9 月女装 -6.71%、男装 -9.49% 双双下滑，配饰反而 +2.76%；
--          男装跌幅最深，需单独看是西装/夹克哪条子品类拖累。

-- T8 挑战题：每月门店排名 + 份额占比
SELECT ym, store_id, sales,
       ROW_NUMBER() OVER (PARTITION BY ym ORDER BY sales DESC) AS rn,
       ROUND(sales / SUM(sales) OVER (PARTITION BY ym) * 100, 1) AS share_pct
FROM (
  SELECT DATE_FORMAT(order_date,'%Y-%m') AS ym, store_id,
         ROUND(SUM(sales_amount),2) AS sales
  FROM orders
  GROUP BY ym, store_id
) t
ORDER BY ym, rn;
-- 结论示例：ST002 三月份额 41.8% → 42.1% → 39.8%，9 月掉了 2.3 个百分点，
--          而 ST003 同期从 29.8% 升到 30.9%——份额在被 ST003 蚕食，不只是大盘问题。
