--Liệt kê 10 khách hàng mới nhất (theo `created_at`) kèm email. Kết quả: `id, name, email, created_at`.
SELECT id, name, email, created_at
FROM customers
ORDER BY created_at DESC 
LIMIT 10;

-- 2. Đếm số sản phẩm đang kinh doanh (không `discontinued`). Kết quả: `active_product_count`.
SELECT COUNT(*) AS count_product
FROM products 
WHERE discontinued = FALSE;

-- 3. Lấy top 5 sản phẩm có `unit_price` cao nhất. Kết quả: `id, name, unit_price`.
SELECT id, name, unit_price
FROM products
ORDER BY unit_price DESC
LIMIT 5;

-- 4. Tìm tất cả đơn hàng ở trạng thái `paid` trong tháng hiện tại. Kết quả: `id, customer_id, order_date, status`.
orders (
  id                BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(id),
  order_date        TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL,       -- 'pending','paid','shipped','cancelled','refunded'
  shipped_date      TIMESTAMPTZ,
  shipping_fee      NUMERIC(12,2) DEFAULT 0,
  payment_method    TEXT                 -- 'card','bank','cod', ...
);
SELECT id, customer_id, order_date, status
FROM orders 
WHERE status = 'paid' 
	  AND order_date >= DATE_TRUNC('month', CURRENT_DATE)
	  AND order_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

--5. Liệt kê các dòng chi tiết đơn hàng của `order_id = :id` với tổng tiền dòng = `quantity * unit_price * (1 - discount/100)`. 
--Kết quả: `product_id, quantity, unit_price, discount, line_total`.
-- Chi tiết đơn hàng
order_details (
  order_id          BIGINT NOT NULL REFERENCES orders(id),
  product_id        BIGINT NOT NULL REFERENCES products(id),
  quantity          INTEGER NOT NULL CHECK (quantity > 0),
  unit_price        NUMERIC(12,2) NOT NULL,     -- chốt tại thời điểm bán
  discount          NUMERIC(5,2) DEFAULT 0,     -- % giảm giá: 0..100
  PRIMARY KEY (order_id, product_id)
);

SELECT product_id, quantity, unit_price, discount, quantity * unit_price * (1 - discount/100) AS line_total
FROM order_details
WHERE order_id = :id;

-- 6. Tính doanh thu (chưa gồm phí ship) theo từng đơn hàng: `order_total = SUM(quantity * unit_price * (1 - discount/100))` trên `order_details`.
--Chỉ tính các đơn `status IN ('paid','shipped')`. Kết quả: `order_id, order_total`

SELECT od.order_id, SUM(od.quantity * od.unit_price * (1 - od.discount/100)) AS order_total
FROM order_details od  INNER JOIN orders o
	  ON od.order_id = o.id
WHERE o.status IN ('paid','shipped')
GROUP BY od.order_id;

--7. Lấy doanh thu theo khách hàng: tổng `order_total` (bài 6) + tổng `shipping_fee`, với điều kiện như bài 6. 
--Kết quả: `customer_id, revenue, shipping_fee_total, grand_total`.
WITH order_total AS(
	SELECT od.order_id, SUM(od.quantity * od.unit_price * (1 - od.discount/100)) AS total
    FROM order_details od
    GROUP BY od.order_id
)
SELECT o.customer_id, SUM(ot.total) AS revenue, SUM(o.shipping_fee) AS shipping_fee_total, SUM(o.shipping_fee + ot.total) AS shipping_fee_total
FROM order_total ot  INNER JOIN orders o
	  ON ot.order_id = o.id
WHERE o.status IN ('paid','shipped')
GROUP BY o.customer_id;

-- 8. Doanh thu theo danh mục sản phẩm trong quý hiện tại. Kết quả: `category, revenue`.
WITH cte AS(
	SELECT p.category, od.order_id, od.quantity, od.unit_price, od.discount 
	FROM order_details od INNER JOIN products p 
	ON od.product_id = p.id
)
SELECT cte.category, SUM(od.quantity * od.unit_price * (1 - od.discount/100)) AS revenue
FROM orders o INNER JOIN cte ON o.id = cte.order_id
WHERE o.status IN ('paid', 'shipped')
  AND o.order_date >= DATE_TRUNC('quarter', CURRENT_DATE)
  AND o.order_date < DATE_TRUNC('quarter', CURRENT_DATE) + INTERVAL '3 months'
GROUP BY cte.category;
-- 9. Liệt kê những khách hàng chưa từng đặt hàng (không có bản ghi trong `orders`). Kết quả: `id, name, email`.
SELECT c.id, c.name, c.email
FROM customers c LEFT JOIN orders o
     ON c.id = o.customer_id
WHERE o.id IS NULL;

-- 10. Tính số đơn và doanh thu theo từng `payment_method` trong 90 ngày gần nhất. Kết quả: `payment_method, order_count, revenue`.
SELECT o.payment_method, COUNT(DISTINCT o.id) AS order_count,SUM(od.quantity * od.unit_price * (1 - od.discount/100)) AS revenue
FROM orders o INNER JOIN order_details od ON o.id = od.order_id
WHERE o.order_date >= NOW() - INTERVAL '90 days'
	  AND o.status IN ('paid','shipped') 
GROUP BY o.payment_method;

-- 11. Với mỗi đơn hàng, tính "tỷ lệ giảm giá trung bình" theo trọng số số lượng: `weighted_discount = SUM(qty * discount) / SUM(qty)`
--. Chỉ với các đơn có ít nhất 1 dòng giảm giá > 0. Kết quả: `order_id, weighted_discount_pct`.
SELECT order_id, SUM(quantity * discount) / SUM(quantity) AS weighted_discount_pct
FROM order_details
GROUP BY order_id
HAVING MAX(discount) > 0;

-- 12. Tìm các đơn hàng giao muộn: `shipped_date::date - order_date::date > 3`. Kết quả: `id, customer_id, order_date, shipped_date, delay_days`.
SELECT id, customer_id, order_date, shipped_date, (shipped_date::date - order_date::date) > 3 AS delay_days
FROM orders
WHERE (shipped_date::date - order_date::date) > 3

--13. Liệt kê 10 sản phẩm bán chạy nhất theo số lượng trong 30 ngày gần nhất. Kết quả: `product_id, name, total_qty`.
order_details (
  order_id          BIGINT NOT NULL REFERENCES orders(id),
  product_id        BIGINT NOT NULL REFERENCES products(id),
  quantity          INTEGER NOT NULL CHECK (quantity > 0),
  unit_price        NUMERIC(12,2) NOT NULL,     -- chốt tại thời điểm bán
  discount          NUMERIC(5,2) DEFAULT 0,     -- % giảm giá: 0..100
  PRIMARY KEY (order_id, product_id)
);

products (
  id                BIGINT PRIMARY KEY,
  name              TEXT NOT NULL,
  category          TEXT,
  unit_price        NUMERIC(12,2) NOT NULL,
  cost              NUMERIC(12,2) NOT NULL,
  discontinued      BOOLEAN NOT NULL DEFAULT FALSE,
  stock             INTEGER NOT NULL DEFAULT 0
);


SELECT 
    od.product_id, 
    p.name, 
    SUM(od.quantity) AS total_qty
FROM order_details od
INNER JOIN products p ON od.product_id = p.id
INNER JOIN orders o ON od.order_id = o.id
WHERE o.order_date >= NOW() - INTERVAL '30 days'
  AND o.status IN ('paid', 'shipped') 
GROUP BY od.product_id, p.name
ORDER BY total_qty DESC 
LIMIT 10; 

-- 14. Tính biên lợi nhuận gộp theo đơn: `gross_profit = SUM(quantity * (unit_price - p.cost) * (1 - discount/100))` (join sang `products p`). 
--Chỉ `status IN ('paid','shipped')`. Kết quả: `order_id, gross_profit`.
order_details (
  order_id          BIGINT NOT NULL REFERENCES orders(id),
  product_id        BIGINT NOT NULL REFERENCES products(id),
  quantity          INTEGER NOT NULL CHECK (quantity > 0),
  unit_price        NUMERIC(12,2) NOT NULL,     -- chốt tại thời điểm bán
  discount          NUMERIC(5,2) DEFAULT 0,     -- % giảm giá: 0..100
  PRIMARY KEY (order_id, product_id)
);
orders (
  id                BIGINT PRIMARY KEY,
  customer_id       BIGINT NOT NULL REFERENCES customers(id),
  order_date        TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL,       -- 'pending','paid','shipped','cancelled','refunded'
  shipped_date      TIMESTAMPTZ,
  shipping_fee      NUMERIC(12,2) DEFAULT 0,
  payment_method    TEXT                 -- 'card','bank','cod', ...
);
products (
  id                BIGINT PRIMARY KEY,
  name              TEXT NOT NULL,
  category          TEXT,
  unit_price        NUMERIC(12,2) NOT NULL,
  cost              NUMERIC(12,2) NOT NULL,
  discontinued      BOOLEAN NOT NULL DEFAULT FALSE,
  stock             INTEGER NOT NULL DEFAULT 0
);
SELECT od.order_id, SUM(od.quantity * (od.unit_price - p.cost) * (1 - od.discount/100)) AS gross_profit
FROM order_details od
INNER JOIN products p ON od.product_id = p.id
INNER JOIN orders o ON od.order_id = o.id
WHERE o.status IN ('paid', 'shipped')
GROUP BY od.order_id; 
-- 15. Tính AOV (Average Order Value) hằng tháng trong 12 tháng gần nhất (`AOV = doanh thu / số đơn`). Kết quả: `month, orders, revenue, aov`.

SELECT 
  TO_CHAR(o.order_date, 'YYYY-MM') AS month,          
  COUNT(DISTINCT o.id) AS orders,                   
  SUM(od.quantity * od.unit_price * (1 - od.discount/100)) AS revenue,
  ROUND(
      SUM(od.quantity * od.unit_price * (1 - od.discount/100)) / COUNT(DISTINCT o.id), 
        2
  ) AS aov
FROM orders o
INNER JOIN order_details od ON o.id = od.order_id
WHERE o.order_date >= DATE_TRUNC('month', NOW()) - INTERVAL '12 months'
  AND o.status IN ('paid', 'shipped')                                   
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM');
-----------------------------Thực chiến------------------------------
--16. RFM cơ bản: Tính cho mỗi khách hàng trong 180 ngày gần nhất: `Recency` = số ngày từ đơn gần nhất đến hôm nay (chỉ `paid`/`shipped`), `Frequency` = số đơn, `Monetary` = tổng doanh thu (như bài 7). Kết quả: `customer_id, recency_days, frequency, monetary`.
WITH order_summary AS (
    -- Tính tổng tiền từng đơn hàng trong 180 ngày gần nhất (gồm tiền hàng + phí ship)
    SELECT 
        o.id AS order_id,
        o.customer_id,
        o.order_date,
        o.shipping_fee,
        SUM(od.quantity * od.unit_price * (1 - od.discount / 100)) AS items_total,
        (SUM(od.quantity * od.unit_price * (1 - od.discount / 100)) + o.shipping_fee) AS order_total
    FROM orders o
    JOIN order_details od ON o.id = od.order_id
    WHERE o.status IN ('paid', 'shipped')
      AND o.order_date >= NOW() - INTERVAL '180 days'
    GROUP BY o.id, o.customer_id, o.order_date, o.shipping_fee
)
--Gom nhóm theo khách hàng để tính R, F, M
SELECT 
    customer_id,
    EXTRACT(DAY FROM (NOW() - MAX(order_date)))::INTEGER AS recency_days, COUNT(DISTINCT order_id) AS frequency, SUM(order_total) AS monetary
FROM order_summary
GROUP BY customer_id;


17. Phân hạng khách hàng theo RFM quintile (1..5) rồi tạo điểm `rfm_score = R + F + M`. Xuất top 20 khách có `rfm_score` cao nhất. Kết quả: `customer_id, r, f, m, rfm_score`.
18. Cohort theo tháng mua hàng đầu tiên: xác định `cohort_month` = tháng của đơn đầu tiên của mỗi KH, tính tỷ lệ KH quay lại đặt đơn ở các tháng +1, +2, +3… trong 6 tháng. Kết quả: ma trận `cohort_month, m0_customers, m1_retained_pct, ... m6_retained_pct`.
19. Basket analysis (cặp sản phẩm hay mua cùng): tìm top 20 cặp `(product_a, product_b)` xuất hiện cùng một `order_id` nhiều nhất trong 6 tháng gần đây. Kết quả: `product_a, product_b, co_occurrence_count`.
20. Rolling 7-day revenue: mỗi ngày trong 90 ngày gần nhất, tính tổng doanh thu 7 ngày gần nhất (cửa sổ trượt). Kết quả: `date, revenue, revenue_7d_rollsum`.
--21. Phát hiện "giá bán thấp hơn cost": tìm các dòng chi tiết có `unit_price * (1 - discount/100) < cost`. Kết quả: `order_id, product_id, effective_price, cost`.
SELECT od.order_id, od.product_id, ROUND(od.unit_price * (1 - od.discount / 100.0), 2) AS effective_price, p.cost
FROM order_details od
JOIN products p ON od.product_id = p.id
WHERE (od.unit_price * (1 - od.discount / 100.0)) < p.cost;
--22. Tồn kho âm tiềm ẩn: với mỗi sản phẩm, tính tổng số lượng đã bán (trong các đơn `paid`/`shipped`) trừ `stock`. Liệt kê sản phẩm có `sold_qty > stock`. Kết quả: `product_id, name, stock, sold_qty, shortfall`.
SELECT 
  p.id AS product_id, p.name, p.stock,
  SUM(od.quantity) AS sold_qty,
  (SUM(od.quantity) - p.stock) AS shortfall
FROM products p
JOIN order_details od ON p.id = od.product_id
JOIN orders o ON od.order_id = o.id
WHERE o.status IN ('paid', 'shipped')
GROUP BY p.id, p.name, p.stock
HAVING SUM(od.quantity) > p.stock;

23. Doanh thu "chuẩn hoá" theo khách: Z-score của `monetary` (bài 16) trong 1 năm gần nhất: `z = (monetary - avg(monetary)) / stddev(monetary)`. Kết quả: `customer_id, monetary, z_score`.
24. Tỷ lệ hoàn/huỷ theo danh mục trong 6 tháng: "Hoàn/huỷ" = đơn `status IN ('cancelled','refunded')`. Mẫu số: tổng đơn của danh mục đó (theo sản phẩm xuất hiện trong đơn). Kết quả: `category, total_orders, cancelled_refunded_orders, rate`.
--25. Xác định "sản phẩm mồ côi": sản phẩm không xuất hiện trong bất kỳ đơn `paid`/`shipped` trong 120 ngày gần đây nhưng `discontinued = FALSE`. Kết quả: `product_id, name, last_order_date`.
SELECT p.id AS product_id, p.name, MAX(o.order_date) AS last_order_date
FROM products p
LEFT JOIN order_details od ON p.id = od.product_id
LEFT JOIN orders o ON od.order_id = o.id AND o.status IN ('paid', 'shipped')
WHERE p.discontinued = FALSE
GROUP BY p.id, p.name
HAVING MAX(o.order_date) < NOW() - INTERVAL '120 days' 
    OR MAX(o.order_date) IS NULL;

26. Tính LTV sơ bộ: với mỗi khách, lấy doanh thu tích luỹ trong 365 ngày kể từ đơn đầu tiên. Kết quả: `customer_id, first_order_date, ltv_365`.
27. Doanh thu theo "kênh thanh toán" nhưng loại bỏ ảnh hưởng của khuyến mãi cực đoan: dùng median của giá trị đơn theo `payment_method` trong 90 ngày gần nhất. (Postgres: `percentile_cont(0.5) WITHIN GROUP (ORDER BY order_total)`). Kết quả: `payment_method, median_order_value`.
28. Tìm đơn hàng "bất thường": đơn có `shipping_fee > percentile_cont(0.95)` theo phân phối phí ship 90 ngày gần nhất và tổng tiền < median 90 ngày. Kết quả: `order_id, shipping_fee, order_total`.
29. Phân rã tăng trưởng doanh thu theo tháng gần nhất so với tháng trước thành 3 thành phần: số đơn tăng/giảm, giá trị trung bình đơn (AOV) tăng/giảm, phí ship tăng/giảm. Kết quả: một bảng trình bày `month, revenue, delta_orders, delta_aov, delta_shipping`.
30. Tạo materialized view `mv_monthly_sales` lưu doanh thu/tháng (bao gồm phí ship) cho `paid`/`shipped`, rồi viết câu query đọc view này để: trả ra 12 tháng gần nhất, thêm cột `mom_growth_pct` (tăng trưởng % so với tháng trước). Kết quả: `month, revenue, mom_growth_pct`.