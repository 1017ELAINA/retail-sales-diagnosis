-- ============================================================
-- 03 · 数据验收核对（6 项）
-- 逐条执行，结果应与注释中的"预期"一致
-- ============================================================
USE retail_project;

-- 1. 行数核对
SELECT 'stores' AS tbl, COUNT(*) AS cnt FROM stores
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'members', COUNT(*) FROM members
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL SELECT 'date_dim', COUNT(*) FROM date_dim;
-- 预期: stores=3, products=15, members=30,
--       orders=2542, inventory=135, date_dim=365

-- 2. 中文检查（应看到正常中文，无乱码）
SELECT * FROM stores;
SELECT * FROM products LIMIT 5;

-- 3. 门店月度销售（故事主查询：ST002 9 月应明显下滑）
SELECT s.store_name, DATE_FORMAT(o.order_date, '%Y-%m') AS ym,
       ROUND(SUM(o.sales_amount), 2) AS sales
FROM orders o
JOIN stores s ON o.store_id = s.store_id
GROUP BY s.store_name, ym
ORDER BY s.store_name, ym;
-- 预期: ST002  2026-07≈215046  2026-08≈218904  2026-09≈193153
--       ST002 9 月环比下滑约 11.8%

-- 4. ST002 订单数按月（客流应基本持平 → 说明下滑不是客流问题）
SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, COUNT(*) AS order_cnt
FROM orders
WHERE store_id = 'ST002'
GROUP BY ym ORDER BY ym;
-- 预期: 7月≈280 单, 8月≈288 单, 9月≈294 单（三个月相差不超过 5%）

-- 5. ST002 连带率按月（件/单，9 月应明显下滑 → 这就是根因方向）
SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym,
       ROUND(SUM(quantity) / COUNT(*), 2) AS items_per_order
FROM orders
WHERE store_id = 'ST002'
GROUP BY ym ORDER BY ym;
-- 预期: 7月≈2.08, 8月≈2.08, 9月≈1.88

-- 6. 会员销售占比（会员口径检查）
SELECT CASE WHEN member_id = '' THEN '非会员' ELSE '会员' END AS member_type,
       COUNT(*) AS order_cnt, ROUND(SUM(sales_amount), 2) AS sales
FROM orders
GROUP BY member_type;
