-- Bước 1: Nạp CSV vào MySQL
-- Chạy từ thư mục capstone-project:
--   mysql --local-infile=1 -uroot -p < sql/02_load_data.sql
-- (server cần: SET GLOBAL local_infile = 1;)
USE olist;
SET FOREIGN_KEY_CHECKS = 0;

LOAD DATA LOCAL INFILE 'dataset/olist_customers_dataset.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'dataset/olist_sellers_dataset.csv' INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'dataset/olist_geolocation_dataset.csv' INTO TABLE geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- File translation dùng CRLF và có BOM ở header (header bị bỏ qua)
LOAD DATA LOCAL INFILE 'dataset/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'dataset/olist_products_dataset.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @cat, @name_len, @desc_len, @photos, @weight, @length, @height, @width)
SET product_category_name      = NULLIF(@cat, ''),
    product_name_lenght        = NULLIF(@name_len, ''),
    product_description_lenght = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos, ''),
    product_weight_g           = NULLIF(@weight, ''),
    product_length_cm          = NULLIF(@length, ''),
    product_height_cm          = NULLIF(@height, ''),
    product_width_cm           = NULLIF(@width, '');

LOAD DATA LOCAL INFILE 'dataset/olist_orders_dataset.csv' INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @purchase, @approved, @carrier, @delivered, @estimated)
SET order_purchase_timestamp      = NULLIF(@purchase, ''),
    order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(@estimated, '');

LOAD DATA LOCAL INFILE 'dataset/olist_order_items_dataset.csv' INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'dataset/olist_order_payments_dataset.csv' INTO TABLE order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Comment review có thể chứa xuống dòng (nằm trong dấu ngoặc kép) và dấu '\'
-- -> tắt ký tự escape, nếu không MySQL gộp 2 dòng thành 1 (mất 1 review)
LOAD DATA LOCAL INFILE 'dataset/olist_order_reviews_dataset.csv' INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '' LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @title, @message, review_creation_date, review_answer_timestamp)
SET review_comment_title   = NULLIF(@title, ''),
    review_comment_message = NULLIF(@message, '');

SET FOREIGN_KEY_CHECKS = 1;

-- Kiểm tra số dòng (kỳ vọng theo pandas.read_csv)
SELECT 'customers' AS tbl, COUNT(*) AS n_rows, 99441 AS expected FROM customers
UNION ALL SELECT 'sellers', COUNT(*), 3095 FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*), 1000163 FROM geolocation
UNION ALL SELECT 'category_translation', COUNT(*), 71 FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*), 32951 FROM products
UNION ALL SELECT 'orders', COUNT(*), 99441 FROM orders
UNION ALL SELECT 'order_items', COUNT(*), 112650 FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*), 103886 FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*), 99224 FROM order_reviews;
