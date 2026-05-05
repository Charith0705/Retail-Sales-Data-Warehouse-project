USE CATALOG sales_dwh;
USE SCHEMA silver;

-- ── DimCustomer (SCD Type 2) ─────────────────────────────────

CREATE TABLE IF NOT EXISTS sales_dwh.silver.dim_customer (
  CustomerSK   BIGINT GENERATED ALWAYS AS IDENTITY,
  CustomerID   INT,
  CustomerName STRING,
  Email        STRING,
  City         STRING,
  Address      STRING,
  StartDate    DATE,
  EndDate      DATE,
  IsActive     INT
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/silver/dim_customer/';

-- Step 1: Expire old records where City or Address changed
MERGE INTO sales_dwh.silver.dim_customer AS target
USING (
  -- Deduplicate first — take the latest record per CustomerID
  SELECT
    CustomerID,
    TRIM(INITCAP(CustomerName)) AS CustomerName,
    LOWER(TRIM(Email))          AS Email,
    TRIM(City)                  AS City,
    TRIM(Address)               AS Address
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY ingested_at DESC) AS rn
    FROM sales_dwh.bronze.raw_customers
  )
  WHERE rn = 1
) AS src
INNER JOIN sales_dwh.silver.dim_customer tgt
  ON  src.CustomerID = tgt.CustomerID
  AND tgt.IsActive   = 1
WHERE
  src.City    <> tgt.City
  OR src.Address <> tgt.Address
ON target.CustomerID = src.CustomerID AND target.IsActive = 1
WHEN MATCHED THEN UPDATE SET
  target.EndDate  = current_date() - INTERVAL 1 DAY,
  target.IsActive = 0;

-- Step 2: Insert new and changed customers
INSERT INTO sales_dwh.silver.dim_customer
  (CustomerID, CustomerName, Email, City, Address, StartDate, EndDate, IsActive)
SELECT
  src.CustomerID,
  TRIM(INITCAP(src.CustomerName)) AS CustomerName,
  LOWER(TRIM(src.Email))          AS Email,
  TRIM(src.City)                  AS City,
  TRIM(src.Address)               AS Address,
  current_date()                  AS StartDate,
  TO_DATE('9999-12-31')           AS EndDate,
  1                               AS IsActive
FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY ingested_at DESC) AS rn
  FROM sales_dwh.bronze.raw_customers
) src
WHERE rn = 1
AND NOT EXISTS (
  SELECT 1
  FROM sales_dwh.silver.dim_customer tgt
  WHERE tgt.CustomerID = src.CustomerID
  AND   tgt.IsActive   = 1
);

-- ── DimProduct (Type 1) ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS sales_dwh.silver.dim_product (
  ProductSK     BIGINT GENERATED ALWAYS AS IDENTITY,
  ProductID     INT,
  ProductName   STRING,
  Category      STRING,
  UnitPrice     DECIMAL(10,2),
  EffectiveDate DATE
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/silver/dim_product/';

MERGE INTO sales_dwh.silver.dim_product AS target
USING (
  SELECT
    ProductID,
    TRIM(ProductName)                AS ProductName,
    TRIM(Category)                   AS Category,
    CAST(UnitPrice AS DECIMAL(10,2)) AS UnitPrice,
    current_date()                   AS EffectiveDate
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY ingested_at DESC) AS rn
    FROM sales_dwh.bronze.raw_products
  )
  WHERE rn = 1
) AS source
ON target.ProductID = source.ProductID
WHEN MATCHED THEN UPDATE SET
  target.ProductName   = source.ProductName,
  target.Category      = source.Category,
  target.UnitPrice     = source.UnitPrice,
  target.EffectiveDate = source.EffectiveDate
WHEN NOT MATCHED THEN INSERT
  (ProductID, ProductName, Category, UnitPrice, EffectiveDate)
VALUES
  (source.ProductID, source.ProductName, source.Category,
   source.UnitPrice, source.EffectiveDate);

-- ── DimStore (Type 1) ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sales_dwh.silver.dim_store (
  StoreSK   BIGINT GENERATED ALWAYS AS IDENTITY,
  StoreID   INT,
  StoreName STRING,
  Region    STRING
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/silver/dim_store/';

MERGE INTO sales_dwh.silver.dim_store AS target
USING (
  SELECT
    CAST(StoreID AS INT) AS StoreID,
    TRIM(StoreName)      AS StoreName,
    TRIM(Region)         AS Region
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY StoreID ORDER BY ingested_at DESC) AS rn
    FROM sales_dwh.bronze.raw_stores
  )
  WHERE rn = 1
) AS source
ON target.StoreID = source.StoreID
WHEN MATCHED THEN UPDATE SET
  target.StoreName = source.StoreName,
  target.Region    = source.Region
WHEN NOT MATCHED THEN INSERT (StoreID, StoreName, Region)
VALUES (source.StoreID, source.StoreName, source.Region);

-- ── FactSales ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sales_dwh.silver.fact_sales (
  SalesSK       BIGINT GENERATED ALWAYS AS IDENTITY,
  TransactionID INT,
  CustomerSK    BIGINT,
  ProductSK     BIGINT,
  StoreSK       BIGINT,
  Quantity      INT,
  Amount        DECIMAL(10,2),
  TxnDate       DATE
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/silver/fact_sales/';

MERGE INTO sales_dwh.silver.fact_sales AS target
USING (
  SELECT
    s.TransactionID,
    dc.CustomerSK,
    dp.ProductSK,
    ds.StoreSK,
    CAST(s.Quantity AS INT)                            AS Quantity,
    CAST(s.Quantity AS DECIMAL(10,2)) * dp.UnitPrice   AS Amount,
    TO_DATE(s.TxnDate, 'yyyy-MM-dd')                   AS TxnDate
  FROM (
    -- Deduplicate sales too
    SELECT *,
      ROW_NUMBER() OVER (PARTITION BY TransactionID ORDER BY ingested_at DESC) AS rn
    FROM sales_dwh.bronze.raw_sales
  ) s
  LEFT JOIN sales_dwh.silver.dim_customer dc
    ON  s.CustomerID = dc.CustomerID
    AND dc.IsActive  = 1
  LEFT JOIN sales_dwh.silver.dim_product dp
    ON  s.ProductID  = dp.ProductID
  LEFT JOIN sales_dwh.silver.dim_store ds
    ON  s.StoreID    = ds.StoreID
  WHERE s.rn = 1
  AND   s.TransactionID IS NOT NULL
) AS source
ON target.TransactionID = source.TransactionID
WHEN NOT MATCHED THEN INSERT
  (TransactionID, CustomerSK, ProductSK, StoreSK, Quantity, Amount, TxnDate)
VALUES
  (source.TransactionID, source.CustomerSK, source.ProductSK,
   source.StoreSK, source.Quantity, source.Amount, source.TxnDate);

-- ── VALIDATION ───────────────────────────────────────────────
SELECT 'dim_customer' AS table_name, COUNT(*) AS total_rows,
       SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS active_records
FROM sales_dwh.silver.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*), NULL FROM sales_dwh.silver.dim_product
UNION ALL
SELECT 'dim_store',   COUNT(*), NULL FROM sales_dwh.silver.dim_store
UNION ALL
SELECT 'fact_sales',  COUNT(*), NULL FROM sales_dwh.silver.fact_sales;