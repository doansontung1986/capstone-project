"""Bước 4: Chuẩn bị dữ liệu cho Power BI (star schema) + bảng số liệu đối chiếu.

Chạy từ thư mục capstone-project, sau khi đã chạy notebook 01 và 03:
    .venv/bin/python powerbi/prepare_powerbi_data.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "output"
PBI_DIR = ROOT / "powerbi" / "data"
PBI_DIR.mkdir(parents=True, exist_ok=True)

# utf-8-sig: Power BI / Excel trên Windows đọc đúng dấu tiếng Bồ Đào Nha
def save(df: pd.DataFrame, name: str) -> None:
    df.to_csv(PBI_DIR / name, index=False, encoding="utf-8-sig")
    print(f"  {name:<28} {len(df):>7,} rows")


# ---------- fact_delivery: 1 dòng / order trong phạm vi phân tích ----------
df = pd.read_csv(OUT_DIR / "fact_orders_clean.csv", low_memory=False,
                 parse_dates=["order_purchase_timestamp"])
df = df[df["in_scope"] == 1].copy()

bucket_order = {"Early >7d": 1, "Early/On time (0-7d)": 2, "Late 1-3d": 3,
                "Late 4-7d": 4, "Late >7d": 5}
distance_labels = ["<100", "100-300", "300-600", "600-1000", "1000-2000", ">2000"]

df["purchase_date"] = df["order_purchase_timestamp"].dt.date
df["delay_bucket_order"] = df["delay_bucket"].map(bucket_order)
df["distance_bin"] = pd.cut(df["distance_km"], [0, 100, 300, 600, 1000, 2000, np.inf],
                            labels=distance_labels, include_lowest=True).astype(str)
df.loc[df["distance_km"].isna(), "distance_bin"] = "unknown"
df["distance_bin_order"] = df["distance_bin"].map(
    {label: i for i, label in enumerate(distance_labels + ["unknown"], start=1)})
df["seller_type"] = np.where(df["n_sellers"] >= 2, "Multi-seller", "Single seller")

fact_cols = [
    "order_id", "purchase_date", "customer_state", "customer_city", "seller_state",
    "main_category", "payment_type", "seller_type", "n_items", "n_sellers",
    "total_price", "total_freight", "payment_value", "freight_ratio",
    "delivery_days", "estimated_days", "handling_days", "delay_days", "is_late",
    "delay_bucket", "delay_bucket_order", "distance_km", "distance_bin",
    "distance_bin_order", "same_state", "review_score", "bad_review", "has_comment",
]
fact = df[fact_cols].round(4)
for c in ["is_late", "bad_review", "same_state", "n_items", "n_sellers", "review_score", "delay_days"]:
    fact[c] = fact[c].astype("Int64")

# ---------- dim_date ----------
dates = pd.date_range(df["order_purchase_timestamp"].min().normalize(),
                      df["order_purchase_timestamp"].max().normalize(), freq="D")
dim_date = pd.DataFrame({
    "date"      : dates.date,
    "year"      : dates.year,
    "quarter"   : "Q" + dates.quarter.astype(str),
    "month"     : dates.month,
    "month_name": dates.strftime("%b"),
    "year_month": dates.strftime("%Y-%m"),
})

# ---------- dim_state: 27 bang Brazil (location dùng cho visual Map) ----------
states = [
    ("AC", "Acre", "Norte"), ("AL", "Alagoas", "Nordeste"), ("AP", "Amapá", "Norte"),
    ("AM", "Amazonas", "Norte"), ("BA", "Bahia", "Nordeste"), ("CE", "Ceará", "Nordeste"),
    ("DF", "Distrito Federal", "Centro-Oeste"), ("ES", "Espírito Santo", "Sudeste"),
    ("GO", "Goiás", "Centro-Oeste"), ("MA", "Maranhão", "Nordeste"),
    ("MT", "Mato Grosso", "Centro-Oeste"), ("MS", "Mato Grosso do Sul", "Centro-Oeste"),
    ("MG", "Minas Gerais", "Sudeste"), ("PA", "Pará", "Norte"), ("PB", "Paraíba", "Nordeste"),
    ("PR", "Paraná", "Sul"), ("PE", "Pernambuco", "Nordeste"), ("PI", "Piauí", "Nordeste"),
    ("RJ", "Rio de Janeiro", "Sudeste"), ("RN", "Rio Grande do Norte", "Nordeste"),
    ("RS", "Rio Grande do Sul", "Sul"), ("RO", "Rondônia", "Norte"), ("RR", "Roraima", "Norte"),
    ("SC", "Santa Catarina", "Sul"), ("SP", "São Paulo", "Sudeste"),
    ("SE", "Sergipe", "Nordeste"), ("TO", "Tocantins", "Norte"),
]
dim_state = pd.DataFrame(states, columns=["state_code", "state_name", "region"])
dim_state["location"] = dim_state["state_name"] + ", Brazil"

missing = set(fact["customer_state"]) - set(dim_state["state_code"])
assert not missing, f"State không có trong dim_state: {missing}"

print("Ghi file vào", PBI_DIR)
save(fact, "fact_delivery.csv")
save(dim_date, "dim_date.csv")
save(dim_state, "dim_state.csv")
for name in ["what_if_reduction", "what_if_delay_curve", "what_if_scenarios",
             "model_metrics", "model_coefficients"]:
    save(pd.read_csv(OUT_DIR / f"{name}.csv"), f"{name}.csv")

# ---------- Số liệu đối chiếu: KPI trên Power BI phải khớp bảng này ----------
late = df["is_late"] == 1
checks = [
    ("Orders", len(df)),
    ("Revenue (BRL)", df["payment_value"].sum()),
    ("Late Rate", df["is_late"].mean()),
    ("Avg Review", df["review_score"].mean()),
    ("Bad Review Rate", df["bad_review"].mean()),
    ("Avg Delivery Days", df["delivery_days"].mean()),
    ("Avg Review - Late", df.loc[late, "review_score"].mean()),
    ("Avg Review - On time", df.loc[~late, "review_score"].mean()),
    ("Bad Review Rate - Late", df.loc[late, "bad_review"].mean()),
    ("Bad Review Rate - On time", df.loc[~late, "bad_review"].mean()),
    ("Late Rate 2017-11", df.loc[df["year_month"] == "2017-11", "is_late"].mean()),
    ("Late Rate 2018-03", df.loc[df["year_month"] == "2018-03", "is_late"].mean()),
    ("Late Rate AL", df.loc[df["customer_state"] == "AL", "is_late"].mean()),
    ("Late Rate SP", df.loc[df["customer_state"] == "SP", "is_late"].mean()),
    ("Bad Review Rate Multi-seller", df.loc[df["n_sellers"] >= 2, "bad_review"].mean()),
]
kpi = pd.DataFrame(checks, columns=["measure", "expected_value"])
kpi["expected_value"] = kpi["expected_value"].round(4)
save(kpi, "kpi_checklist.csv")
print()
print(kpi.to_string(index=False))
