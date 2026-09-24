"""
Blinkit BI Project — Data Cleaning & Feature Engineering
---------------------------------------------------------
Reconciles the two inventory feeds, standardises dates, removes duplicates,
and engineers the analytical fields (delivery delay flags, RFM inputs,
margin values, customer lifetime metrics) that feed the MySQL warehouse
and the Power BI / Tableau dashboards.

Run: python 01_data_cleaning_feature_engineering.py
"""

import pandas as pd
import numpy as np
from pathlib import Path

RAW = Path("/mnt/user-data/uploads")
OUT = Path("/home/claude/blinkit_project/data_cleaned")
OUT.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------
# 1. ORDERS + DELIVERY  →  cleaned, typed, delay-flagged
# ---------------------------------------------------------------------
orders = pd.read_csv(RAW / "blinkit_orders.csv",
                      parse_dates=["order_date", "promised_delivery_time", "actual_delivery_time"])
delivery = pd.read_csv(RAW / "blinkit_delivery_performance.csv",
                        parse_dates=["promised_time", "actual_time"])

orders = orders.drop_duplicates(subset="order_id")
delivery = delivery.drop_duplicates(subset="order_id")

orders["delay_minutes"] = (orders["actual_delivery_time"] - orders["promised_delivery_time"]).dt.total_seconds() / 60
orders["is_delayed"] = orders["delay_minutes"] > 0
orders["order_hour"] = orders["order_date"].dt.hour
orders["order_weekday"] = orders["order_date"].dt.day_name()
orders["order_month"] = orders["order_date"].dt.to_period("M").astype(str)

orders.to_csv(OUT / "orders_clean.csv", index=False)
delivery.to_csv(OUT / "delivery_clean.csv", index=False)

# ---------------------------------------------------------------------
# 2. CUSTOMERS  →  RFM-style features + tenure
# ---------------------------------------------------------------------
customers = pd.read_csv(RAW / "blinkit_customers.csv", parse_dates=["registration_date"])
customers = customers.drop_duplicates(subset="customer_id")

last_order = orders.groupby("customer_id")["order_date"].max().rename("last_order_date")
order_freq = orders.groupby("customer_id")["order_id"].count().rename("orders_in_data")
order_value = orders.groupby("customer_id")["order_total"].sum().rename("total_spend")

customers = customers.merge(last_order, on="customer_id", how="left") \
                      .merge(order_freq, on="customer_id", how="left") \
                      .merge(order_value, on="customer_id", how="left")

snapshot_date = orders["order_date"].max()
customers["recency_days"] = (snapshot_date - customers["last_order_date"]).dt.days
customers["tenure_days"] = (snapshot_date - customers["registration_date"]).dt.days
customers[["orders_in_data", "total_spend"]] = customers[["orders_in_data", "total_spend"]].fillna(0)

customers.to_csv(OUT / "customers_clean.csv", index=False)

# ---------------------------------------------------------------------
# 3. PRODUCTS + ORDER ITEMS  →  category revenue, margin ₹ value
# ---------------------------------------------------------------------
products = pd.read_csv(RAW / "blinkit_products.csv").drop_duplicates(subset="product_id")
items = pd.read_csv(RAW / "blinkit_order_items.csv")

items = items.merge(products, on="product_id", how="left")
items["line_revenue"] = items["quantity"] * items["unit_price"]
items["line_margin_value"] = items["line_revenue"] * (items["margin_percentage"] / 100)

items.to_csv(OUT / "order_items_enriched.csv", index=False)
products.to_csv(OUT / "products_clean.csv", index=False)

# ---------------------------------------------------------------------
# 4. INVENTORY  →  reconcile TWO source feeds (different date grains,
#    ~7.3K duplicate rows in the "New" feed) into one daily-stock table
# ---------------------------------------------------------------------
inv_daily = pd.read_csv(RAW / "blinkit_inventory.csv")
inv_monthly_raw = pd.read_csv(RAW / "blinkit_inventoryNew.csv")

inv_daily["date"] = pd.to_datetime(inv_daily["date"], format="%d-%m-%Y")
inv_monthly_raw = inv_monthly_raw.drop_duplicates()  # strips the duplicate rows
inv_monthly_raw["date"] = pd.to_datetime(inv_monthly_raw["date"], format="%b-%y")

inv_daily["source"] = "daily_feed"
inv_monthly_raw["source"] = "monthly_feed"

inventory = pd.concat([inv_daily, inv_monthly_raw], ignore_index=True)
inventory["damage_rate_pct"] = np.where(
    inventory["stock_received"] > 0,
    (inventory["damaged_stock"] / inventory["stock_received"]) * 100,
    0
)
inventory.to_csv(OUT / "inventory_reconciled.csv", index=False)

# ---------------------------------------------------------------------
# 5. FEEDBACK & MARKETING  →  light typing / de-dup only
# ---------------------------------------------------------------------
feedback = pd.read_csv(RAW / "blinkit_customer_feedback.csv", parse_dates=["feedback_date"]).drop_duplicates("feedback_id")
marketing = pd.read_csv(RAW / "blinkit_marketing_performance.csv", parse_dates=["date"]).drop_duplicates("campaign_id")
marketing["ctr_pct"] = (marketing["clicks"] / marketing["impressions"]) * 100
marketing["conversion_rate_pct"] = (marketing["conversions"] / marketing["clicks"]) * 100

feedback.to_csv(OUT / "feedback_clean.csv", index=False)
marketing.to_csv(OUT / "marketing_clean.csv", index=False)

print("Cleaning complete.")
print(f"Inventory: {len(inv_daily)} daily rows + {len(inv_monthly_raw)} monthly rows "
      f"(deduped from {pd.read_csv(RAW / 'blinkit_inventoryNew.csv').shape[0]}) → {len(inventory)} reconciled rows")
print(f"Orders: {len(orders)} | Customers: {len(customers)} | Order items: {len(items)}")
