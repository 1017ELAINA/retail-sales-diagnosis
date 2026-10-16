-- ============================================================
-- 06 · 库存健康度诊断与补货 / 调拨建议
-- 依赖：已执行 01_schema.sql ~ 03_verify.sql，数据已导入
-- 目的：把「9 月主力款断货」这个结论，变成一张可执行的补货 / 调拨清单
-- 说明：本文件共 5 段，建议逐段执行，每段结果都对应 Excel 里的一个 sheet
-- ============================================================
USE retail_project;


-- ============================================================
-- 第 ① 段：数据质量校验 —— 库存滚动闭合
-- 口径：期初库存 + 本月入库 - 本月销量 = 期末库存 = 下月期初库存
-- 预期：45 组「店 × 款 × 月」中，有 7 组闭合不成立（推算期末 < 0）
--       业务含义：销量超过了可售库存 → 断货超卖
-- ============================================================
WITH monthly_sales AS (
    SELECT store_id,
           product_id,
           DATE_FORMAT(order_date, '%Y-%m') AS ym,
           SUM(quantity)                    AS sold_qty
    FROM orders
    GROUP BY store_id, product_id, DATE_FORMAT(order_date, '%Y-%m')
)
SELECT DATE_FORMAT(i.inventory_date, '%Y-%m')                    AS 月份,
       i.store_id                                                AS 门店编码,
       s.store_name                                              AS 门店,
       i.product_id                                              AS 商品编码,
       p.product_name                                            AS 商品,
       i.stock_qty                                               AS 期初库存,
       i.in_qty                                                  AS 本月入库,
       IFNULL(m.sold_qty, 0)                                     AS 本月销量,
       i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0)            AS 推算期末,
       i.stock_qty + i.in_qty - i.out_qty                        AS 表内闭合期末,
       CASE WHEN i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0) < 0
            THEN '异常-负库存（断货超卖）'
            ELSE '正常' END                                       AS 校验结论
FROM inventory i
JOIN stores   s ON s.store_id   = i.store_id
JOIN products p ON p.product_id = i.product_id
LEFT JOIN monthly_sales m
       ON m.store_id   = i.store_id
      AND m.product_id = i.product_id
      AND m.ym         = DATE_FORMAT(i.inventory_date, '%Y-%m')
ORDER BY (i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0)) ASC;
-- 取数结论：45 组中有 7 组为负库存，全部集中在需求最高的 6 个「店 × 款」组合


-- ============================================================
-- 第 ② 段：库存健康度分档（以 2026-09 为例）
-- 周转天数 = 期末库存 ÷ 日均销量
--   日均销量 = 当月销量 ÷ 当月天数
-- 分档：< 5 天 = 断货；5~15 = 紧张；15~45 = 健康；45~90 = 偏高；>= 90 = 积压
-- 预期：45 组中 断货 8 / 紧张 3 / 健康 12 / 偏高 13 / 积压 9
-- ============================================================
WITH monthly_sales AS (
    SELECT store_id, product_id,
           DATE_FORMAT(order_date, '%Y-%m') AS ym,
           SUM(quantity)                    AS sold_qty
    FROM orders
    GROUP BY store_id, product_id, DATE_FORMAT(order_date, '%Y-%m')
),
base AS (
    SELECT DATE_FORMAT(i.inventory_date, '%Y-%m')                 AS ym,
           DAY(LAST_DAY(i.inventory_date))                        AS 当月天数,
           i.store_id, s.store_name,
           i.product_id, p.product_name, p.category, p.price,
           i.stock_qty                                            AS 期初库存,
           i.in_qty                                               AS 本月入库,
           IFNULL(m.sold_qty, 0)                                  AS 本月销量,
           i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0)         AS 期末库存,
           ROUND(IFNULL(m.sold_qty, 0) / DAY(LAST_DAY(i.inventory_date)), 2) AS 日均销量
    FROM inventory i
    JOIN stores   s ON s.store_id   = i.store_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN monthly_sales m
           ON m.store_id   = i.store_id
          AND m.product_id = i.product_id
          AND m.ym         = DATE_FORMAT(i.inventory_date, '%Y-%m')
    WHERE i.inventory_date = '2026-09-01'
)
SELECT ym AS 月份, store_id AS 门店编码, store_name AS 门店,
       product_id AS 商品编码, product_name AS 商品, price AS 单价,
       期初库存, 本月入库, 本月销量, 期末库存, 日均销量,
       CASE WHEN 日均销量 = 0 THEN 9999
            ELSE ROUND(期末库存 / 日均销量, 1) END                 AS 周转天数,
       CASE WHEN 日均销量 = 0                                   THEN '积压'
            WHEN 期末库存 / 日均销量 <  5  THEN '断货'
            WHEN 期末库存 / 日均销量 <  15 THEN '紧张'
            WHEN 期末库存 / 日均销量 <  45 THEN '健康'
            WHEN 期末库存 / 日均销量 <  90 THEN '偏高'
            ELSE '积压' END                                        AS 健康度,
       ROUND(期末库存 * price, 0)                                  AS 占用资金
FROM base
ORDER BY 周转天数 ASC;


-- ============================================================
-- 第 ③ 段：断货 / 紧张清单（按紧急度排序）
-- 目的：一眼看出「哪些店哪些款快没货了」
-- 预期：11 组（断货 8 + 紧张 3），日均销量集中在 1.6 ~ 2.4 件/天
-- ============================================================
WITH monthly_sales AS (
    SELECT store_id, product_id,
           DATE_FORMAT(order_date, '%Y-%m') AS ym,
           SUM(quantity)                    AS sold_qty
    FROM orders
    GROUP BY store_id, product_id, DATE_FORMAT(order_date, '%Y-%m')
),
base AS (
    SELECT i.store_id, s.store_name, i.product_id, p.product_name, p.price,
           i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0)          AS 期末库存,
           ROUND(IFNULL(m.sold_qty, 0) / 30, 2)                    AS 日均销量,
           IFNULL(m.sold_qty, 0)                                   AS 本月销量
    FROM inventory i
    JOIN stores   s ON s.store_id   = i.store_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN monthly_sales m
           ON m.store_id = i.store_id AND m.product_id = i.product_id AND m.ym = '2026-09'
    WHERE i.inventory_date = '2026-09-01'
)
SELECT store_name AS 门店, product_name AS 商品, price AS 单价,
       期末库存, 本月销量, 日均销量,
       ROUND(期末库存 / 日均销量, 1)                               AS 周转天数,
       CASE WHEN 期末库存 / 日均销量 < 5 THEN '断货' ELSE '紧张' END AS 紧急度,
       -- 目标周转 30 天，缺口向上取整到 5 的倍数
       CEIL(GREATEST(日均销量 * 30 - 期末库存, 0) / 5) * 5          AS 建议补货量,
       CEIL(GREATEST(日均销量 * 30 - 期末库存, 0) / 5) * 5 * price  AS 补货金额
FROM base
WHERE 日均销量 > 0 AND 期末库存 / 日均销量 < 15
ORDER BY 周转天数 ASC;


-- ============================================================
-- 第 ④ 段：跨店调拨匹配（积压店 → 缺货店，同款）
-- 规则：调出方 = 周转 >= 90 天，可调出 = 期末库存 - 日均销量 × 45（保留 45 天用量）
--       调入方 = 周转 <  15 天，需调入 = 日均销量 × 30 - 期末库存
-- 目的：优先内部调拨而不是新采购 —— 不增加采购成本，只加速库存周转
-- 预期：可匹配 2 条，合计价值约 ¥120,355
-- ============================================================
WITH monthly_sales AS (
    SELECT store_id, product_id,
           DATE_FORMAT(order_date, '%Y-%m') AS ym,
           SUM(quantity)                    AS sold_qty
    FROM orders
    GROUP BY store_id, product_id, DATE_FORMAT(order_date, '%Y-%m')
),
base AS (
    SELECT i.store_id, s.store_name, i.product_id, p.product_name, p.price,
           i.stock_qty + i.in_qty - IFNULL(m.sold_qty, 0)          AS 期末库存,
           IFNULL(m.sold_qty, 0) / 30                              AS 日均销量
    FROM inventory i
    JOIN stores   s ON s.store_id   = i.store_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN monthly_sales m
           ON m.store_id = i.store_id AND m.product_id = i.product_id AND m.ym = '2026-09'
    WHERE i.inventory_date = '2026-09-01'
),
sup AS (   -- 供给方：积压，可调出
    SELECT *, FLOOR(GREATEST(期末库存 - 日均销量 * 45, 0) / 5) * 5 AS 可调出
    FROM base WHERE 日均销量 > 0 AND 期末库存 / 日均销量 >= 90
),
dem AS (   -- 需求方：断货 / 紧张，需调入
    SELECT *, CEIL(GREATEST(日均销量 * 30 - 期末库存, 0) / 5) * 5 AS 需调入
    FROM base WHERE 日均销量 > 0 AND 期末库存 / 日均销量 < 15
)
SELECT d.product_id AS 商品编码, d.product_name AS 商品,
       s.store_name  AS 调出门店, d.store_name AS 调入门店,
       LEAST(s.可调出, d.需调入)                    AS 建议调拨量,
       LEAST(s.可调出, d.需调入) * d.price           AS 调拨金额,
       ROUND(s.日均销量, 2) AS 调出方日均, ROUND(d.日均销量, 2) AS 调入方日均
FROM dem d
JOIN sup s ON s.product_id = d.product_id          -- 同款才可调拨
WHERE LEAST(s.可调出, d.需调入) > 0
ORDER BY 调拨金额 DESC;
-- 取数结论：仅 2 条可内部调拨（P003 商务西装 95 件、P010 中长款风衣 50 件），
--           说明「全网都缺」的款必须走采购补货，调拨解决不了


-- ============================================================
-- 第 ⑤ 段：全网供需缺口（调拨解决不了的部分 → 必须采购）
-- 逻辑：按商品汇总全网期末库存与全网日均销量，算出全网缺口
-- 预期：P002 / P007 等款全网周转不足，需要下单补货
-- ============================================================
WITH monthly_sales AS (
    SELECT product_id,
           SUM(quantity) AS sold_qty
    FROM orders
    WHERE order_date >= '2026-09-01' AND order_date <= '2026-09-30'
    GROUP BY product_id
),
inv_sum AS (
    SELECT i.product_id,
           SUM(i.stock_qty + i.in_qty - i.out_qty) AS 全网期末库存
    FROM inventory i
    WHERE i.inventory_date = '2026-09-01'
    GROUP BY i.product_id
)
SELECT p.product_id AS 商品编码, p.product_name AS 商品, p.category AS 品类,
       p.price AS 单价,
       a.全网期末库存,
       s.sold_qty AS 全网9月销量,
       ROUND(s.sold_qty / 30, 2) AS 全网日均,
       ROUND(a.全网期末库存 / (s.sold_qty / 30), 1) AS 全网周转天数,
       CEIL(GREATEST(s.sold_qty / 30 * 30 - a.全网期末库存, 0) / 5) * 5 AS 全网缺口
FROM products p
JOIN monthly_sales s ON s.product_id = p.product_id
JOIN inv_sum       a ON a.product_id = p.product_id
ORDER BY 全网周转天数 ASC;
