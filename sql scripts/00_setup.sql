CREATE CATALOG IF NOT EXISTS sales_dwh;

USE CATALOG sales_dwh;

CREATE SCHEMA IF NOT EXISTS sales_dwh.bronze;

CREATE SCHEMA IF NOT EXISTS sales_dwh.silver;

CREATE SCHEMA IF NOT EXISTS sales_dwh.gold;

SHOW SCHEMAS IN sales_dwh;

drop table if exists sales_dwh.bronze.raw_customers;
drop table if exists sales_dwh.bronze.raw_products;
drop table if exists sales_dwh.bronze.raw_stores;
drop table if exists sales_dwh.bronze.raw_sales ;
drop table if exists sales_dwh.silver.dim_customer;
drop table if exists sales_dwh.silver.dim_product;
drop table if exists sales_dwh.silver.dim_store;
drop table if exists sales_dwh.silver.fact_sales;
drop table if exists sales_dwh.gold.dim_customer;
drop table if exists sales_dwh.gold.dim_product;
drop table if exists sales_dwh.gold.dim_store;
drop table if exists sales_dwh.gold.fact_sales;