USE CATALOG sales_dwh;

-- ============================================================
-- GOLD TESTS — pipeline stops if any check fails
-- ============================================================

-- ── TEST 1: Gold row counts must match Silver ────────────────

SELECT CASE
  WHEN gold_count <> silver_count
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: dim_customer Gold matches Silver — ' || CAST(gold_count AS STRING) || ' rows'
END AS test_dim_customer_row_count
FROM (
  SELECT
    (SELECT COUNT(*) FROM sales_dwh.gold.dim_customer)   AS gold_count,
    (SELECT COUNT(*) FROM sales_dwh.silver.dim_customer) AS silver_count
);

SELECT CASE
  WHEN gold_count <> silver_count
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: dim_product Gold matches Silver — ' || CAST(gold_count AS STRING) || ' rows'
END AS test_dim_product_row_count
FROM (
  SELECT
    (SELECT COUNT(*) FROM sales_dwh.gold.dim_product)   AS gold_count,
    (SELECT COUNT(*) FROM sales_dwh.silver.dim_product) AS silver_count
);

SELECT CASE
  WHEN gold_count <> silver_count
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: dim_store Gold matches Silver — ' || CAST(gold_count AS STRING) || ' rows'
END AS test_dim_store_row_count
FROM (
  SELECT
    (SELECT COUNT(*) FROM sales_dwh.gold.dim_store)   AS gold_count,
    (SELECT COUNT(*) FROM sales_dwh.silver.dim_store) AS silver_count
);

SELECT CASE
  WHEN gold_count <> silver_count
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: fact_sales Gold matches Silver — ' || CAST(gold_count AS STRING) || ' rows'
END AS test_fact_sales_row_count
FROM (
  SELECT
    (SELECT COUNT(*) FROM sales_dwh.gold.fact_sales)   AS gold_count,
    (SELECT COUNT(*) FROM sales_dwh.silver.fact_sales) AS silver_count
);

-- ── TEST 2: No nulls on surrogate keys in Gold fact_sales ───

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null surrogate keys in Gold fact_sales'
END AS test_null_sk_in_fact_sales
FROM sales_dwh.gold.fact_sales
WHERE CustomerSK IS NULL
   OR ProductSK  IS NULL
   OR StoreSK    IS NULL;

-- ── TEST 3: Active record count matches Silver ───────────────

SELECT CASE
  WHEN gold_active <> silver_active
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: Active customer count matches Silver — ' || CAST(gold_active AS STRING) || ' active records'
END AS test_active_customer_count
FROM (
  SELECT
    (SELECT COUNT(*) FROM sales_dwh.gold.dim_customer   WHERE IsActive = 1) AS gold_active,
    (SELECT COUNT(*) FROM sales_dwh.silver.dim_customer WHERE IsActive = 1) AS silver_active
);

-- ── TEST 4: No negative or zero amounts in Gold ──────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All amounts in Gold fact_sales are positive'
END AS test_gold_amount_positive
FROM sales_dwh.gold.fact_sales
WHERE Amount <= 0 OR Amount IS NULL;

-- ── TEST 5: TxnDate must be within valid range ───────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All TxnDates are within valid range'
END AS test_txn_date_range
FROM sales_dwh.gold.fact_sales
WHERE TxnDate IS NULL
   OR TxnDate > current_date()
   OR TxnDate < TO_DATE('2020-01-01');

-- ── TEST 6: No orphan records in Gold fact_sales ────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All CustomerSKs in Gold fact_sales exist in Gold dim_customer'
END AS test_gold_customer_fk
FROM sales_dwh.gold.fact_sales f
WHERE NOT EXISTS (
  SELECT 1 FROM sales_dwh.gold.dim_customer d
  WHERE d.CustomerSK = f.CustomerSK
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All ProductSKs in Gold fact_sales exist in Gold dim_product'
END AS test_gold_product_fk
FROM sales_dwh.gold.fact_sales f
WHERE NOT EXISTS (
  SELECT 1 FROM sales_dwh.gold.dim_product d
  WHERE d.ProductSK = f.ProductSK
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All StoreSKs in Gold fact_sales exist in Gold dim_store'
END AS test_gold_store_fk
FROM sales_dwh.gold.fact_sales f
WHERE NOT EXISTS (
  SELECT 1 FROM sales_dwh.gold.dim_store d
  WHERE d.StoreSK = f.StoreSK
);

SELECT 'ALL GOLD TESTS PASSED' AS final_status;