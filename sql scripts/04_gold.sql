-- ============================================================
-- SCRIPT  : 04_gold.sql
-- PURPOSE : Write final presentation tables to Gold S3 zone
-- RUN     : After 03_silver.sql completes
-- ============================================================

USE CATALOG sales_dwh;
USE SCHEMA gold;

-- ── DimCustomer Gold — active records only ───────────────────

CREATE OR REPLACE TABLE sales_dwh.gold.dim_customer
USING DELTA
LOCATION 's3://your-bucket-name/gold/dim_customer/'
AS
SELECT
  CustomerSK,
  CustomerID,
  CustomerName,
  Email,
  City,
  Address,
  StartDate,
  EndDate,
  IsActive
FROM sales_dwh.silver.dim_customer;
-- Gold keeps all records (active + expired) so history is preserved
-- Filter IsActive = 1 at query time when needed

-- ── DimProduct Gold ──────────────────────────────────────────

CREATE OR REPLACE TABLE sales_dwh.gold.dim_product
USING DELTA
LOCATION 's3://your-bucket-name/gold/dim_product/'
AS
SELECT
  ProductSK,
  ProductID,
  ProductName,
  Category,
  UnitPrice,
  EffectiveDate
FROM sales_dwh.silver.dim_product;

-- ── DimStore Gold ────────────────────────────────────────────

CREATE OR REPLACE TABLE sales_dwh.gold.dim_store
USING DELTA
LOCATION 's3://your-bucket-name/gold/dim_store/'
AS
SELECT
  StoreSK,
  StoreID,
  StoreName,
  Region
FROM sales_dwh.silver.dim_store;

-- ── FactSales Gold ───────────────────────────────────────────

CREATE OR REPLACE TABLE sales_dwh.gold.fact_sales
USING DELTA
LOCATION 's3://your-bucket-name/gold/fact_sales/'
AS
SELECT
  SalesSK,
  TransactionID,
  CustomerSK,
  ProductSK,
  StoreSK,
  Quantity,
  Amount,
  TxnDate
FROM sales_dwh.silver.fact_sales;

-- ── FINAL VALIDATION ─────────────────────────────────────────
SELECT 'dim_customer' AS table_name, COUNT(*) AS total_rows,
       SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS active_rows
FROM sales_dwh.gold.dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*), NULL FROM sales_dwh.gold.dim_product
UNION ALL
SELECT 'dim_store',   COUNT(*), NULL FROM sales_dwh.gold.dim_store
UNION ALL
SELECT 'fact_sales',  COUNT(*), NULL FROM sales_dwh.gold.fact_sales;