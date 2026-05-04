USE CATALOG sales_dwh;
USE SCHEMA bronze;

-- customers
CREATE TABLE IF NOT EXISTS bronze.raw_customers
USING DELTA
LOCATION 's3://your-bucket/bronze/customers/'
AS
SELECT
  *,
  current_timestamp() AS ingested_at,
  'initial'           AS load_type
FROM read_files(
  's3://your-bucket/sftp-landing/customers_src*.csv',
  format      => 'csv',
  header      => 'true',
  inferSchema => 'true'
);

MERGE INTO bronze.raw_customers AS target
USING (
  SELECT
    *,
    current_timestamp() AS ingested_at,
    'incremental'       AS load_type
  FROM read_files(
    's3://your-bucket/sftp-landing/customers_src*.csv',
    format      => 'csv',
    header      => 'true',
    inferSchema => 'true'
  )
) AS source
ON target.customer_id = source.customer_id
WHEN NOT MATCHED THEN INSERT *;

-- products
CREATE TABLE IF NOT EXISTS bronze.raw_products
USING DELTA
LOCATION 's3://your-bucket/bronze/products/'
AS
SELECT
  *,
  current_timestamp() AS ingested_at,
  'initial'           AS load_type
FROM read_files(
  's3://your-bucket/sftp-landing/products_src*.csv',
  format => 'csv', header => 'true', inferSchema => 'true'
);

MERGE INTO bronze.raw_products AS target
USING (
  SELECT *, current_timestamp() AS ingested_at, 'incremental' AS load_type
  FROM read_files(
    's3://your-bucket/sftp-landing/products_src*.csv',
    format => 'csv', header => 'true', inferSchema => 'true'
  )
) AS source
ON target.product_id = source.product_id
WHEN NOT MATCHED THEN INSERT *;


-- stores
CREATE TABLE IF NOT EXISTS bronze.raw_stores
USING DELTA
LOCATION 's3://your-bucket/bronze/stores/'
AS
SELECT
  *,
  current_timestamp() AS ingested_at,
  'initial'           AS load_type
FROM read_files(
  's3://your-bucket/sftp-landing/stores_src*.csv',
  format => 'csv', header => 'true', inferSchema => 'true'
);

MERGE INTO bronze.raw_stores AS target
USING (
  SELECT *, current_timestamp() AS ingested_at, 'incremental' AS load_type
  FROM read_files(
    's3://your-bucket/sftp-landing/stores_src*.csv',
    format => 'csv', header => 'true', inferSchema => 'true'
  )
) AS source
ON target.store_id = source.store_id
WHEN NOT MATCHED THEN INSERT *;

-- sales
CREATE TABLE IF NOT EXISTS bronze.raw_sales
USING DELTA
LOCATION 's3://your-bucket/bronze/sales/'
AS
SELECT
  *,
  current_timestamp() AS ingested_at,
  'initial'           AS load_type
FROM read_files(
  's3://your-bucket/sftp-landing/sales_transactions_src*.csv',
  format => 'csv', header => 'true', inferSchema => 'true'
);

MERGE INTO bronze.raw_sales AS target
USING (
  SELECT *, current_timestamp() AS ingested_at, 'incremental' AS load_type
  FROM read_files(
    's3://your-bucket/sftp-landing/sales_transactions_src*.csv',
    format => 'csv', header => 'true', inferSchema => 'true'
  )
) AS source
ON target.transaction_id = source.transaction_id
WHEN NOT MATCHED THEN INSERT *;