# Blinkit Business Intelligence & Customer Analytics Dashboard

**An end-to-end BI project built on Blinkit's sales, customer, delivery, and marketing data — from messy raw exports to decision-ready dashboards.**

---

## 1. The Problem

Blinkit sits on a pile of operational data — orders, deliveries, feedback, inventory, marketing spend — but that data was scattered across eight disconnected CSV exports, none of which spoke to each other. Two of the inventory feeds didn't even agree on a date format. Nobody could answer a simple question like *"which delivery partners are actually missing SLAs, and is that hurting our ratings?"* without pulling three spreadsheets together by hand.

The goal of this project was to turn that mess into a proper analytics stack: a clean data model, a queryable warehouse, and a set of dashboards that a category manager or ops lead could actually use every week.

## 2. The Data

Eight raw sources, ~110K rows combined:

| Source | Rows | What it holds |
|---|---|---|
| `blinkit_orders.csv` | 5,000 | Order-level transactions, timestamps, delivery status |
| `blinkit_order_items.csv` | 5,000 | Line items per order |
| `blinkit_customers.csv` | 2,500 | Customer profile, segment, address |
| `blinkit_products.csv` | 268 | SKU catalog, category, margin |
| `blinkit_delivery_performance.csv` | 5,000 | Promised vs. actual delivery times |
| `blinkit_customer_feedback.csv` | 5,000 | Ratings, sentiment, free-text feedback |
| `blinkit_marketing_performance.csv` | 5,400 | Campaign spend, clicks, conversions |
| `blinkit_inventory.csv` + `blinkit_inventoryNew.csv` | 75,172 + 18,105 | Two overlapping stock-received/damaged feeds |

The two inventory files were the messiest part of the project — one used `DD-MM-YYYY`, the other used `Mon-YY`, and the "new" feed had **7,359 exact duplicate rows** baked in. Reconciling those into a single trustworthy stock table was step one of the cleaning pipeline.

## 3. What I Built

### a) Data cleaning & feature engineering (Python / Pandas)
- Standardised every date column, de-duplicated all eight tables, and reconciled the two inventory feeds into one `inventory_reconciled` table with a `source_feed` flag for traceability.
- Engineered analytical fields that don't exist in the raw exports: delivery **delay-in-minutes**, RFM inputs (**recency / frequency / monetary**) per customer, per-line **margin value**, damage-rate %, CTR and conversion-rate for every marketing campaign.
- Script: [`01_data_cleaning_feature_engineering.py`](computer:///mnt/user-data/outputs/01_data_cleaning_feature_engineering.py)

### b) Data warehouse (MySQL)
- Designed a normalized star-ish schema — `customers`, `products`, `orders`, `order_items`, `delivery_performance`, `customer_feedback`, `marketing_performance`, `inventory_reconciled` — with foreign keys tying everything back to `orders` and `products`, plus indexes on the columns the dashboards filter by most (order date, customer, sentiment, product/date on inventory).
- Schema: [`01_schema.sql`](computer:///mnt/user-data/outputs/01_schema.sql)

### c) Advanced SQL analysis
Seven analytical queries that go beyond basic aggregation:
- **Monthly revenue trend with MoM growth** (`LAG` window function)
- **RFM customer segmentation** (`NTILE` quartile scoring → Champions / Loyal / At Risk / Dormant)
- **Delivery-partner SLA scorecard** (on-time % per partner, filtered to partners with meaningful volume)
- **Top-3 products per category** (`RANK() OVER PARTITION BY`)
- **Marketing channel ROI** (blended ROAS, conversion rate by channel)
- **Inventory damage-rate leaderboard** (reconciled feed)
- **Delivery delay vs. customer rating** correlation
- Queries: [`02_advanced_analysis_queries.sql`](computer:///mnt/user-data/outputs/02_advanced_analysis_queries.sql)

### d) Interactive KPI dashboard
Since I couldn't attach a live `.pbix`/`.twbx` file here, the same cleaned data model and the same KPI logic that would drive the Power BI / Tableau dashboards is rendered as a live, clickable web dashboard — same numbers, same charts, tab-based navigation across Sales, Customers, Delivery, Products, and Marketing.
👉 **[Open the live dashboard](https://claude.ai/artifact/Pq6kJveTiMQuar4USEGVHa)**

## 4. What the Numbers Say

- **₹1.1 Cr** in total revenue across 5,000 orders (₹2,202 AOV), Mar 2023 – Nov 2024.
- **Delivery is the weak link**: only **69.4%** of orders arrive on time; 493 are "significantly delayed." Interestingly, average rating barely moves between on-time (3.33) and delayed (3.37) orders — so late delivery alone isn't the main driver of dissatisfaction; feedback data splits nearly evenly across Delivery, Customer Service, Product Quality, and App Experience complaints, meaning the fix has to be cross-functional, not just logistics.
- **Customer base is evenly split** across Premium, Regular, New, and Inactive (~25% each) — but RFM scoring shows **735 "Loyal" and 606 "Champion"** customers already exist and are being under-served by a one-size-fits-all retention strategy.
- **Dairy & Breakfast, Pharmacy, and Fruits & Vegetables** are the top three revenue categories; Vitamins and Pet Treats are the single highest-revenue SKUs.
- **Email edges out App and Social as the most efficient acquisition channel** (2.05x ROAS vs. ~1.9x elsewhere), despite getting a smaller share of the ₹1.63 Cr total ad spend.

## 5. Tech Stack

`Python (Pandas, NumPy)` for cleaning & feature engineering · `MySQL` for the warehouse & advanced SQL · `Power BI` / `Tableau` for the executive dashboards (mirrored here as an interactive web dashboard) · category icons and rating-emoji lookup tables supplied for the Power BI visual layer.

## 6. Repo Structure

```
blinkit_project/
├── data_cleaned/               # cleaned, feature-engineered CSVs
├── sql/
│   ├── 01_schema.sql           # MySQL warehouse DDL
│   └── 02_advanced_analysis_queries.sql
├── scripts/
│   └── 01_data_cleaning_feature_engineering.py
└── kpi_data.json               # KPI values powering the dashboard
```
