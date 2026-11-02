-- Bước 1: Tạo bảng phân tích order-level (1 dòng / order_id)
-- Chạy: mysql -uroot -p < sql/03_build_mart.sql
USE olist;

-- Toạ độ trung bình theo zip prefix (geolocation có nhiều điểm / zip)
DROP TABLE IF EXISTS geo_zip;
CREATE TABLE geo_zip AS
SELECT geolocation_zip_code_prefix AS zip_code_prefix,
       AVG(geolocation_lat)        AS lat,
       AVG(geolocation_lng)        AS lng
FROM geolocation
GROUP BY geolocation_zip_code_prefix;
ALTER TABLE geo_zip ADD PRIMARY KEY (zip_code_prefix);

DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders AS
WITH items AS (
    SELECT order_id,
           COUNT(*)                  AS n_items,
           COUNT(DISTINCT product_id) AS n_products,
           COUNT(DISTINCT seller_id) AS n_sellers,
           SUM(price)                AS total_price,
           SUM(freight_value)        AS total_freight,
           MAX(shipping_limit_date)  AS shipping_limit_date
    FROM order_items
    GROUP BY order_id
),
-- Sản phẩm / người bán "chính" = item có giá cao nhất trong đơn
main_item AS (
    SELECT order_id, product_id, seller_id
    FROM (
        SELECT order_id, product_id, seller_id,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY price DESC, order_item_id) AS rn
        FROM order_items
    ) t
    WHERE rn = 1
),
payments AS (
    SELECT order_id,
           SUM(payment_value)        AS payment_value,
           MAX(payment_installments) AS payment_installments,
           COUNT(*)                  AS n_payments,
           -- phương thức có giá trị thanh toán lớn nhất
           SUBSTRING_INDEX(GROUP_CONCAT(payment_type ORDER BY payment_value DESC), ',', 1)
                                     AS payment_type
    FROM order_payments
    GROUP BY order_id
),
-- Một order có thể có nhiều review -> giữ review mới nhất
reviews AS (
    SELECT order_id, review_score, review_comment_title, review_comment_message,
           review_creation_date, review_answer_timestamp
    FROM (
        SELECT r.*,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY review_answer_timestamp DESC) AS rn
        FROM order_reviews r
    ) t
    WHERE rn = 1
)
SELECT o.order_id,
       o.order_status,
       o.order_purchase_timestamp,
       o.order_approved_at,
       o.order_delivered_carrier_date,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       c.customer_unique_id,
       c.customer_zip_code_prefix,
       c.customer_city,
       c.customer_state,
       gc.lat                         AS customer_lat,
       gc.lng                         AS customer_lng,
       i.n_items,
       i.n_products,
       i.n_sellers,
       i.total_price,
       i.total_freight,
       i.shipping_limit_date,
       mi.product_id                  AS main_product_id,
       COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
                                      AS main_category,
       p.product_weight_g,
       p.product_photos_qty,
       mi.seller_id                   AS main_seller_id,
       s.seller_zip_code_prefix,
       s.seller_city,
       s.seller_state,
       gs.lat                         AS seller_lat,
       gs.lng                         AS seller_lng,
       pm.payment_value,
       pm.payment_type,
       pm.payment_installments,
       pm.n_payments,
       r.review_score,
       r.review_comment_title,
       r.review_comment_message,
       r.review_creation_date,
       r.review_answer_timestamp
FROM orders o
JOIN customers c                              ON c.customer_id = o.customer_id
LEFT JOIN geo_zip gc                          ON gc.zip_code_prefix = c.customer_zip_code_prefix
LEFT JOIN items i                             ON i.order_id = o.order_id
LEFT JOIN main_item mi                        ON mi.order_id = o.order_id
LEFT JOIN products p                          ON p.product_id = mi.product_id
LEFT JOIN product_category_name_translation t ON t.product_category_name = p.product_category_name
LEFT JOIN sellers s                           ON s.seller_id = mi.seller_id
LEFT JOIN geo_zip gs                          ON gs.zip_code_prefix = s.seller_zip_code_prefix
LEFT JOIN payments pm                         ON pm.order_id = o.order_id
LEFT JOIN reviews r                           ON r.order_id = o.order_id;

ALTER TABLE fact_orders ADD PRIMARY KEY (order_id);

-- Kiểm tra: số dòng = số order distinct
SELECT (SELECT COUNT(*) FROM fact_orders)              AS fact_rows,
       (SELECT COUNT(DISTINCT order_id) FROM orders)   AS distinct_orders,
       (SELECT COUNT(*) FROM fact_orders WHERE review_score IS NULL)   AS no_review,
       (SELECT COUNT(*) FROM fact_orders WHERE n_items IS NULL)        AS no_items,
       (SELECT COUNT(*) FROM fact_orders WHERE customer_lat IS NULL)   AS no_customer_geo,
       (SELECT COUNT(*) FROM fact_orders WHERE seller_lat IS NULL
                                           AND n_items IS NOT NULL)    AS no_seller_geo;
