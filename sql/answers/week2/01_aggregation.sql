# Query C
USE shop;

--câu 1
SELECT category, country, sum(price * quantity) AS revenue
FROM shop.events
WHERE event_type='purchase'
GROUP BY category, country
ORDER BY revenue DESC
LIMIT 20;

-- ### Bài 2 — Subtotal với WITH ROLLUP (Medium)
-- Tính doanh thu theo `country` và `category`, đồng thời có dòng tổng phụ (subtotal) cho từng `country` và một dòng tổng chung.
-- > **Gợi ý:** Thêm `WITH ROLLUP` sau `GROUP BY country, category`. Các dòng subtotal có giá trị `category` rỗng/0; dùng hàm như `if` để gán nhãn "ALL" cho dễ đọc.
SELECT
    if(country='', 'ALL', country) AS country_label,
    if(category='', 'ALL', category) AS category_label,
    sum(price * quantity) AS revenue
FROM shop.events
WHERE event_type='purchase'
GROUP BY country, category WITH ROLLUP
ORDER BY country, category;



-- ### Bài 3 — Ma trận tổng với WITH CUBE (Medium)
-- Tạo báo cáo đa chiều: tổng doanh thu cho mọi tổ hợp con của (`country`, `device`, `category`).
-- > **Gợi ý:** Dùng `GROUP BY country, device, category WITH CUBE`. CUBE sinh tất cả tổ hợp con, khác ROLLUP (chỉ theo thứ tự phân cấp).
SELECT
    if(country='', 'ALL', country) AS country_label,
    if(device='', 'ALL', device) AS device_label,
    if(category='', 'ALL', category) AS category_label,
    sum(price * quantity) AS revenue
FROM shop.events
WHERE event_type='purchase'
GROUP BY country, device, category WITH CUBE
ORDER BY country, device, category;

-- ### Bài 4 — Số người dùng duy nhất chính xác vs xấp xỉ (Medium)
-- So sánh số user duy nhất theo ngày bằng `uniqExact`, `uniq` và `uniqHLL12`. Hiển thị 3 cột trong cùng một query.
-- > **Gợi ý:** `uniqExact(user_id)` chính xác nhưng tốn RAM; `uniq(user_id)` xấp xỉ nhanh; `uniqHLL12` dùng HyperLogLog. Nhóm theo `event_date`.
SELECT
    event_date,
    uniqExact(user_id) AS exact_users,
    uniq(user_id) AS approx_users,
    uniqHLL12(user_id) AS hll_users,
    round(abs(approx_users-exact_users)/exact_users * 100, 3) AS uniq_error_pct,
    round(abs(hll_user-exact_users)/exact_users * 100, 3) AS hll_error_pct
FROM shop.events
GROUP BY event_date
ORDER BY event_date;

-- ### Bài 5 — Doanh thu và AOV theo ngày (Medium)
-- Tính doanh thu hàng ngày và giá trị đơn trung bình (AOV = tổng doanh thu / số đơn) từ bảng `orders` trạng thái `paid`.
-- > **Gợi ý:** `sum(total_amount)` và `sum(total_amount) / count()`. Lọc `order_status = 'paid'`. Nhóm theo `toDate(created_at)`.
SELECT toDate(created_at) AS order_date,
       sum(total_amount) AS revenue,
       count() AS paid_count,
       sum(total_amount) / count() AS aov
FROM shop.orders FINAL
WHERE order_status='paid'
GROUP BY order_date 
ORDER BY order_date;

-- ### Bài 6 — Top sản phẩm theo từng danh mục (Hard)
-- Với mỗi `category`, tìm 3 sản phẩm có doanh thu cao nhất.
-- > **Gợi ý:** Dùng window function `row_number() OVER (PARTITION BY category ORDER BY revenue DESC)` trong subquery, sau đó lọc `rn <= 3`. Hoặc dùng `arrayJoin` kết hợp `groupArray` + `arraySlice`.
WITH a AS (
    SELECT category, product_id, sum(price * quantity) AS revenue, row_number() OVER (PARTITION BY category ORDER BY sum(price * quantity) DESC) AS rn
    FROM shop.events
    WHERE event_type='purchase'
    GROUP BY category, product_id
)
SELECT category, product_id, revenue, rn 
FROM a
WHERE rn<=3
ORDER BY category, rn;

SELECT category, product_id, sum(price * quantity) AS revenue
FROM shop.events
WHERE event_type='purchase'
GROUP BY category, product_id
ORDER BY category, revenue DESC
LIMIT 3 BY category;
-- ### Bài 7 — argMax để lấy giá trị kèm theo (Medium)
-- Với mỗi `user_id`, tìm `product_id` của sự kiện `purchase` gần nhất (theo `event_time`).
-- > **Gợi ý:** `argMax(product_id, event_time)` trả về `product_id` ứng với `event_time` lớn nhất. Không cần self-join.

SELECT
    user_id,
    argMax(product_id, event_time) AS last_purchased_product,
    max(event_time) AS last_purchase_time
FROM shop.events
WHERE event_type='purchase'
GROUP BY user_id
ORDER BY last_purchase_time DESC
LIMIT 20;
-- ### Bài 8 — Phân phối phân vị response time (Medium)
-- Từ `access_logs`, tính p50, p90, p95, p99 của `response_ms` theo từng giờ.
-- > **Gợi ý:** `quantile(0.5)(response_ms)`, hoặc `quantiles(0.5, 0.9, 0.95, 0.99)(response_ms)` trả về mảng. Nhóm theo `toStartOfHour(ts)`.
SELECT toStartOfHour(ts) AS hour, count() AS requests,
       quantiles(0.5, 0.9, 0.95, 0.99)(response_ms) AS qs,
       round(qs[1],1) AS p50,
       round(qs[2],1) AS p90,
       round(qs[3],1) AS p95,
       round(qs[4],1) AS p99
FROM shop.access_logs
GROUP BY hour
ORDER BY hour;

-- ### Bài 9 — Tỉ lệ đóng góp doanh thu (share) (Hard)
-- Tính doanh thu từng `category` và % đóng góp của nó trên tổng doanh thu toàn hệ thống.
-- > **Gợi ý:** Dùng window `sum(revenue) OVER ()` làm mẫu số, hoặc `CROSS JOIN` với subquery tính tổng. `revenue / total * 100`.
SELECT
    category,
    revenue,
    sum(revenue) OVER () AS total_revenue,
    round(toFloat64(revenue) / toFloat64(sum(revenue) OVER ()) * 100, 2) AS share
FROM
(
    SELECT category, sum(price * quantity) AS revenue
    FROM shop.events
    WHERE event_type='purchase'
    GROUP BY category
)
ORDER BY revenue DESC;
-- ### Bài 10 — Đếm có điều kiện (conditional aggregation) (Medium)
-- Trong một query, đếm số sự kiện `view`, `add_to_cart`, `purchase` thành 3 cột riêng, nhóm theo `event_date`.
-- > **Gợi ý:** `countIf(event_type = 'view')`, `countIf(event_type = 'add_to_cart')`, ... Đây là pivot thủ công bằng `*If`.
SELECT
    event_date,
    countIf(event_type='view') AS views,
    countIf(event_type='add_to_cart') AS add_to_carts,
    countIf(event_type='purchase') AS purchases
FROM shop.events
GROUP BY event_date
ORDER BY event_date;
-- ### Bài 11 — Doanh thu trung bình có trọng số (Hard)
-- Tính giá bán trung bình có trọng số theo `quantity` cho mỗi `category` (weighted average price).
-- > **Gợi ý:** `sum(price * quantity) / sum(quantity)`. Không dùng `avg(price)` vì bỏ qua số lượng.
SELECT
    category, sum(quantity) AS unit_sold,
    round(sum(price * quantity) / sum(quantity), 2) AS weighted_avg_price,
    round(avg(price), 2) AS simple_avg_price
FROM shop.events
WHERE event_type='purchase'
GROUP BY category
ORDER BY category;
-- ### Bài 12 — groupArray và sort trong mảng (Hard)
-- Với mỗi `user_id`, lấy mảng các `product_id` đã mua, sắp xếp theo thời gian mua tăng dần, loại trùng.
-- > **Gợi ý:** `groupArray(product_id)` kết hợp sắp xếp qua `arraySort`/`arrayDistinct`, hoặc dùng `groupArray` trên subquery đã `ORDER BY event_time`. Chú ý ClickHouse không đảm bảo thứ tự trong `groupArray` nếu không sắp xếp trước.

WITH a AS (
    SELECT user_id, product_id
    FROM shop.events
    WHERE event_type='purchase'
    ORDER BY event_time
)
SELECT user_id, arrayDistinct(groupArray(product_id)) AS purchased_product
FROM a
GROUP BY user_id
ORDER BY user_id;