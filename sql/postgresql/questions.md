## Lược đồ (giả định)

```sql
-- Khách hàng
customers (
  id                BIGINT PRIMARY KEY,
  name              TEXT NOT NULL,
  email             TEXT UNIQUE NOT NULL,
  city              TEXT,
  tier              SMALLINT,            -- 1,2,3
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sản phẩm
products (
  id                BIGINT PRIMARY KEY,
  name              TEXT NOT NULL,
  category          TEXT,
  unit_price        NUMERIC(12,2) NOT NULL,
  cost              NUMERIC(12,2) NOT NULL,
  discontinued      BOOLEAN NOT NULL DEFAULT FALSE,
  stock             INTEGER NOT NULL DEFAULT 0
);

-- Đơn hàng
orders (
  id                BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(id),
  order_date        TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL,       -- 'pending','paid','shipped','cancelled','refunded'
  shipped_date      TIMESTAMPTZ,
  shipping_fee      NUMERIC(12,2) DEFAULT 0,
  payment_method    TEXT                 -- 'card','bank','cod', ...
);

-- Chi tiết đơn hàng
order_details (
  order_id          BIGINT NOT NULL REFERENCES orders(id),
  product_id        BIGINT NOT NULL REFERENCES products(id),
  quantity          INTEGER NOT NULL CHECK (quantity > 0),
  unit_price        NUMERIC(12,2) NOT NULL,     -- chốt tại thời điểm bán
  discount          NUMERIC(5,2) DEFAULT 0,     -- % giảm giá: 0..100
  PRIMARY KEY (order_id, product_id)
);
```

## 5 bài khởi động

1. Liệt kê 10 khách hàng mới nhất (theo `created_at`) kèm email. Kết quả: `id, name, email, created_at`.
2. Đếm số sản phẩm đang kinh doanh (không `discontinued`). Kết quả: `active_product_count`.
3. Lấy top 5 sản phẩm có `unit_price` cao nhất. Kết quả: `id, name, unit_price`.
4. Tìm tất cả đơn hàng ở trạng thái `paid` trong tháng hiện tại. Kết quả: `id, customer_id, order_date, status`.
5. Liệt kê các dòng chi tiết đơn hàng của `order_id = :id` với tổng tiền dòng = `quantity * unit_price * (1 - discount/100)`. Kết quả: `product_id, quantity, unit_price, discount, line_total`.

## 10 bài cơ bản

6. Tính doanh thu (chưa gồm phí ship) theo từng đơn hàng: `order_total = SUM(quantity * unit_price * (1 - discount/100))` trên `order_details`. Chỉ tính các đơn `status IN ('paid','shipped')`. Kết quả: `order_id, order_total`.
7. Lấy doanh thu theo khách hàng: tổng `order_total` (bài 6) + tổng `shipping_fee`, với điều kiện như bài 6. Kết quả: `customer_id, revenue, shipping_fee_total, grand_total`.
8. Doanh thu theo danh mục sản phẩm trong quý hiện tại. Kết quả: `category, revenue`.
9. Liệt kê những khách hàng chưa từng đặt hàng (không có bản ghi trong `orders`). Kết quả: `id, name, email`.
10. Tính số đơn và doanh thu theo từng `payment_method` trong 90 ngày gần nhất. Kết quả: `payment_method, order_count, revenue`.
11. Với mỗi đơn hàng, tính "tỷ lệ giảm giá trung bình" theo trọng số số lượng: `weighted_discount = SUM(qty * discount) / SUM(qty)`. Chỉ với các đơn có ít nhất 1 dòng giảm giá > 0. Kết quả: `order_id, weighted_discount_pct`.
12. Tìm các đơn hàng giao muộn: `shipped_date::date - order_date::date > 3`. Kết quả: `id, customer_id, order_date, shipped_date, delay_days`.
13. Liệt kê 10 sản phẩm bán chạy nhất theo số lượng trong 30 ngày gần nhất. Kết quả: `product_id, name, total_qty`.
14. Tính biên lợi nhuận gộp theo đơn: `gross_profit = SUM(quantity * (unit_price - p.cost) * (1 - discount/100))` (join sang `products p`). Chỉ `status IN ('paid','shipped')`. Kết quả: `order_id, gross_profit`.
15. Tính AOV (Average Order Value) hằng tháng trong 12 tháng gần nhất (`AOV = doanh thu / số đơn`). Kết quả: `month, orders, revenue, aov`.

## 15 bài thực chiến

16. RFM cơ bản: Tính cho mỗi khách hàng trong 180 ngày gần nhất: `Recency` = số ngày từ đơn gần nhất đến hôm nay (chỉ `paid`/`shipped`), `Frequency` = số đơn, `Monetary` = tổng doanh thu (như bài 7). Kết quả: `customer_id, recency_days, frequency, monetary`.
17. Phân hạng khách hàng theo RFM quintile (1..5) rồi tạo điểm `rfm_score = R + F + M`. Xuất top 20 khách có `rfm_score` cao nhất. Kết quả: `customer_id, r, f, m, rfm_score`.
18. Cohort theo tháng mua hàng đầu tiên: xác định `cohort_month` = tháng của đơn đầu tiên của mỗi KH, tính tỷ lệ KH quay lại đặt đơn ở các tháng +1, +2, +3… trong 6 tháng. Kết quả: ma trận `cohort_month, m0_customers, m1_retained_pct, ... m6_retained_pct`.
19. Basket analysis (cặp sản phẩm hay mua cùng): tìm top 20 cặp `(product_a, product_b)` xuất hiện cùng một `order_id` nhiều nhất trong 6 tháng gần đây. Kết quả: `product_a, product_b, co_occurrence_count`.
20. Rolling 7-day revenue: mỗi ngày trong 90 ngày gần nhất, tính tổng doanh thu 7 ngày gần nhất (cửa sổ trượt). Kết quả: `date, revenue, revenue_7d_rollsum`.
21. Phát hiện "giá bán thấp hơn cost": tìm các dòng chi tiết có `unit_price * (1 - discount/100) < cost`. Kết quả: `order_id, product_id, effective_price, cost`.
22. Tồn kho âm tiềm ẩn: với mỗi sản phẩm, tính tổng số lượng đã bán (trong các đơn `paid`/`shipped`) trừ `stock`. Liệt kê sản phẩm có `sold_qty > stock`. Kết quả: `product_id, name, stock, sold_qty, shortfall`.
23. Doanh thu "chuẩn hoá" theo khách: Z-score của `monetary` (bài 16) trong 1 năm gần nhất: `z = (monetary - avg(monetary)) / stddev(monetary)`. Kết quả: `customer_id, monetary, z_score`.
24. Tỷ lệ hoàn/huỷ theo danh mục trong 6 tháng: "Hoàn/huỷ" = đơn `status IN ('cancelled','refunded')`. Mẫu số: tổng đơn của danh mục đó (theo sản phẩm xuất hiện trong đơn). Kết quả: `category, total_orders, cancelled_refunded_orders, rate`.
25. Xác định "sản phẩm mồ côi": sản phẩm không xuất hiện trong bất kỳ đơn `paid`/`shipped` trong 120 ngày gần đây nhưng `discontinued = FALSE`. Kết quả: `product_id, name, last_order_date`.
26. Tính LTV sơ bộ: với mỗi khách, lấy doanh thu tích luỹ trong 365 ngày kể từ đơn đầu tiên. Kết quả: `customer_id, first_order_date, ltv_365`.
27. Doanh thu theo "kênh thanh toán" nhưng loại bỏ ảnh hưởng của khuyến mãi cực đoan: dùng median của giá trị đơn theo `payment_method` trong 90 ngày gần nhất. (Postgres: `percentile_cont(0.5) WITHIN GROUP (ORDER BY order_total)`). Kết quả: `payment_method, median_order_value`.
28. Tìm đơn hàng "bất thường": đơn có `shipping_fee > percentile_cont(0.95)` theo phân phối phí ship 90 ngày gần nhất và tổng tiền < median 90 ngày. Kết quả: `order_id, shipping_fee, order_total`.
29. Phân rã tăng trưởng doanh thu theo tháng gần nhất so với tháng trước thành 3 thành phần: số đơn tăng/giảm, giá trị trung bình đơn (AOV) tăng/giảm, phí ship tăng/giảm. Kết quả: một bảng trình bày `month, revenue, delta_orders, delta_aov, delta_shipping`.
30. Tạo materialized view `mv_monthly_sales` lưu doanh thu/tháng (bao gồm phí ship) cho `paid`/`shipped`, rồi viết câu query đọc view này để: trả ra 12 tháng gần nhất, thêm cột `mom_growth_pct` (tăng trưởng % so với tháng trước). Kết quả: `month, revenue, mom_growth_pct`.