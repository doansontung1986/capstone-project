# Đồ án cuối khoá DA Advanced — Olist: Giao hàng → Review

Bài toán: hiệu suất giao hàng ảnh hưởng thế nào đến điểm review, và nếu cải thiện giao hàng thì review xấu giảm bao nhiêu.

## Chạy lại từ đầu
```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# MySQL (user/password trong utils/config.py)
mysql -uroot -p -e "SET GLOBAL local_infile = 1;"
mysql -uroot -p < sql/01_create_schema.sql
# Phải chạy từ thư mục capstone-project (đường dẫn CSV là tương đối: dataset/...)
mysql --local-infile=1 -uroot -p < sql/02_load_data.sql   # in số dòng để đối chiếu
mysql -uroot -p < sql/03_build_mart.sql                   # tạo fact_orders

# Notebook (chạy theo thứ tự, từ thư mục notebooks/)
.venv/bin/jupyter lab notebooks/
```

| Bước | File | Output |
|---|---|---|
| 1. Đọc dữ liệu | `sql/01..03_*.sql` | DB `olist`, bảng `fact_orders` |
| 2. Xử lý dữ liệu | `notebooks/01_read_and_clean.ipynb` | `output/fact_orders_clean.csv` |
| 3. EDA | `notebooks/02_eda.ipynb` | `output/eda_*.csv` |
| 5. What-if | `notebooks/03_what_if.ipynb` | `output/what_if_*.csv`, `model_*.csv` |
| 4. Visualization | `powerbi/prepare_powerbi_data.py` → `powerbi/data/`; dựng theo `powerbi/HUONG_DAN_POWER_BI.md` + `powerbi/measures.dax` | `powerbi/olist_delivery_review.pbix` |
