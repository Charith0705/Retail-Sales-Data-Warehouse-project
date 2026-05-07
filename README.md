# Retail Sales Data Warehouse — ETL & Data Quality Validation

A production-style ETL pipeline built on **Databricks SQL**, **AWS S3**, and **GitHub Actions CI/CD**.  
Implements a full **Medallion Architecture** (Bronze → Silver → Gold) with automated testing gates,  
SCD Type 2 dimension handling, and a file archival mechanism across all pipeline zones.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Pipeline Flow](#pipeline-flow)
- [Data Model](#data-model)
- [Archival Mechanism](#archival-mechanism)
- [Testing Strategy](#testing-strategy)
- [CI/CD Setup](#cicd-setup)
- [How to Run](#how-to-run)
- [Environment Configuration](#environment-configuration)

---

## Architecture Overview

```
Source CSVs (SFTP Landing)
        │
        ▼
┌──────────────────┐
│  01_archival.py  │  ← Archives old files, keeps latest per source per zone
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  Bronze Layer    │  ← Raw ingestion — CSVs → Delta tables in S3
│  02_bronze.sql   │
└──────────────────┘
        │
┌──────────────────┐
│  02_bronze_test  │  ← Gate 1: stops pipeline if Bronze checks fail
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  Silver Layer    │  ← Transform, SCD2, derive amounts, load dims + facts
│  03_silver.sql   │
└──────────────────┘
        │
┌──────────────────┐
│  03_silver_test  │  ← Gate 2: stops pipeline if Silver checks fail
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  Gold Layer      │  ← Final presentation tables written to S3 Gold zone
│  04_gold.sql     │
└──────────────────┘
        │
┌──────────────────┐
│  04_gold_test    │  ← Gate 3: stops pipeline if Gold checks fail
└──────────────────┘
```

---

## Tech Stack

| Component       | Technology                              |
|-----------------|-----------------------------------------|
| ETL Engine      | Databricks SQL (Serverless Warehouse)   |
| Storage         | AWS S3 (us-east-2)                      |
| Table Format    | Delta Lake (Parquet)                    |
| Catalog         | Unity Catalog                           |
| Archival Script | Python (dbutils.fs)                     |
| CI/CD           | GitHub Actions                          |
| Architecture    | Medallion (Bronze / Silver / Gold)      |
| Source Format   | CSV with naming: `<name>_DDMMYYYYHHMMSS.csv` |

---

## Project Structure

```
├── scripts/
│   ├── 00_setup.sql            # One-time catalog and schema creation
│   ├── 01_archival.py          # File archival across SFTP, Bronze, Silver zones
│   ├── 02_bronze.sql           # Raw ingestion from S3 sftp-landing into Bronze Delta tables
│   ├── 03_bronze_test.sql      # Bronze validation gate — stops pipeline on failure
│   ├── 04_silver.sql           # Transform, SCD2, derive amounts, dimension and fact loads
│   ├── 05_silver_test.sql      # Silver validation gate — stops pipeline on failure
│   ├── 06_gold.sql             # Final Gold layer tables written to S3
│   └── 07_gold_test.sql        # Gold validation gate — stops pipeline on failure
├── docs/
│   └── ETL_Testing_Documentation.docx   # Full test plan, test cases, defect log
└── README.md
```

---

## Pipeline Flow

### Day 1 — Full Load

1. Upload 4 source CSV files to `s3://bucket/sftp-landing/` with timestamp in filename
2. Archival script runs — detects single files, no archival needed
3. Bronze ingests all 4 CSVs into Delta tables
4. Bronze test gate validates row counts, null PKs, duplicates
5. Silver creates `dim_customer`, `dim_product`, `dim_store`, `fact_sales`
6. Silver test gate validates SCD2 logic, FK integrity, amount calculation
7. Gold copies final tables from Silver to Gold S3 zone

### Day 2 — Incremental Load

1. Upload new CSV files with updated timestamp to `s3://bucket/sftp-landing/`
2. Archival script detects 2 files per source — moves older file to `archive/sftp/`
3. Bronze MERGE updates changed records, inserts new ones
4. Silver SCD2 expires changed customer records, inserts new active rows
5. Gold refreshed with latest state

---

## Data Model

```
                    ┌─────────────────┐
                    │  DimCustomer    │
                    │  (SCD Type 2)   │
                    │  CustomerSK  PK │
                    │  CustomerID  NK │
                    │  StartDate      │
                    │  EndDate        │
                    │  IsActive       │
                    └────────┬────────┘
                             │
┌──────────────┐    ┌────────▼────────┐    ┌─────────────┐
│  DimProduct  │    │   FactSales     │    │  DimStore   │
│  ProductSK PK│───►│  CustomerSK  FK │◄───│  StoreSK PK │
│  ProductID NK│    │  ProductSK   FK │    │  StoreID  NK│
│  UnitPrice   │    │  StoreSK     FK │    │  StoreName  │
└──────────────┘    │  Quantity       │    │  Region     │
                    │  Amount         │    └─────────────┘
                    │  TxnDate        │
                    └─────────────────┘
```

### Transformation Rules

| Column        | Rule                                      |
|---------------|-------------------------------------------|
| CustomerName  | `TRIM(INITCAP(CustomerName))`             |
| Email         | `LOWER(TRIM(Email))`                      |
| StoreName     | `TRIM(StoreName)`                         |
| ProductName   | `TRIM(ProductName)`                       |
| Amount        | `Quantity × UnitPrice` from DimProduct    |
| TxnDate       | `TO_DATE(TxnDate, 'dd-MM-yyyy')`          |

### SCD Type 2 Logic for DimCustomer

- **Trigger columns:** `City` and `Address`
- When either changes: old record gets `IsActive = 0`, `EndDate = today - 1`
- New record inserted with `IsActive = 1`, `StartDate = today`, `EndDate = 9999-12-31`
- FactSales always joins on `IsActive = 1` to resolve the current surrogate key

---

## Archival Mechanism

Source files follow the naming convention:
```
customers_src_DDMMYYYYHHMMSS.csv
```

The archival script (`01_archival.py`) runs **before** the Bronze notebook on every pipeline execution:

1. Lists all files in each zone (`sftp-landing/`, `bronze/`, `silver/`)
2. Parses the `DDMMYYYYHHMMSS` timestamp from each filename using regex
3. Identifies the latest file per source by timestamp
4. Moves all older files to the corresponding archive folder
5. Validates that exactly 1 file remains per source per zone
6. **Raises an exception and stops the pipeline** if validation fails

Archive folder structure:
```
s3://bucket/archive/sftp/customers/
s3://bucket/archive/bronze/customers/
s3://bucket/archive/silver/customers/
```

---

## Testing Strategy

Each layer has a dedicated test script that runs as the next task in the Databricks Workflow.

### Bronze Tests
- Row count > 0 for all 4 tables
- No duplicate primary keys
- `ingested_at` not null

### Silver Tests
- No null surrogate keys
- No duplicate active records per CustomerID
- SCD2 date continuity — `EndDate = StartDate - 1`
- Every expired record has a corresponding active record
- No nulls on critical columns
- Amount = `Quantity × UnitPrice` within 0.01 tolerance
- Referential integrity — all SKs in FactSales exist in dimension tables
- Surrogate key uniqueness across all dims

### Gold Tests
- Row counts match Silver exactly
- No null surrogate keys in FactSales
- Active customer count matches Silver
- All amounts are positive
- TxnDate within valid range (2020-01-01 to today)
- No orphan records in FactSales

---

## CI/CD Setup

GitHub Actions automatically deploys updated notebooks to Databricks whenever code is pushed to the `main` branch.

```
Push to main branch
        │
        ▼
GitHub Actions workflow triggers
        │
        ▼
Notebooks deployed to Databricks workspace
        │
        ▼
Databricks Workflow runs scripts sequentially
```

Required GitHub Secrets:
```
DATABRICKS_HOST        # your Databricks workspace URL
DATABRICKS_TOKEN       # personal access token from Databricks settings
```

---

## How to Run

### First Time Setup

```sql
-- Run 00_setup.sql once in Databricks SQL editor
CREATE CATALOG IF NOT EXISTS sales_dwh;
CREATE SCHEMA IF NOT EXISTS sales_dwh.bronze;
CREATE SCHEMA IF NOT EXISTS sales_dwh.silver;
CREATE SCHEMA IF NOT EXISTS sales_dwh.gold;
```

### Upload Source Files

Upload your 4 CSV files to S3 with the correct naming convention:
```
s3://your-bucket/sftp-landing/customers_src_DDMMYYYYHHMMSS.csv
s3://your-bucket/sftp-landing/products_src_DDMMYYYYHHMMSS.csv
s3://your-bucket/sftp-landing/stores_src_DDMMYYYYHHMMSS.csv
s3://your-bucket/sftp-landing/sales_transactions_src_DDMMYYYYHHMMSS.csv
```

### Run the Pipeline

Trigger the Databricks Workflow at everyday 5:30AM automatically with trigger scheduling.  
The workflow runs all 7 tasks in order and stops automatically if any test gate fails.

---
### S3 Folder Structure Required
```
s3://your-bucket/
├── sftp-landing/
├── bronze/
├── silver/
├── gold/
└── archive/
    ├── sftp/
    ├── bronze/
    └── silver/
```
