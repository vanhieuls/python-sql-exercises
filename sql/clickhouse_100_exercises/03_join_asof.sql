USE shop;
-- ### Bài 27 — Join đơn hàng với chi tiết (Medium)
-- Nối `orders` với `order_items` để tính tổng số lượng sản phẩm mỗi đơn, đối chiếu với `total_amount`.
-- > **Gợi ý:** `INNER JOIN order_items USING (order_id)`, rồi `GROUP BY order_id`.
SELECT
    o.order_id,
    o.total_amount,
    sum(oi.quantity * oi.unit_price) AS item_amount,
    sum(oi.quantity) AS total_quantity,
    o.total_amount - item_amount AS diff
FROM shop.orders AS o
FINAL
INNER JOIN shop.order_items AS oi ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.total_amount
ORDER BY o.order_id ASC
LIMIT 50;

-- ### Bài 28 — Lợi nhuận gộp theo sản phẩm (Medium)
-- Nối `order_items` với `products` để tính lợi nhuận = `(unit_price - cost) * quantity`.
-- > **Gợi ý:** JOIN theo `product_id`, dùng `cost` từ bảng `products`. `sum((unit_price - cost) * quantity)`.
SELECT
    p.product_id,
    p.name,
    p.category,
    sum(oi.quantity) AS unit_sold,
    sum((oi.unit_price - p.cost) * oi.quantity) AS profit
FROM shop.order_items AS oi
INNER JOIN shop.products AS p ON oi.product_id = p.product_id
GROUP BY
    p.product_id,
    p.name,
    p.category
ORDER BY profit DESC
LIMIT 10;
-- ### Bài 29 — User chưa từng mua (anti join) (Medium)
-- Tìm user có trong `users` nhưng không có đơn `paid` nào.
-- > **Gợi ý:** `LEFT JOIN orders ... WHERE order_id IS NULL`, hoặc `WHERE user_id NOT IN (SELECT user_id FROM orders WHERE order_status='paid')`. ClickHouse có `LEFT ANTI JOIN`.
SELECT
    u.user_id,
    u.country
FROM shop.users AS u
LEFT JOIN
(
    SELECT
        user_id,
        order_id
    FROM shop.orders
    FINAL
    WHERE order_status = 'paid'
) AS o ON u.user_id = o.user_id
WHERE o.order_id = 0
LIMIT 20;
-- ### Bài 30 — ASOF JOIN khớp giá theo thời điểm (Hard)
-- Có bảng `price_history(product_id, price, valid_from)`. Với mỗi sự kiện bán, lấy giá hiệu lực tại thời điểm `event_time`.
-- > **Gợi ý:** `ASOF LEFT JOIN price_history ON e.product_id = p.product_id AND e.event_time >= p.valid_from`. ASOF lấy bản ghi gần nhất thỏa bất đẳng thức cuối.

SELECT
    e.product_id,
    p.price AS price_at_time,
    e.price AS price_in_event,
    e.event_time AS event_time,
    p.valid_from AS valid_from
FROM shop.events AS e
ASOF LEFT JOIN shop.price_history AS p ON (e.product_id = p.product_id) AND (e.event_time >= p.valid_from)
WHERE e.event_type = 'purchase'
LIMIT 5;

-- ### Bài 31 — Self join tìm cặp sản phẩm mua chung (Hard)
-- Tìm các cặp sản phẩm thường xuất hiện cùng trong một đơn (market basket).
-- > **Gợi ý:** Self join `order_items a JOIN order_items b ON a.order_id = b.order_id AND a.product_id < b.product_id`, rồi `GROUP BY a.product_id, b.product_id COUNT()`. Điều kiện `<` để tránh trùng cặp.
SELECT
    a.product_id AS product_a,
    b.product_id AS product_b,
    count() AS bought_together
FROM shop.order_items AS a
INNER JOIN shop.order_items AS b ON a.order_id = b.order_id
WHERE a.product_id < b.product_id
GROUP BY
    product_a,
    product_b
ORDER BY bought_together DESC
LIMIT 20;
-- ### Bài 32 — Join nhiều bảng dựng báo cáo (Medium)
-- Nối `orders`, `users`, để báo cáo doanh thu theo `plan` của user và `country`.
-- > **Gợi ý:** JOIN `orders` với `users USING(user_id)`, group theo `plan, country`.
SELECT
    u.plan,
    u.country,
    sum(o.total_amount)
FROM shop.orders AS o
INNER JOIN shop.users AS u USING (user_id)
WHERE o.order_status = 'paid'
GROUP BY
    u.plan,
    u.country;
-- ### Bài 33 — Dictionary thay cho JOIN (Hard)
-- Giả sử có dictionary `product_dict`. Lấy tên sản phẩm bằng `dictGet` thay vì join bảng.
-- > **Gợi ý:** `dictGet('product_dict', 'name', toUInt64(product_id))`. Dictionary nhanh hơn JOIN khi tra cứu key-value và nằm trong RAM.
SELECT
    dictGet('shop.product_dict', 'name', product_id) AS product_name,
    dictGet('shop.product_dict', 'brand', product_id) AS brand,
    sum(price * quantity) AS revenue
FROM shop.events
WHERE event_type = 'purchase'
GROUP BY product_id
ORDER BY revenue DESC
LIMIT 10;
-- ### Bài 34 — Semi join: user có mua category X (Medium)
-- Tìm user từng mua ít nhất một sản phẩm thuộc category 'electronics'.
-- > **Gợi ý:** `LEFT SEMI JOIN` hoặc `WHERE user_id IN (SELECT ...)`. SEMI JOIN trả mỗi hàng trái tối đa 1 lần.
SELECT
    u.user_id,
    u.country,
    u.plan
FROM shop.users AS u
SEMI LEFT JOIN
(
    SELECT DISTINCT user_id
    FROM shop.events
    WHERE (event_type = 'purchase') AND (category = 'electronics')
) AS e ON u.user_id = e.user_id
ORDER BY u.user_id ASC
LIMIT 5;
-- ### Bài 35 — Join với subquery tổng hợp (Medium)
-- Hiển thị mỗi đơn kèm tổng chi tiêu toàn thời gian của user đó.
-- > **Gợi ý:** JOIN `orders` với subquery `(SELECT user_id, sum(total_amount) ... GROUP BY user_id)`.
SELECT
    order_id,
    user_id,
    total_amount,
    sum(if(order_status = 'paid', total_amount, toDecimal64(0, 2))) OVER (PARTITION BY user_id) AS lifetime_spent
FROM shop.orders
FINAL
ORDER BY order_id ASC
LIMIT 50;
-- ### Bài 36 — Cross join sinh lịch đầy đủ (Hard)
-- Tạo báo cáo doanh thu theo ngày cho mọi ngày trong khoảng, kể cả ngày không có đơn (fill gaps).
-- > **Gợi ý:** Sinh dải ngày bằng `arrayJoin(range(...))` hoặc `numbers()`, `CROSS JOIN` / `LEFT JOIN` với dữ liệu thật. Hoặc dùng `WITH FILL` trong `ORDER BY`.
SELECT
    c.day AS report_day,
    d.orders AS orders,
    d.revenue AS revenue
FROM
(
    SELECT toDate(today() - toIntervalDay(number)) AS day
    FROM numbers(220)
) AS c
LEFT JOIN
(
    SELECT
        toDate(created_at) AS day,
        count() AS orders,
        sum(total_amount) AS revenue
    FROM shop.orders
    FINAL
    WHERE order_status = 'paid'
    GROUP BY day
) AS d ON c.day = d.day
ORDER BY report_day ASC;    
-- ### Bài 37 — Join phân tán (GLOBAL JOIN) (Hard)
-- Giải thích và viết query dùng `GLOBAL JOIN` khi bảng phải ở cluster phân tán.
-- > **Gợi ý:** Trên `Distributed` table, `JOIN` thường phải là `GLOBAL JOIN` để bảng phải được phát tán tới mọi shard. Lưu ý chi phí network.

-- ### Bài 38 — Điền giá trị bị thiếu bằng WITH FILL (Medium)
-- Doanh thu theo ngày, điền 0 cho ngày trống dùng `ORDER BY day WITH FILL`.
-- > **Gợi ý:** `ORDER BY day WITH FILL STEP toIntervalDay(1)`. Các cột aggregate sẽ là 0/NULL cho ngày được điền.

SELECT
    toDate(created_at) AS day,
    count() AS orders,
    sum(total_amount) AS revenue
FROM shop.orders
FINAL
WHERE order_status = 'paid'
GROUP BY day
ORDER BY day ASC WITH FILL FROM today() - toIntervalDay(220) TO today() + 1 STEP toIntervalDay(1);

