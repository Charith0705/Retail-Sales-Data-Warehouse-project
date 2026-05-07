USE CATALOG sales_dwh;

-- TEST 1: No null surrogate keys

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null CustomerSK in dim_customer'
END AS test_null_customer_sk
FROM sales_dwh.silver.dim_customer
WHERE CustomerSK IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null ProductSK in dim_product'
END AS test_null_product_sk
FROM sales_dwh.silver.dim_product
WHERE ProductSK IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No null StoreSK in dim_store'
END AS test_null_store_sk
FROM sales_dwh.silver.dim_store
WHERE StoreSK IS NULL;

-- TEST 2: No duplicate active records per CustomerID

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No duplicate active CustomerIDs in dim_customer'
END AS test_duplicate_active_customer
FROM (
  SELECT CustomerID, COUNT(*) AS cnt
  FROM sales_dwh.silver.dim_customer
  WHERE IsActive = 1
  GROUP BY CustomerID
  HAVING cnt > 1
);

-- TEST 3: SCD2 date continuity 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: SCD2 date continuity is correct'
END AS test_scd2_date_continuity
FROM (
  SELECT
    expired.CustomerID,
    expired.EndDate,
    active.StartDate
  FROM sales_dwh.silver.dim_customer expired
  INNER JOIN sales_dwh.silver.dim_customer active
    ON  expired.CustomerID = active.CustomerID
    AND expired.IsActive   = 0
    AND active.IsActive    = 1
  WHERE expired.EndDate <> active.StartDate - INTERVAL 1 DAY
);

-- TEST 4: Every expired record must have one active record

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: Every expired customer has an active record'
END AS test_expired_has_active
FROM (
  SELECT CustomerID
  FROM sales_dwh.silver.dim_customer
  WHERE IsActive = 0
  AND CustomerID NOT IN (
    SELECT CustomerID
    FROM sales_dwh.silver.dim_customer
    WHERE IsActive = 1
  )
);

-- TEST 5: No nulls in critical Silver columns

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No nulls in critical dim_customer columns'
END AS test_null_customer_columns
FROM sales_dwh.silver.dim_customer
WHERE CustomerID   IS NULL
   OR CustomerName IS NULL
   OR Email        IS NULL
   OR City         IS NULL
   OR Address      IS NULL
   OR StartDate    IS NULL
   OR EndDate      IS NULL
   OR IsActive     IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No nulls in critical dim_product columns'
END AS test_null_product_columns
FROM sales_dwh.silver.dim_product
WHERE ProductID   IS NULL
   OR ProductName IS NULL
   OR Category    IS NULL
   OR UnitPrice   IS NULL;

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: No nulls in critical dim_store columns'
END AS test_null_store_columns
FROM sales_dwh.silver.dim_store
WHERE StoreID   IS NULL
   OR StoreName IS NULL
   OR Region    IS NULL;

-- TEST 6: Amount calculation validation 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: Amount calculation is correct'
END AS test_amount_calculation
FROM (
  SELECT
    f.TransactionID,
    f.Amount                                AS actual_amount,
    f.Quantity * p.UnitPrice                AS expected_amount
  FROM sales_dwh.silver.fact_sales f
  INNER JOIN sales_dwh.silver.dim_product p
    ON f.ProductSK = p.ProductSK
  WHERE ABS(f.Amount - (f.Quantity * p.UnitPrice)) > 0.01
  AND   f.Amount IS NOT NULL
);

-- TEST 7: Referential integrity 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All CustomerSKs in fact_sales exist in dim_customer'
END AS test_customer_fk
FROM sales_dwh.silver.fact_sales f
WHERE f.CustomerSK IS NOT NULL
AND NOT EXISTS (
  SELECT 1 FROM sales_dwh.silver.dim_customer d
  WHERE d.CustomerSK = f.CustomerSK
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All ProductSKs in fact_sales exist in dim_product'
END AS test_product_fk
FROM sales_dwh.silver.fact_sales f
WHERE f.ProductSK IS NOT NULL
AND NOT EXISTS (
  SELECT 1 FROM sales_dwh.silver.dim_product d
  WHERE d.ProductSK = f.ProductSK
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All StoreSKs in fact_sales exist in dim_store'
END AS test_store_fk
FROM sales_dwh.silver.fact_sales f
WHERE f.StoreSK IS NOT NULL
AND NOT EXISTS (
  SELECT 1 FROM sales_dwh.silver.dim_store d
  WHERE d.StoreSK = f.StoreSK
);

-- TEST 8: Amount must be positive 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: All amounts are positive'
END AS test_amount_positive
FROM sales_dwh.silver.fact_sales
WHERE Amount <= 0 OR Amount IS NULL;

-- TEST 9: Surrogate key uniqueness 

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: CustomerSK is unique in dim_customer'
END AS test_customer_sk_unique
FROM (
  SELECT CustomerSK, COUNT(*) AS cnt
  FROM sales_dwh.silver.dim_customer
  GROUP BY CustomerSK
  HAVING cnt > 1
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: ProductSK is unique in dim_product'
END AS test_product_sk_unique
FROM (
  SELECT ProductSK, COUNT(*) AS cnt
  FROM sales_dwh.silver.dim_product
  GROUP BY ProductSK
  HAVING cnt > 1
);

SELECT CASE
  WHEN COUNT(*) > 0
  THEN CAST(1/0 AS STRING)
  ELSE 'PASS: StoreSK is unique in dim_store'
END AS test_store_sk_unique
FROM (
  SELECT StoreSK, COUNT(*) AS cnt
  FROM sales_dwh.silver.dim_store
  GROUP BY StoreSK
  HAVING cnt > 1
);

SELECT 'ALL SILVER TESTS PASSED' AS final_status;