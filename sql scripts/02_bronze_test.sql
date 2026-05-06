USE CATALOG sales_dwh;

-- ============================================================
-- BRONZE TESTS — pipeline stops if any check fails
-- ============================================================

-- ── TEST 1: Row count must be greater than 0 ────────────────

SELECT CASE
  WHEN COUNT(*) = 0
  THEN CAST(1/0 AS STRING)  -- stops pipeline
  ELSE 'PASS: raw_customers has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_customers_row_count
FROM sales_dwh.bronze.raw_customers;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: raw_products has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_products_row_count
FROM sales_dwh.bronze.raw_products;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: raw_stores has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_stores_row_count
FROM sales_dwh.bronze.raw_stores;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: raw_sales has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_sales_row_count
FROM sales_dwh.bronze.raw_sales;

-- ── TEST 2: No null primary keys ────────────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null CustomerIDs in raw_customers'
END AS test_null_customer_id
FROM sales_dwh.bronze.raw_customers
WHERE CustomerID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null ProductIDs in raw_products'
END AS test_null_product_id
FROM sales_dwh.bronze.raw_products
WHERE ProductID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null StoreIDs in raw_stores'
END AS test_null_store_id
FROM sales_dwh.bronze.raw_stores
WHERE StoreID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null TransactionIDs in raw_sales'
END AS test_null_transaction_id
FROM sales_dwh.bronze.raw_sales
WHERE TransactionID IS NULL;

-- ── TEST 3: No duplicate primary keys ───────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No duplicate CustomerIDs in raw_customers'
END AS test_duplicate_customer_id
FROM (
  SELECT CustomerID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_customers
  GROUP BY CustomerID
  HAVING cnt > 1
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No duplicate ProductIDs in raw_products'
END AS test_duplicate_product_id
FROM (
  SELECT ProductID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_products
  GROUP BY ProductID
  HAVING cnt > 1
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No duplicate StoreIDs in raw_stores'
END AS test_duplicate_store_id
FROM (
  SELECT StoreID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_stores
  GROUP BY StoreID
  HAVING cnt > 1
);

SELECT TransactionID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_sales
  GROUP BY TransactionID
  HAVING cnt > 1

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No duplicate TransactionIDs in raw_sales'
END AS test_duplicate_transaction_id
FROM (
  SELECT TransactionID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_sales
  GROUP BY TransactionID
  HAVING cnt > 1
);

-- ── TEST 4: ingested_at must not be null ────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: ingested_at populated in all Bronze tables'
END AS test_ingested_at_not_null
FROM (
  SELECT CustomerID FROM sales_dwh.bronze.raw_customers WHERE ingested_at IS NULL
  UNION ALL
  SELECT ProductID  FROM sales_dwh.bronze.raw_products  WHERE ingested_at IS NULL
  UNION ALL
  SELECT StoreID    FROM sales_dwh.bronze.raw_stores    WHERE ingested_at IS NULL
  UNION ALL
  SELECT TransactionID FROM sales_dwh.bronze.raw_sales  WHERE ingested_at IS NULL
);

-- ── TEST 5: UnitPrice must be positive ──────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All UnitPrices are positive'
END AS test_unit_price_positive
FROM sales_dwh.bronze.raw_products
WHERE UnitPrice <= 0 OR UnitPrice IS NULL;

-- ── TEST 6: Quantity must be positive ───────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All Quantities are positive'
END AS test_quantity_positive
FROM sales_dwh.bronze.raw_sales
WHERE Quantity <= 0 OR Quantity IS NULL;

SELECT 'ALL BRONZE TESTS PASSED' AS final_status;