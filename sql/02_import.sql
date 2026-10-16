-- ============================================================
-- 02 · 导入数据
-- 前置：已执行 day1_schema.sql
--
-- 【推荐】方法一：Workbench 导入向导（不会报错，最省心）
--   逐表操作：左侧 SCHEMAS 展开 retail_project → 右键 stores 表
--   → Table Data Import Wizard → 选 csv/stores.csv → 编码选 utf8
--   → 字段自动对应 → Import。products / members / orders / inventory 同样处理。
--   完成后直接执行本文件里第 ③ 段（date_dim 生成）。
--
-- 【快速】方法二：本文件整体执行（LOAD DATA 方式）
--   若报错 "Loading local data is disabled" → 回退方法一。
--   注意：CSV 路径必须是本机实际路径，且不要用 Excel 另存这些 CSV。
-- ============================================================
USE retail_project;

-- ① 允许本地文件导入（需要管理员权限的 MySQL 实例可能执行失败，失败就用方法一）
SET GLOBAL local_infile = 1;

-- ② 导入 5 个 CSV（列顺序与建表一致，显式指定 utf8mb4）
LOAD DATA LOCAL INFILE 'C:/Users/33935/Desktop/溢达/retail_project_v2/csv/stores.csv'
INTO TABLE stores CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/33935/Desktop/溢达/retail_project_v2/csv/products.csv'
INTO TABLE products CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/33935/Desktop/溢达/retail_project_v2/csv/members.csv'
INTO TABLE members CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/33935/Desktop/溢达/retail_project_v2/csv/orders.csv'
INTO TABLE orders CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/33935/Desktop/溢达/retail_project_v2/csv/inventory.csv'
INTO TABLE inventory CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- ③ date_dim 不用 CSV，递归 CTE 直接生成 2026 全年
INSERT INTO date_dim (date_id, `year`, `month`, `day`, `week`, `weekday`, is_weekend)
WITH RECURSIVE dates AS (
  SELECT DATE '2026-01-01' AS d
  UNION ALL
  SELECT DATE_ADD(d, INTERVAL 1 DAY) FROM dates WHERE d < DATE '2026-12-31'
)
SELECT d, YEAR(d), MONTH(d), DAY(d), WEEK(d), WEEKDAY(d), IF(WEEKDAY(d) >= 5, 1, 0)
FROM dates;
