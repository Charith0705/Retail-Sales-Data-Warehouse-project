USE CATALOG sales_dwh;
USE SCHEMA bronze;

-- ── CUSTOMERS 

CREATE TABLE IF NOT EXISTS sales_dwh.bronze.raw_customers (
  CustomerID   INT,
  CustomerName STRING,
  Email        STRING,
  City         STRING,
  Address      STRING,
  LastUpdated  STRING,
  ingested_at  TIMESTAMP
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/bronze/customers/';

MERGE INTO sales_dwh.bronze.raw_customers AS target
USING (
  SELECT
    CAST(CustomerID AS INT) AS CustomerID,
    CustomerName,
    Email,
    City,
    Address,
    LastUpdated,
    current_timestamp() AS ingested_at
  FROM read_files(
    's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/sftp-landing/customers_src*.csv',
    format      => 'csv',
    header      => 'true',
    inferSchema => 'true'
  )
) AS source
ON target.CustomerID = source.CustomerID
WHEN NOT MATCHED THEN INSERT *;

-- ── PRODUCTS 

CREATE TABLE IF NOT EXISTS sales_dwh.bronze.raw_products (
  ProductID   INT,
  ProductName STRING,
  Category    STRING,
  UnitPrice   DECIMAL(10,2),
  ingested_at TIMESTAMP
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/bronze/products/';

MERGE INTO sales_dwh.bronze.raw_products AS target
USING (
  SELECT
    CAST(ProductID AS INT) AS ProductID,
    ProductName,
    Category,
    CAST(UnitPrice AS DECIMAL(10,2)) AS UnitPrice,
    current_timestamp() AS ingested_at
  FROM read_files(
    's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/sftp-landing/products_src*.csv',
    format      => 'csv',
    header      => 'true',
    inferSchema => 'true'
  )
) AS source
ON target.ProductID = source.ProductID
WHEN NOT MATCHED THEN INSERT *;

-- ── STORES 

CREATE TABLE IF NOT EXISTS sales_dwh.bronze.raw_stores (
  StoreID     INT,
  StoreName   STRING,
  Region      STRING,
  ingested_at TIMESTAMP
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/bronze/stores/';

MERGE INTO sales_dwh.bronze.raw_stores AS target
USING (
  SELECT
    CAST(StoreID AS INT) AS StoreID,
    StoreName,
    Region,
    current_timestamp()  AS ingested_at
  FROM read_files(
    's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/sftp-landing/stores_src*.csv',
    format      => 'csv',
    header      => 'true',
    inferSchema => 'true'
  )
) AS source
ON target.StoreID = source.StoreID
WHEN NOT MATCHED THEN INSERT *;

-- ── SALES 

CREATE TABLE IF NOT EXISTS sales_dwh.bronze.raw_sales (
  TransactionID INT,
  CustomerID    INT,
  ProductID     INT,
  StoreID       INT,
  Quantity      INT,
  TxnDate       STRING,
  ingested_at   TIMESTAMP
)
USING DELTA
LOCATION 's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/bronze/sales/';

MERGE INTO sales_dwh.bronze.raw_sales AS target
USING (
  SELECT
    CAST(TransactionID AS INT) AS TransactionID,
    CAST(CustomerID    AS INT) AS CustomerID,
    CAST(ProductID     AS INT) AS ProductID,
    CAST(StoreID       AS INT) AS StoreID,
    CAST(Quantity      AS INT) AS Quantity,
    TxnDate,
    current_timestamp() AS ingested_at
  FROM read_files(
    's3://sales-dwh-bucket-charith-977574653589-us-east-2-an/sftp-landing/sales_transactions_src*.csv',
    format      => 'csv',
    header      => 'true',
    inferSchema => 'true'
  )
) AS source
ON target.TransactionID = source.TransactionID
WHEN NOT MATCHED THEN INSERT *;

-- ── VALIDATION ──────────────────────────────────────────────────
SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count
FROM sales_dwh.bronze.raw_customers
UNION ALL

SELECT 'raw_products', COUNT(*) 
FROM sales_dwh.bronze.raw_products
UNION ALL

SELECT 'raw_stores', COUNT(*) 
FROM sales_dwh.bronze.raw_stores
UNION ALL

SELECT 'raw_sales', COUNT(*)
FROM sales_dwh.bronze.raw_sales;