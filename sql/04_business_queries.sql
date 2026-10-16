-- ============================================================
-- 04 · 业务查询（门店 / 品类 / 客单价 / 折扣 / 环比，每题附业务结论）
-- ============================================================
USE retail_project;

-- T1 日销售额
SELECT order_date, ROUND(SUM(sales_amount), 2) AS daily_sales
FROM orders
GROUP BY order_date
ORDER BY order_date;
-- 结论示例：92 天总销售 151.94 万，日均约 1.65 万；周末日均 2.16 万约为工作日 1.45 万的 1.5 倍，
--          符合服装零售周末高峰规律，排班与促销资源应向周末倾斜。

-- T2 门店销售额
SELECT store_id, ROUND(SUM(sales_amount), 2) AS total_sales
FROM orders
GROUP BY store_id
ORDER BY total_sales DESC;
-- 结论示例：ST002 三个月 62.71 万，约为 ST001 的 1.44 倍，是头号门店。

-- T3 品类销售额
SELECT p.category, ROUND(SUM(o.sales_amount), 2) AS sales
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category
ORDER BY sales DESC;
-- 结论示例：女装 70.76 万（占 46.6%）是第一品类，男装 39.2%，配饰仅 14.3%。

-- T4 门店×月度销售趋势
SELECT o.store_id, DATE_FORMAT(o.order_date, '%Y-%m') AS ym,
       ROUND(SUM(o.sales_amount), 2) AS sales
FROM orders o
GROUP BY o.store_id, ym
ORDER BY o.store_id, ym;
-- 结论示例：ST001/ST003 三个月波动在 ±3% 内属正常；ST002 9 月环比 -11.8% 是唯一异常点，
--          应作为下钻分析对象。

-- T5 客单价
SELECT ROUND(AVG(sales_amount), 2) AS avg_order_value FROM orders;   -- 整体
SELECT store_id, ROUND(AVG(sales_amount), 2) AS aov, COUNT(*) AS orders_cnt
FROM orders
GROUP BY store_id;
-- 结论示例：整体客单价 597.72 元；ST002 727.50 元比 ST001 高 40%，
--          与其高单价品类（西装/风衣）占比高一致。

-- T6 折扣情况
SELECT ROUND(AVG(discount), 3) AS avg_disc, COUNT(*) AS orders_cnt,
       SUM(discount < 1.0) AS discounted_cnt
FROM orders;
SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, ROUND(AVG(discount), 3) AS avg_disc
FROM orders
GROUP BY ym;
-- 结论示例：平均折扣 0.97，40.5% 订单有折扣；三个月折扣稳定在 0.970~0.971，
--          9 月下滑与促销力度无关，可排除价格战因素。

-- T7 挑战题：HAVING
SELECT store_id, DATE_FORMAT(order_date, '%Y-%m') AS ym,
       ROUND(SUM(sales_amount), 2) AS sales
FROM orders
GROUP BY store_id, ym
HAVING SUM(sales_amount) > 150000
ORDER BY sales DESC;
-- 结论示例：月销超 15 万的组合共 6 个；ST001 全部被淘汰（最高月销仅 14.92 万），
--          ST002 即使异常月份仍居第一，但领先优势在缩小。
