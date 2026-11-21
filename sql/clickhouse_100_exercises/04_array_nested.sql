USE shop;
-- ### Bài 39 — arrayJoin bung mảng (Medium)
-- Giả sử cột `tags Array(String)`. Đếm tần suất mỗi tag.
-- > **Gợi ý:** `arrayJoin(tags)` biến mỗi phần tử mảng thành 1 hàng, rồi `GROUP BY tag COUNT()`.

-- Chuẩn bị: bảng phụ product_tags, mỗi sản phẩm có 2–5 tag.
CREATE TABLE IF NOT EXISTS shop.product_tags
(
    product_id UInt64,
    tags       Array(String)
)
ENGINE = MergeTree
ORDER BY product_id;

TRUNCATE TABLE shop.product_tags;

INSERT INTO shop.product_tags
SELECT
    product_id,
    arrayFilter(t -> t != '', [
        toString(category),
        lower(toString(brand)),
        if(list_price >= 100, 'premium', 'budget'),
        if(product_id % 7 = 0, 'sale', ''),
        if(product_id % 11 = 0, 'new_arrival', '')
    ]) AS tags
FROM shop.products;

-- Cách 1: hàm arrayJoin trong SELECT
SELECT
    arrayJoin(tags) AS tag,
    count() AS cnt
FROM shop.product_tags
GROUP BY tag
ORDER BY cnt DESC;

-- Cách 2: mệnh đề ARRAY JOIN (tương đương, dễ đọc hơn khi cần giữ các cột khác)
SELECT
    tag,
    count() AS cnt,
    uniqExact(product_id) AS products
FROM shop.product_tags
ARRAY JOIN tags AS tag
GROUP BY tag
ORDER BY cnt DESC;


-- ### Bài 40 — groupArray gom lịch sử (Medium)
-- Gom tất cả `event_type` của mỗi session thành một mảng theo thứ tự thời gian.
-- > **Gợi ý:** Sắp xếp trước trong subquery rồi `groupArray(event_type)`, hoặc `groupArray` + `arraySort` với cặp (time, type).

-- Cách khuyên dùng: gom cặp (time, type) rồi sort trong mảng → luôn đúng thứ tự,
-- kể cả khi query chạy song song nhiều thread.
SELECT
    session_id,
    any(user_id) AS user_id,
    arrayMap(x -> x.2, arraySort(x -> x.1, groupArray((event_time, event_type)))) AS event_path,
    length(event_path) AS n_events
FROM shop.events
GROUP BY session_id
ORDER BY n_events DESC, session_id
LIMIT 20;

-- Cách 2: ORDER BY trong subquery rồi groupArray.
-- Lưu ý: ClickHouse KHÔNG đảm bảo groupArray giữ thứ tự của subquery khi xử lý song song,
-- nên cách 1 an toàn hơn. Có thể ép 1 thread bằng SETTINGS max_threads = 1 (chậm hơn).
SELECT
    session_id,
    groupArray(event_type) AS event_path
FROM
(
    SELECT session_id, event_type
    FROM shop.events
    ORDER BY session_id, event_time
)
GROUP BY session_id
ORDER BY session_id
LIMIT 20;


-- ### Bài 41 — Phân tích funnel bằng windowFunnel (Hard)
-- Tính số user đi qua các bước view → add_to_cart → purchase trong vòng 1 giờ.
-- > **Gợi ý:** `windowFunnel(3600)(event_time, event_type='view', event_type='add_to_cart', event_type='purchase')`. Hàm trả về số bước liên tiếp đạt được; `GROUP BY user_id` trước.

-- 41a: phân phối số bước tối đa mỗi user đạt được (0, 1, 2, 3)
SELECT
    level,
    count() AS users
FROM
(
    SELECT
        user_id,
        windowFunnel(3600)(
            event_time,
            event_type = 'view',
            event_type = 'add_to_cart',
            event_type = 'purchase'
        ) AS level
    FROM shop.events
    WHERE event_type IN ('view', 'add_to_cart', 'purchase')
    GROUP BY user_id
)
GROUP BY level
ORDER BY level;

-- 41b: dạng funnel — số user đạt ÍT NHẤT bước k và tỉ lệ chuyển đổi giữa các bước
SELECT
    countIf(level >= 1) AS step1_view,
    countIf(level >= 2) AS step2_add_to_cart,
    countIf(level >= 3) AS step3_purchase,
    round(step2_add_to_cart / step1_view * 100, 2) AS view_to_cart_pct,
    round(step3_purchase / step2_add_to_cart * 100, 2) AS cart_to_purchase_pct,
    round(step3_purchase / step1_view * 100, 2) AS overall_pct
FROM
(
    SELECT
        user_id,
        windowFunnel(3600)(
            event_time,
            event_type = 'view',
            event_type = 'add_to_cart',
            event_type = 'purchase'
        ) AS level
    FROM shop.events
    WHERE event_type IN ('view', 'add_to_cart', 'purchase')
    GROUP BY user_id
);


-- ### Bài 42 — Retention bằng retention() (Hard)
-- Tính retention: user active ngày 0 và còn active ngày 1, ngày 7.
-- > **Gợi ý:** Hàm `retention(cond0, cond1, cond7)` trả mảng 0/1. `sumForEach` / `arraySum` để tổng hợp theo cohort.

-- Ngày 0 = ngày đầu tiên user xuất hiện (cohort_date).
-- retention(...) trả [d0, d1, d7]; d1/d7 chỉ = 1 khi d0 = 1.
-- sumForEach cộng từng vị trí của mảng qua mọi user → [tổng d0, tổng d1, tổng d7].
WITH first_seen AS
(
    SELECT user_id, min(event_date) AS cohort_date
    FROM shop.events
    GROUP BY user_id
)
SELECT
    cohort_date,
    sumForEach(r) AS totals,
    totals[1] AS day0_users,
    totals[2] AS day1_users,
    totals[3] AS day7_users,
    round(day1_users / day0_users * 100, 2) AS day1_retention_pct,
    round(day7_users / day0_users * 100, 2) AS day7_retention_pct
FROM
(
    SELECT
        e.user_id AS user_id,
        f.cohort_date AS cohort_date,
        retention(
            e.event_date = f.cohort_date,
            e.event_date = f.cohort_date + 1,
            e.event_date = f.cohort_date + 7
        ) AS r
    FROM shop.events AS e
    INNER JOIN first_seen AS f ON e.user_id = f.user_id
    GROUP BY user_id, cohort_date
)
GROUP BY cohort_date
ORDER BY cohort_date;


-- ### Bài 43 — arrayMap biến đổi phần tử (Medium)
-- Có mảng `prices Array(Decimal)`, tạo mảng mới đã áp thuế 10%.
-- > **Gợi ý:** `arrayMap(x -> x * 1.1, prices)`.

-- prices = giá các món trong mỗi đơn (dựng từ order_items).
-- Lưu ý: Decimal * Float (1.1) bị ClickHouse báo lỗi kiểu → nhân với Decimal hoặc đổi sang Float.
SELECT
    order_id,
    groupArray(unit_price) AS prices,
    arrayMap(x -> round(x * toDecimal64(1.1, 2), 2), prices) AS prices_with_tax,
    arraySum(prices) AS subtotal,
    arraySum(prices_with_tax) AS total_with_tax
FROM shop.order_items
GROUP BY order_id
ORDER BY order_id
LIMIT 20;


-- ### Bài 44 — arrayFilter lọc phần tử (Medium)
-- Từ mảng `amounts`, chỉ giữ các giá trị > 100 và tính tổng.
-- > **Gợi ý:** `arraySum(arrayFilter(x -> x > 100, amounts))`.

-- amounts = giá trị các đơn paid của mỗi user.
SELECT
    user_id,
    groupArray(total_amount) AS amounts,
    arrayFilter(x -> x > 100, amounts) AS big_amounts,
    length(big_amounts) AS n_big_orders,
    arraySum(big_amounts) AS big_amount_sum
FROM shop.orders FINAL
WHERE order_status = 'paid'
GROUP BY user_id
ORDER BY big_amount_sum DESC
LIMIT 20;

-- Đối chiếu: cùng kết quả nếu làm bằng aggregate có điều kiện (không cần mảng)
-- SELECT user_id, sumIf(total_amount, total_amount > 100) FROM shop.orders FINAL
-- WHERE order_status = 'paid' GROUP BY user_id;


-- ### Bài 45 — arrayReduce áp dụng aggregate lên mảng (Hard)
-- Tính trung vị (median) của một mảng số trong từng hàng.
-- > **Gợi ý:** `arrayReduce('median', amounts)` áp dụng hàm tổng hợp dạng chuỗi tên lên mảng.

-- median là xấp xỉ (reservoir sampling); medianExact là chính xác.
-- arrayReduce nhận tên hàm aggregate dạng chuỗi, kể cả hàm có tham số như 'quantileExact(0.9)'.
SELECT
    user_id,
    amounts,
    arrayReduce('median', amounts) AS median_approx,
    arrayReduce('medianExact', amounts) AS median_exact,
    arrayReduce('quantileExact(0.9)', amounts) AS p90,
    arrayReduce('avg', amounts) AS avg_amount
FROM
(
    SELECT
        user_id,
        groupArray(toFloat64(total_amount)) AS amounts
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY user_id
    HAVING length(amounts) >= 5
)
ORDER BY user_id
LIMIT 20;


-- ### Bài 46 — Nested columns truy vấn song song (Hard)
-- Với bảng có cột Nested `items.product_id`, `items.qty`, tính tổng qty mỗi hàng.
-- > **Gợi ý:** Nested thực chất là nhiều mảng song song cùng độ dài. `arraySum(items.qty)`, hoặc `arrayJoin` song song để bung.

-- Chuẩn bị: bảng orders_nested — mỗi đơn 1 hàng, các món nằm trong cột Nested `items`.
CREATE TABLE IF NOT EXISTS shop.orders_nested
(
    order_id UInt64,
    items Nested
    (
        product_id UInt64,
        unit_price Decimal(18, 2),
        qty        UInt32
    )
)
ENGINE = MergeTree
ORDER BY order_id;

TRUNCATE TABLE shop.orders_nested;

-- Các groupArray trong cùng một nhóm duyệt cùng thứ tự hàng → các mảng song song khớp nhau.
INSERT INTO shop.orders_nested (order_id, `items.product_id`, `items.unit_price`, `items.qty`)
SELECT
    order_id,
    groupArray(product_id),
    groupArray(unit_price),
    groupArray(quantity)
FROM shop.order_items
GROUP BY order_id;

-- 46a: tính trên mảng, không cần bung
SELECT
    order_id,
    items.product_id,
    items.qty,
    arraySum(items.qty) AS total_qty,
    arraySum((p, q) -> p * q, items.unit_price, items.qty) AS order_value
FROM shop.orders_nested
ORDER BY order_id
LIMIT 20;

-- 46b: bung Nested thành từng dòng (ARRAY JOIN bung các mảng song song cùng lúc)
SELECT
    order_id,
    it.product_id,
    it.unit_price,
    it.qty,
    it.unit_price * it.qty AS line_total
FROM shop.orders_nested
ARRAY JOIN items AS it
ORDER BY order_id
LIMIT 20;


-- ### Bài 47 — arrayEnumerate đánh số thứ tự (Medium)
-- Với mảng sự kiện trong session, gắn số thứ tự cho từng phần tử.
-- > **Gợi ý:** `arrayEnumerate(events_arr)` trả `[1,2,3,...]`. Kết hợp `arrayZip` để ghép index với giá trị.

-- 47a: giữ dạng mảng — ghép (số thứ tự, event_type)
SELECT
    session_id,
    events_arr,
    arrayEnumerate(events_arr) AS idx,
    arrayZip(idx, events_arr) AS numbered_events
FROM
(
    SELECT
        session_id,
        arrayMap(x -> x.2, arraySort(x -> x.1, groupArray((event_time, event_type)))) AS events_arr
    FROM shop.events
    GROUP BY session_id
)
ORDER BY session_id
LIMIT 20;

-- 47b: bung ra từng dòng kèm step_no — tương đương row_number() trong session
SELECT
    session_id,
    step_no,
    event_type
FROM
(
    SELECT
        session_id,
        arrayMap(x -> x.2, arraySort(x -> x.1, groupArray((event_time, event_type)))) AS events_arr
    FROM shop.events
    GROUP BY session_id
)
ARRAY JOIN
    events_arr AS event_type,
    arrayEnumerate(events_arr) AS step_no
ORDER BY session_id, step_no
LIMIT 50;


-- ### Bài 48 — sequenceMatch phát hiện mẫu hành vi (Hard)
-- Tìm user có mẫu hành vi: view rồi purchase mà không add_to_cart ở giữa.
-- > **Gợi ý:** `sequenceMatch('(?1).*(?2)')(event_time, cond_view, cond_purchase)` kết hợp điều kiện phủ định, hoặc `sequenceCount`. Tham khảo cú pháp pattern của ClickHouse.

-- Mẹo: sequenceMatch BỎ QUA các sự kiện không khớp điều kiện nào. Vì vậy phải khai báo
-- cả điều kiện add_to_cart (?2) dù pattern không dùng tới — nếu không, cart sẽ bị bỏ qua.
--   '(?1)(?3)'   = view rồi NGAY SAU là purchase (giữa không có cart)  ← đúng đề bài
--   '(?1).*(?3)' = view rồi purchase, ở giữa được phép có cart       ← sai đề bài
SELECT
    user_id,
    sequenceCount('(?1)(?3)')(
        event_time,
        event_type = 'view',
        event_type = 'add_to_cart',
        event_type = 'purchase'
    ) AS direct_buy_times
FROM shop.events
WHERE event_type IN ('view', 'add_to_cart', 'purchase')
GROUP BY user_id
HAVING sequenceMatch('(?1)(?3)')(
        event_time,
        event_type = 'view',
        event_type = 'add_to_cart',
        event_type = 'purchase'
    )
ORDER BY direct_buy_times DESC, user_id
LIMIT 20;

-- Mở rộng: số user mua thẳng (không qua cart) trong vòng 1 giờ sau khi view
SELECT countIf(direct_buy_1h) AS users_direct_buy_within_1h
FROM
(
    SELECT
        user_id,
        sequenceMatch('(?1)(?t<=3600)(?3)')(
            event_time,
            event_type = 'view',
            event_type = 'add_to_cart',
            event_type = 'purchase'
        ) AS direct_buy_1h
    FROM shop.events
    WHERE event_type IN ('view', 'add_to_cart', 'purchase')
    GROUP BY user_id
);


-- ### Bài 49 — arrayCumSum lũy kế trong mảng (Medium)
-- Có mảng doanh thu theo tháng của mỗi user, tính mảng lũy kế.
-- > **Gợi ý:** `arrayCumSum(monthly_revenue)`.

-- Bước 1: doanh thu theo (user, tháng); Bước 2: gom thành mảng đã sort theo tháng; Bước 3: lũy kế.
-- Lưu ý: tháng user không mua sẽ không có phần tử (mảng không liên tục theo lịch).
WITH monthly AS
(
    SELECT
        user_id,
        toStartOfMonth(created_at) AS month,
        sum(total_amount) AS revenue
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY user_id, month
)
SELECT
    user_id,
    arraySort(x -> x.1, groupArray((month, revenue))) AS sorted_pairs,
    arrayMap(x -> x.1, sorted_pairs) AS months,
    arrayMap(x -> x.2, sorted_pairs) AS monthly_revenue,
    arrayCumSum(monthly_revenue) AS cumulative_revenue
FROM monthly
GROUP BY user_id
ORDER BY user_id
LIMIT 20;


-- ### Bài 50 — Mảng giao/nhau giữa 2 tập (Hard)
-- Với 2 mảng sản phẩm của 2 user, tính số sản phẩm chung (Jaccard-like).
-- > **Gợi ý:** `arrayIntersect(a, b)` rồi `length(...)`. Jaccard = `length(intersect) / length(arrayDistinct(arrayConcat(a,b)))`.

-- 50a: ví dụ nhỏ với 2 mảng cố định để hiểu công thức
SELECT
    [1, 2, 3, 4, 5] AS a,
    [4, 5, 6, 7] AS b,
    arrayIntersect(a, b) AS common_items,                  -- [4,5]
    arrayDistinct(arrayConcat(a, b)) AS union_items,       -- [1..7]
    length(common_items) / length(union_items) AS jaccard; -- 2/7 ≈ 0.2857

-- 50b: áp dụng thật — so từng cặp trong 200 user mua nhiều sản phẩm khác nhau nhất.
-- Không so toàn bộ 100k user vì số cặp ~ n²/2 quá lớn.
-- ORDER BY có thêm user_id để tie-break: CTE được tính lại mỗi lần tham chiếu,
-- thiếu tie-break thì 2 lần tính có thể ra 2 tập user khác nhau.
WITH user_products AS
(
    SELECT
        user_id,
        groupUniqArray(product_id) AS products
    FROM shop.events
    WHERE event_type = 'purchase'
    GROUP BY user_id
    ORDER BY length(products) DESC, user_id
    LIMIT 200
)
SELECT
    a.user_id AS user_a,
    b.user_id AS user_b,
    arrayIntersect(a.products, b.products) AS common_products,
    length(common_products) AS n_common,
    length(arrayDistinct(arrayConcat(a.products, b.products))) AS union_size,
    round(n_common / union_size, 4) AS jaccard
FROM user_products AS a
CROSS JOIN user_products AS b
WHERE a.user_id < b.user_id
ORDER BY n_common DESC, jaccard DESC, user_a, user_b
LIMIT 20;
