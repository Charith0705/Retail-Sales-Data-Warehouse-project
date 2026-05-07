USE CATALOG sales_dwh;
-- TEST 1: Row count

SELECT CASE
  WHEN COUNT(*) = 0
  THEN RAISE_ERROR('Test failed: raw_customers has 0 rows')
  ELSE 'PASS: raw_customers has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_customers_row_count
FROM sales_dwh.bronze.raw_customers;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN RAISE_ERROR('Test failed: raw_products has 0 rows')
  ELSE 'PASS: raw_products has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_products_row_count
FROM sales_dwh.bronze.raw_products;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN RAISE_ERROR('Test failed: raw_stores has 0 rows')
  ELSE 'PASS: raw_stores has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_stores_row_count
FROM sales_dwh.bronze.raw_stores;

SELECT CASE
  WHEN COUNT(*) = 0
  THEN RAISE_ERROR('Test failed: raw_sales has 0 rows')
  ELSE 'PASS: raw_sales has ' || CAST(COUNT(*) AS STRING) || ' rows'
END AS test_raw_sales_row_count
FROM sales_dwh.bronze.raw_sales;

-- TEST 2: No null primary keys 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN RAISE_ERROR('Test failed: Null CustomerIDs found in raw_customers')
  ELSE 'PASS: No null CustomerIDs in raw_customers'
END AS test_null_customer_id
FROM sales_dwh.bronze.raw_customers
WHERE CustomerID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN RAISE_ERROR('Test failed: Null ProductIDs found in raw_products')
  ELSE 'PASS: No null ProductIDs in raw_products'
END AS test_null_product_id
FROM sales_dwh.bronze.raw_products
WHERE ProductID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN RAISE_ERROR('Test failed: Null StoreIDs found in raw_stores')
  ELSE 'PASS: No null StoreIDs in raw_stores'
END AS test_null_store_id
FROM sales_dwh.bronze.raw_stores
WHERE StoreID IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN RAISE_ERROR('Test failed: Null TransactionIDs found in raw_sales')
  ELSE 'PASS: No null TransactionIDs in raw_sales'
END AS test_null_transaction_id
FROM sales_dwh.bronze.raw_sales
WHERE TransactionID IS NULL;

-- ── TEST 3: ingested_at must not be null ────────────────────

SELECT CASE
  WHEN COUNT(*) > 0
  THEN RAISE_ERROR('Test failed: ingested_at is null in some Bronze tables')
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

