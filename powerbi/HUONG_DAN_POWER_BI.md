# Bước 4 — Hướng dẫn dựng dashboard Power BI

**Mục tiêu:** 4 trang kể một câu chuyện: *Tổng quan → Giao trễ ở đâu → Trễ làm hỏng review ra sao → Nếu giao tốt hơn thì được gì*.

**File đầu vào** (`powerbi/data/`, tạo bởi `prepare_powerbi_data.py`):

| File | Vai trò | Số dòng |
|---|---|---|
| `fact_delivery.csv` | Fact: 1 dòng / order trong phạm vi phân tích (delivered, có review, 01/2017–08/2018) | 95.560 |
| `dim_date.csv` | Bảng ngày | 602 |
| `dim_state.csv` | 27 bang Brazil + vùng + `location` cho bản đồ | 27 |
| `what_if_reduction.csv` | Kết quả model: giảm trễ 0–15 ngày → review xấu tránh được | 16 |
| `what_if_delay_curve.csv` | Kết quả model: số ngày trễ 0–30 → xác suất review xấu (đơn điển hình) | 31 |
| `what_if_scenarios.csv` | 5 kịch bản What-if | 5 |
| `model_metrics.csv`, `model_coefficients.csv` | Hiệu suất & hệ số model | 4 / 11 |
| `kpi_checklist.csv` | Số liệu đúng để đối chiếu với dashboard | 15 |

DAX: `powerbi/measures.dax`.

---

## 0. Chuẩn bị (máy ảo Windows)
1. Trên Mac, chạy lại nếu dữ liệu thay đổi: `.venv/bin/python powerbi/prepare_powerbi_data.py`
2. Copy thư mục `powerbi/data/` vào máy ảo (VMware Fusion: *Virtual Machine → Sharing → Shared Folders*, hoặc kéo thả).
3. **Quan trọng — định dạng số:** CSV dùng dấu chấm thập phân (`12.5`). Nếu Windows đặt vùng Việt Nam, Power BI sẽ hiểu sai số.
   *File → Options and settings → Options → CURRENT FILE → Regional Settings → Locale for import = **English (United States)*** — làm **trước** khi import.

## 1. Import & Power Query
*Home → Get data → Text/CSV*, import lần lượt 8 file (trừ `kpi_checklist.csv`). Với mỗi file chọn **Transform Data** và kiểm tra kiểu:

| Bảng | Cột | Kiểu |
|---|---|---|
| fact_delivery | `purchase_date` | Date |
| | `total_price`, `total_freight`, `payment_value`, `freight_ratio`, `delivery_days`, `estimated_days`, `handling_days`, `distance_km` | Decimal number |
| | `n_items`, `n_sellers`, `delay_days`, `is_late`, `delay_bucket_order`, `distance_bin_order`, `same_state`, `review_score`, `bad_review`, `has_comment` | Whole number |
| | còn lại | Text |
| dim_date | `date` | Date |
| what_if_delay_curve | `late_days` | Whole number |
| what_if_reduction | `reduce_days` | Whole number |
| what_if_*, model_* | các cột số còn lại | Decimal number |

*Close & Apply.* Kiểm tra số dòng `fact_delivery` = **95.560**.

## 2. Model
**Relationships** (Model view, Many-to-one, Single direction):
- `fact_delivery[purchase_date]` → `dim_date[date]`
- `fact_delivery[customer_state]` → `dim_state[state_code]`

Các bảng `what_if_*`, `model_*` để **không quan hệ** (độc lập).

**Sort by column** (Data view → chọn cột → *Column tools → Sort by column*):
- `fact_delivery[delay_bucket]` sort theo `delay_bucket_order`
- `fact_delivery[distance_bin]` sort theo `distance_bin_order`
- `dim_date[month_name]` sort theo `month`

**Mark as date table:** chọn `dim_date` → *Table tools → Mark as date table* → cột `date`.

**Data category:** `dim_state[location]` → *Column tools → Data category = Place*.

**Measures:** tạo bảng `_Measures` (*Home → Enter data → đặt tên `_Measures` → Load*), rồi *New measure* lần lượt theo `measures.dax`. Format:
- `Late Rate`, `Bad Review Rate`, `Bad Review Rate Late/On Time`, `Late Rate Overall`, `WI * Rate`, `WI Prob Bad Review` → **Percentage, 1 chữ số thập phân**
- `Avg Review*` → Decimal, 2 chữ số
- `Revenue` → Whole number, phân cách hàng nghìn

**What-if parameters** (*Modeling → New parameter → Numeric range*, bật *Add slicer to this page*):
- `Reduce Days`: 0 → 15, increment 1, default 3 (đặt ở trang 4)
- `Late Days`: 0 → 30, increment 1, default 5 (đặt ở trang 4)

*(Tạo parameter trước, rồi mới tạo các measure `WI ...` vì chúng dùng `[Reduce Days Value]`, `[Late Days Value]`.)*

---

## 3. Bốn trang dashboard

Bố cục chung: tiêu đề trang ở trên + **1 câu insight** (text box) ngay dưới tiêu đề. Màu nhất quán: xanh = đúng hạn/tốt, đỏ = trễ/xấu.

### Trang 1 — Overview: "Olist giao hàng & sự hài lòng của khách"
| Visual | Fields |
|---|---|
| 6 Card | `Orders`, `Revenue`, `Late Rate`, `Avg Review`, `Bad Review Rate`, `Avg Delivery Days` |
| Line & clustered column chart | X: `dim_date[year_month]` · Column: `Orders` · Line: `Late Rate` |
| Line chart | X: `dim_date[year_month]` · Y: `Avg Review` |
| Slicer | `dim_date[year]`, `dim_state[region]` |

**Insight:** *95.560 đơn, 6,7% giao trễ. Tỉ lệ trễ tăng vọt ở 11/2017 (12,3%, đợt Black Friday) và 02–03/2018 (14,0% và 18,7%); đúng những tháng đó điểm review trung bình giảm xuống dưới 4,0.*

### Trang 2 — Delivery: "Giao trễ ở đâu?"
| Visual | Fields |
|---|---|
| Filled map (hoặc Azure Map) | Location: `dim_state[location]` · Color saturation: `Late Rate` · Tooltip: `Orders`, `Avg Delivery Days`, `Avg Review` |
| Clustered bar | Y: `dim_state[state_code]` · X: `Late Rate` (sort giảm dần) · thêm *Constant line* = `Late Rate Overall` |
| Column chart | X: `fact_delivery[distance_bin]` · Y: `Late Rate`, `Avg Delivery Days` |
| Table | `seller_state`, `customer_state`, `Orders`, `Late Rate` — filter *Orders ≥ 300*, sort `Late Rate` giảm dần |
| Bar chart | Y: `main_category` · X: `Bad Review Rate` — filter Top N 10 theo `Orders` |

> Nếu visual bản đồ không hiển thị trong máy ảo (cần internet và tính năng map được bật trong *Options → Security*), dùng bar chart theo bang thay thế.

**Insight:** *Bang vùng Đông Bắc trễ nhiều nhất: AL 20,9%, MA 17,2%, SE 15,1% — so với SP chỉ 4,4%. Khoảng cách càng xa càng dễ trễ: <100 km trễ 4,4%, >2.000 km trễ 11,9%. Tuyến SP → RJ (8.047 đơn) trễ 14,0%. Ghi chú: các bang phía Bắc (AM, AP, RO) ít trễ (~3%) nhưng giao trung bình 19–27 ngày — ngày dự kiến được đặt rất xa nên "đúng hạn" không có nghĩa là nhanh.*

### Trang 3 — Delivery × Review: "Trễ làm hỏng review như thế nào?"
| Visual | Fields |
|---|---|
| 3 Card | `Avg Review Late`, `Avg Review On Time`, `Bad Review Multiplier` |
| Column chart | X: `fact_delivery[delay_bucket]` · Y: `Bad Review Rate` · Data labels on |
| 100% stacked bar | Y: `delay_bucket` · X: `Orders` · Legend: `review_score` |
| Clustered column | X: `fact_delivery[seller_type]` · Y: `Bad Review Rate`, `Late Rate` |
| Card (text) | `Insight Late vs On Time` |

**Insight:** *Đơn trễ trung bình 2,27★ so với 4,29★ của đơn đúng hạn; tỉ lệ review xấu 62,4% vs 9,3% (gấp ~6,7 lần). Mức trễ càng lớn càng tệ: trễ 1–3 ngày → 32% review xấu, 4–7 ngày → 68%, >7 ngày → 79%. Riêng đơn nhiều người bán có 47% review xấu dù hầu như không trễ → vấn đề khác ngoài giao hàng.*

### Trang 4 — What-if: "Nếu giao hàng tốt hơn?"
| Visual | Fields |
|---|---|
| Slicer | `Reduce Days` (parameter) |
| 3 Card | `WI Bad Reviews Avoided`, `WI Late Orders Bad Rate`, `WI System Bad Rate` |
| Card (text) | `WI Insight` |
| Line chart | X: `what_if_reduction[reduce_days]` · Y: `bad_reviews_avoided` |
| Slicer | `Late Days` (parameter) |
| Card | `WI Prob Bad Review` |
| Line chart | X: `what_if_delay_curve[late_days]` · Y: `prob_bad_review` |
| Table | `what_if_scenarios`: `scenario`, `orders`, `pred_bad_rate_before`, `pred_bad_rate_after`, `bad_reviews_avoided` |
| Table nhỏ | `model_metrics` (dòng Logistic ngưỡng tối ưu): ROC-AUC, Recall, Precision, F1 |

**Insight:** *Theo mô hình Logistic Regression (ROC-AUC 0,75): giảm trễ 3 ngày cho mọi đơn trễ tránh ~580 review xấu; giao đúng hạn toàn bộ tránh ~2.085, đưa tỉ lệ review xấu toàn hệ thống từ 12,8% xuống 10,7%. Giảm phí ship 20% gần như không có tác dụng. Một đơn điển hình: đúng hạn → 18% khả năng review xấu; trễ 7 ngày → 47%; trễ 10 ngày → 61%.*
*Lưu ý trên slide: đây là ước lượng theo mô hình tương quan, không phải kết quả thử nghiệm.*

---

## 4. Kiểm tra trước khi nộp
So sánh card trên dashboard (không filter) với `data/kpi_checklist.csv`:

| Measure | Giá trị đúng |
|---|---|
| Orders | 95.560 |
| Revenue | 15.246.886 BRL (≈ 15,25 triệu) |
| Late Rate | 6,7% |
| Avg Review | 4,16 |
| Bad Review Rate | 12,8% |
| Avg Delivery Days | 12,5 |
| Avg Review Late / On Time | 2,27 / 4,29 |
| Bad Review Rate Late / On Time | 62,4% / 9,3% |
| Late Rate khi filter 2018-03 | 18,7% |
| Late Rate khi filter bang AL | 20,9% |
| WI Bad Reviews Avoided (Reduce Days = 3) | ≈ 580 |

Nếu `Orders` đúng nhưng các số thập phân sai → kiểm tra lại **Locale for import** (mục 0.3).

Lưu file: `powerbi/olist_delivery_review.pbix`.
