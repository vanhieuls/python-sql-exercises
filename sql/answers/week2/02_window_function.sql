Use shop;
-- ### Bài 13 — Running total doanh thu (Medium)
-- Tính doanh thu lũy kế theo ngày (cumulative sum).
-- > **Gợi ý:** `sum(daily_revenue) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. Tính `daily_revenue` ở subquery trước.
SELECT day, daily_revenue, 
       SUM(daily_revenue) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_sum
FROM(
    SELECT toDate(created_at) AS day, sum(total_amount) AS daily_revenue
    FROM shop.orders FINAL
    WHERE order_status='paid'
    GROUP BY day 
)
ORDER BY day;
-- ### Bài 14 — Moving average 7 ngày (Medium)
-- Tính trung bình trượt 7 ngày của số đơn hàng mỗi ngày.
-- > **Gợi ý:** `avg(order_count) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`.
SELECT day, order_count,
       avg(order_count) OVER(ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS avg_7d
FROM (
    SELECT toDate(created_at) AS day, count() AS order_count
    FROM shop.orders FINAL
    GROUP BY day
    ORDER BY day WITH FILL STEP 1
)
ORDER BY day;
-- ### Bài 15 — So sánh với ngày trước (lag) (Medium)
-- Tính % tăng trưởng doanh thu ngày so với ngày liền trước.
-- > **Gợi ý:** `lag(revenue) OVER (ORDER BY day)` hoặc `lagInFrame`. Tính `(today - yesterday) / yesterday * 100`. Cẩn thận chia cho 0.
SELECT day, revenue, pre_revenue, if(pre_revenue = 0, NULL, round((toFloat64(revenue) - toFloat64(pre_revenue)) / toFloat64(pre_revenue) * 100, 2)
    ) AS growth
FROM(
    SELECT day, revenue, lagInFrame(revenue,1,toDecimal64(0,2)) OVER(ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS pre_revenue 
    FROM(
        SELECT toDate(created_at) AS day, sum(total_amount) AS revenue
        FROM shop.orders FINAL
        WHERE order_status = 'paid'
        GROUP BY day
    )
)
ORDER BY day
LIMIT 10;
-- ### Bài 16 — Xếp hạng user theo chi tiêu (Medium)
-- Xếp hạng user theo tổng chi tiêu dùng `rank`, `dense_rank`, `row_number` — hiển thị cả 3 để thấy khác biệt.
-- > **Gợi ý:** `rank()` để lại khoảng trống khi đồng hạng, `dense_rank()` không, `row_number()` luôn duy nhất. `OVER (ORDER BY total_spent DESC)`.
SELECT user_id, total_spent, 
       rank() OVER(ORDER BY total_spent DESC) AS rank,
       dense_rank() OVER(ORDER BY total_spent DESC) AS dense_rank,
       row_number() OVER(ORDER BY total_spent DESC) AS row_nb
FROM(
    SELECT user_id, sum(total_amount) AS total_spent
    FROM shop.orders FINAL
    WHERE order_status='paid'
    GROUP BY user_id
)
ORDER BY total_spent DESC, user_id
LIMIT 30;
-- ### Bài 17 — Phần trăm tích lũy (percent of running total) (Hard)
-- Xếp sản phẩm theo doanh thu giảm dần và tính % lũy kế để phân tích Pareto (80/20).
-- > **Gợi ý:** Running sum chia cho tổng: `sum(rev) OVER (ORDER BY rev DESC) / sum(rev) OVER ()`. Lọc ngưỡng 80% để tìm nhóm sản phẩm chủ lực.
SELECT revenue, product_id, run_sum
FROM(
    SELECT revenue, product_id,
           round(toFloat64(sum(revenue) OVER(ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))/toFloat64(sum(revenue) OVER())*100,2) AS run_sum
    FROM (
        SELECT product_id, sum(price*quantity) AS revenue
        FROM shop.events
        WHERE event_type='purchase'
        GROUP BY product_id
    )
)
WHERE run_sum<=80
ORDER BY run_sum;
-- ### Bài 18 — First/last value trong phiên (Hard)
-- Với mỗi `session_id`, tìm trang/sự kiện đầu tiên và cuối cùng của phiên.
-- > **Gợi ý:** `first_value(event_type) OVER (PARTITION BY session_id ORDER BY event_time)` và `last_value(...)` với frame `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. Chú ý frame mặc định của `last_value`.
SELECT
    session_id,
    argMin(event_type, event_time) AS first_event,
    argMax(event_type, event_time) AS last_event
FROM shop.events
GROUP BY session_id
LIMIT 50;
-- ### Bài 19 — Khoảng cách thời gian giữa 2 sự kiện (Medium)
-- Tính số giây giữa mỗi sự kiện và sự kiện trước đó của cùng user.
-- > **Gợi ý:** `event_time - lagInFrame(event_time) OVER (PARTITION BY user_id ORDER BY event_time)`, rồi `dateDiff('second', ...)` hoặc trừ trực tiếp `DateTime`.
SELECT user_id, event_time, event_type, pre_time, if(pre_time=toDateTime(0), NULL, dateDiff('second', pre_time, event_time)) AS gap_second
FROM (
    SELECT user_id, event_time,event_type, lagInFrame(event_time, 1, toDateTime(0)) OVER(PARTITION BY user_id ORDER BY event_time ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS pre_time
    FROM shop.events
    WHERE user_id IN (1,2,3)
)
ORDER BY user_id, event_time; 
-- ### Bài 20 — Ntile phân nhóm user (Medium)
-- Chia user thành 10 nhóm (decile) theo tổng chi tiêu.
-- > **Gợi ý:** `ntile(10) OVER (ORDER BY total_spent DESC)`. Mỗi nhóm ~10% user.
SELECT decile, count() AS users, round(min(total_spent), 2) AS min_spent, round(max(total_spent), 2) AS max_spent, sum(total_spent) AS decile_revenue
FROM (
    SELECT user_id, total_spent, ntile(10) OVER(ORDER BY total_spent DESC) AS decile
    FROM (
        SELECT user_id, sum(total_amount) AS total_spent
        FROM shop.orders FINAL
        WHERE order_status = 'paid'
        GROUP BY user_id
    )
)
GROUP BY decile
ORDER BY decile;
SELECT count()/10 FROM shop.users;
-- ### Bài 21 — Số phiên đồng thời (sessionization) (Hard)
-- Xác định ranh giới phiên mới khi khoảng cách giữa 2 sự kiện của cùng user > 30 phút, đánh số phiên.
-- > **Gợi ý:** Dùng `lag` để lấy thời gian trước, tạo cờ `new_session = gap > 1800`, rồi `sum(new_session) OVER (PARTITION BY user_id ORDER BY event_time)` làm session index.

-- ### Bài 22 — Streak đăng nhập liên tiếp (Hard)
-- Tìm chuỗi ngày hoạt động liên tiếp dài nhất của mỗi user.
-- > **Gợi ý:** Kỹ thuật "gaps and islands": `date - toIntervalDay(row_number() OVER (PARTITION BY user_id ORDER BY date))` tạo khóa nhóm cho các ngày liên tiếp, rồi đếm theo nhóm.
SELECT user_id, max(streak_days) AS longest_streak
FROM(
    SELECT user_id, grp, count() AS streak_days
    FROM(
        SELECT
            user_id, event_date, event_date - toIntervalDay(rn) AS grp
        FROM(
            SELECT
                user_id, event_date, row_number() OVER (PARTITION BY user_id ORDER BY event_date) AS rn
            FROM (SELECT DISTINCT user_id, event_date FROM shop.events)
        )
    )
    GROUP BY user_id, grp
)
GROUP BY user_id
ORDER BY longest_streak DESC, user_id
LIMIT 10;
-- ### Bài 23 — Top-N thay đổi theo thời gian (Hard)
-- Với mỗi tháng, tìm category có doanh thu cao nhất và so sánh với tháng trước.
-- > **Gợi ý:** Window `argMax`/`row_number` theo tháng, rồi `lag` để lấy category tháng trước. Nhiều tầng subquery.

-- ### Bài 24 — Chênh lệch so với trung bình nhóm (Medium)
-- So sánh giá mỗi sản phẩm với giá trung bình của category nó thuộc.
-- > **Gợi ý:** `list_price - avg(list_price) OVER (PARTITION BY category)`.
SELECT product_id, list_price, category, name,
       avg(list_price) OVER(PARTITION BY category) AS avg,
       list_price - avg(list_price) OVER(PARTITION BY category) AS diff
FROM shop.products
ORDER BY category, diff DESC;
-- ### Bài 25 — Running distinct count xấp xỉ (Hard)
-- Số user duy nhất lũy kế theo ngày (approx).
-- > **Gợi ý:** ClickHouse không có `count(distinct) OVER`. Dùng trick: tính `uniqState` theo ngày rồi merge lũy kế, hoặc tính ngày first_seen của mỗi user rồi cộng dồn số user mới. Cách thứ hai đơn giản hơn cho junior.
SELECT day, uniqMerge(state) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative
FROM (
    SELECT event_date AS day, uniqState(user_id) AS state
    FROM shop.events
    GROUP BY day
)
ORDER BY day;

-- ### Bài 26 — Lead để dự đoán sự kiện kế tiếp (Medium)
-- Với mỗi sự kiện `view`, xác định sự kiện kế tiếp của cùng user có phải `purchase` không.
-- > **Gợi ý:** `leadInFrame(event_type) OVER (PARTITION BY user_id ORDER BY event_time)`, so sánh `= 'purchase'`.
SELECT
    count() AS views,
    countIf(next_event = 'purchase') AS followed_by_purchase,
    round(followed_by_purchase / views * 100, 3) AS pct
FROM(
    SELECT
        event_type,
        leadInFrame(event_type, 1, '') OVER (
            PARTITION BY user_id ORDER BY event_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS next_event
    FROM shop.events
)
WHERE event_type = 'view';