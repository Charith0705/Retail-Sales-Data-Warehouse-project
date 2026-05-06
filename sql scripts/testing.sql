USE CATALOG sales_dwh;


SELECT TransactionID, COUNT(*) AS cnt
  FROM sales_dwh.bronze.raw_sales
  GROUP BY TransactionID
  HAVING cnt > 1;