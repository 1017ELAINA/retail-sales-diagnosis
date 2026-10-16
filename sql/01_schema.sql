-- ============================================================
-- 01 · 建库建表（6 张表，utf8mb4）
-- 用 MySQL Workbench 打开本文件，全选（Ctrl+A）后点闪电图标执行
-- 全程 utf8mb4，中文不会乱码
-- ============================================================

DROP DATABASE IF EXISTS retail_project;

CREATE DATABASE retail_project
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE retail_project;

-- 门店
CREATE TABLE stores (
  store_id   VARCHAR(10)  PRIMARY KEY,
  store_name VARCHAR(50)  NOT NULL,
  city       VARCHAR(20),
  region     VARCHAR(20),
  open_date  DATE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 商品
CREATE TABLE products (
  product_id   VARCHAR(10)  PRIMARY KEY,
  product_name VARCHAR(100) NOT NULL,
  category     VARCHAR(50),
  sub_category VARCHAR(50),
  price        DECIMAL(10,2),
  cost         DECIMAL(10,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 会员
CREATE TABLE members (
  member_id   VARCHAR(10) PRIMARY KEY,
  member_name VARCHAR(50),
  gender      VARCHAR(10),
  age         INT,
  level       VARCHAR(20),
  join_date   DATE,
  store_id    VARCHAR(10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 订单（一行 = 一张单；member_id 为空串表示非会员）
CREATE TABLE orders (
  order_id     VARCHAR(20) PRIMARY KEY,
  order_date   DATE        NOT NULL,
  store_id     VARCHAR(10) NOT NULL,
  product_id   VARCHAR(10) NOT NULL,
  member_id    VARCHAR(10),
  quantity     INT,
  unit_price   DECIMAL(10,2),
  discount     DECIMAL(5,2),
  sales_amount DECIMAL(10,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 库存（每月 1 号快照：期初库存 / 当月进货 / 当月售出）
CREATE TABLE inventory (
  inventory_date DATE,
  store_id       VARCHAR(10),
  product_id     VARCHAR(10),
  stock_qty      INT,
  in_qty         INT,
  out_qty        INT,
  PRIMARY KEY (inventory_date, store_id, product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 日期维度表（2026 全年，导入脚本里用 SQL 生成）
CREATE TABLE date_dim (
  date_id    DATE PRIMARY KEY,
  `year`     INT,
  `month`    INT,
  `day`      INT,
  `week`     INT,
  weekday    INT,
  is_weekend TINYINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
