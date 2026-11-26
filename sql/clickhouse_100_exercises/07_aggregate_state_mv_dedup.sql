USE shop;
-- =====================================================================
-- Chủ đề 7 — Aggregate State, Materialized View, dedup (bài 75–86)
-- Chủ đề này phần lớn là THIẾT KẾ BẢNG. Mỗi bài tạo bảng riêng (tiền tố rõ ràng), dùng
-- CREATE ... IF NOT EXISTS + TRUNCATE để chạy lại file nhiều lần không bị nhân đôi dữ liệu.
-- Bảng gốc (events, orders, ...) chỉ bị đổi ở bài 85 (thêm projection) — có lệnh gỡ kèm theo.
--

-- =====================================================================


-- ### Bài 75 — uniqState + uniqMerge (Hard)
-- Giải thích và viết query lưu `uniqState(user_id)` theo ngày rồi merge lại thành tổng theo tháng.
-- > **Gợi ý:** `uniqState` tạo trạng thái trung gian (dùng trong MV); `uniqMerge` gộp lại. Query đọc từ bảng `AggregatingMergeTree`: `uniqMerge(users_state)`.
--
CREATE TABLE IF NOT EXISTS shop.agg_daily_users (
    event_date Date,
    users_state AggregateFunction(uniq, UInt64)
)
ENGINE = AggregatingMergeTree
ORDER BY event_date;

TRUNCATE TABLE shop.agg_daily_users;

INSERT INTO shop.agg_daily_users
SELECT event_date,
    uniqState(user_id) AS users_state
FROM shop.events
GROUP BY event_date;

-- Merge state theo ngày → số user duy nhất theo tháng
SELECT m.month AS month,
    m.users_from_state AS users_from_state,
    m.sum_of_daily_users AS sum_of_daily_users_WRONG,
    e.users_exact_raw AS users_from_raw_events
FROM (
    SELECT toStartOfMonth(event_date) AS month,
        uniqMerge(users_state) AS users_from_state,
        sum(daily) AS sum_of_daily_users
    FROM (
        -- finalizeAggregation(state) = đọc con số của 1 state (để minh họa cột sai)
        SELECT event_date, users_state, finalizeAggregation(users_state) AS daily
        FROM shop.agg_daily_users
    )
    GROUP BY month
) AS m
INNER JOIN (
    SELECT toStartOfMonth(event_date) AS month, uniq(user_id) AS users_exact_raw
    FROM shop.events
    GROUP BY month
) AS e ON m.month = e.month
ORDER BY month;


-- ### Bài 76 — AggregatingMergeTree MV (Hard)
-- Viết `CREATE MATERIALIZED VIEW` tổng hợp doanh thu ngày dùng `sumState`.
-- > **Gợi ý:** MV đích là `AggregatingMergeTree`, cột là `sumState(amount)`. Khi đọc dùng `sumMerge`. MV cập nhật khi insert vào bảng nguồn.
CREATE TABLE IF NOT EXISTS shop.agg_daily_revenue (
    event_date Date,
    category LowCardinality(String),
    revenue_state AggregateFunction(sum, Decimal(18, 2)),
    purchases_state AggregateFunction(count)
)
ENGINE = AggregatingMergeTree
ORDER BY (event_date, category);

CREATE MATERIALIZED VIEW IF NOT EXISTS shop.mv_daily_revenue
TO shop.agg_daily_revenue
AS
SELECT event_date, category,
    sumState(CAST(price * quantity AS Decimal(18, 2))) AS revenue_state,
    countState() AS purchases_state
FROM shop.events
WHERE event_type = 'purchase'
GROUP BY event_date, category;

-- Backfill dữ liệu đã có 
TRUNCATE TABLE shop.agg_daily_revenue;

INSERT INTO shop.agg_daily_revenue
SELECT event_date, category,
    sumState(CAST(price * quantity AS Decimal(18, 2))),
    countState()
FROM shop.events
WHERE event_type = 'purchase'
GROUP BY event_date, category;

-- Đọc luôn GROUP BY + -Merge
SELECT event_date,
    sumMerge(revenue_state) AS revenue,
    countMerge(purchases_state) AS purchases
FROM shop.agg_daily_revenue
GROUP BY event_date
ORDER BY event_date DESC
LIMIT 14;


-- ### Bài 77 — quantileState kết hợp nhiều phần (Hard)
-- Lưu `quantileState(0.95)(response_ms)` theo giờ, truy vấn p95 theo ngày từ state.
-- > **Gợi ý:** `quantileState` → `quantileMerge(0.95)`. Không thể trung bình các p95 theo cách thường, phải merge state.
--
CREATE TABLE IF NOT EXISTS shop.agg_hourly_latency (
    hour DateTime,
    requests SimpleAggregateFunction(sum, UInt64),
    p95_state AggregateFunction(quantile(0.95), UInt32)
)
ENGINE = AggregatingMergeTree
ORDER BY hour;

TRUNCATE TABLE shop.agg_hourly_latency;

INSERT INTO shop.agg_hourly_latency
SELECT toStartOfHour(ts) AS hour,
    count() AS requests,
    quantileState(0.95)(response_ms) AS p95_state
FROM shop.access_logs
GROUP BY hour;

SELECT s.day AS day,
    s.p95_from_state AS p95_from_state,
    s.avg_of_hourly_p95 AS avg_of_hourly_p95_WRONG,
    r.p95_raw AS p95_from_raw_logs
FROM (
    SELECT toDate(hour) AS day,
        quantileMerge(0.95)(p95_state) AS p95_from_state,
        avg(hourly_p95) AS avg_of_hourly_p95
    FROM (
        SELECT hour, p95_state, finalizeAggregation(p95_state) AS hourly_p95
        FROM shop.agg_hourly_latency
    )
    GROUP BY day
) AS s
INNER JOIN (
    SELECT toDate(ts) AS day, quantile(0.95)(response_ms) AS p95_raw
    FROM shop.access_logs
    GROUP BY day
) AS r ON s.day = r.day
ORDER BY day;

-- ### Bài 78 — Dedup với ReplacingMergeTree (Medium)
-- `orders` dùng `ReplacingMergeTree(updated_at)`. Viết query lấy bản mới nhất của mỗi đơn an toàn (chưa merge).
-- > **Gợi ý:** `SELECT ... FROM orders FINAL`, hoặc `argMax(col, updated_at) GROUP BY order_id`. `FINAL` tốn tài nguyên; argMax thường tốt hơn cho query.
--
CREATE TABLE IF NOT EXISTS shop.demo_orders_replacing (
    order_id UInt64,
    order_status LowCardinality(String),
    total_amount Decimal(18, 2),
    updated_at DateTime
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY order_id;

TRUNCATE TABLE shop.demo_orders_replacing;
INSERT INTO shop.demo_orders_replacing VALUES (1, 'created', 100, '2026-01-01 10:00:00'), (2, 'created', 50, '2026-01-01 11:00:00');
INSERT INTO shop.demo_orders_replacing VALUES (1, 'paid',    100, '2026-01-01 10:05:00');
INSERT INTO shop.demo_orders_replacing VALUES (1, 'shipped', 100, '2026-01-02 08:00:00');

-- (a) đọc thường 
SELECT * FROM shop.demo_orders_replacing ORDER BY order_id, updated_at;

-- (b) FINAL
SELECT * FROM shop.demo_orders_replacing FINAL ORDER BY order_id;

-- (c) argMax
SELECT order_id,
    argMax(order_status, updated_at) AS order_status,
    argMax(total_amount, updated_at) AS total_amount,
    max(updated_at) AS updated_at
FROM shop.demo_orders_replacing
GROUP BY order_id
ORDER BY order_id;

-- Áp dụng trên bảng thật: số đơn theo trạng thái mới nhất
SELECT order_status, count() AS orders
FROM (
    SELECT order_id, argMax(order_status, updated_at) AS order_status
    FROM shop.orders
    GROUP BY order_id
)
GROUP BY order_status
ORDER BY orders DESC;


-- ### Bài 79 — FINAL vs argMax (Hard)
-- So sánh kết quả `FROM orders FINAL` và cách dùng `argMax` theo `updated_at`; giải thích khi nào dùng cái nào.
-- > **Gợi ý:** `FINAL` merge toàn bộ cột tự động nhưng chậm; `argMax` chỉ lấy cột cần, nhanh hơn nhưng phải liệt kê cột thủ công.

-- 79a: so sánh kết quả 2 cách
SELECT f.order_status AS order_status,
    f.orders AS orders_final,
    a.orders AS orders_argmax,
    f.orders - a.orders AS diff
FROM (
    SELECT order_status, count() AS orders
    FROM shop.orders FINAL
    GROUP BY order_status
) AS f
FULL OUTER JOIN (
    SELECT order_status, count() AS orders
    FROM (
        SELECT order_id, argMax(order_status, updated_at) AS order_status
        FROM shop.orders
        GROUP BY order_id
    )
    GROUP BY order_status
) AS a ON f.order_status = a.order_status
ORDER BY order_status;

-- ### Bài 80 — SummingMergeTree (Medium)
-- Thiết kế bảng `SummingMergeTree` cộng dồn doanh thu theo (ngày, category) và query tổng.
-- > **Gợi ý:** `ORDER BY (date, category)`; các cột numeric tự cộng khi merge. Query vẫn nên `sum()` để gộp phần chưa merge.
--
CREATE TABLE IF NOT EXISTS shop.sum_daily_category (
    event_date Date,
    category LowCardinality(String),
    revenue Decimal(38, 2),
    quantity UInt64,
    purchases UInt64
)
ENGINE = SummingMergeTree
ORDER BY (event_date, category);

TRUNCATE TABLE shop.sum_daily_category;

-- Lô 1: user chẵn
INSERT INTO shop.sum_daily_category
SELECT event_date, category, sum(price * quantity), sum(quantity), count()
FROM shop.events
WHERE event_type = 'purchase' AND user_id % 2 = 0
GROUP BY event_date, category;

-- Lô 2: user lẻ
INSERT INTO shop.sum_daily_category
SELECT event_date, category, sum(price * quantity), sum(quantity), count()
FROM shop.events
WHERE event_type = 'purchase' AND user_id % 2 = 1
GROUP BY event_date, category;

-- Trước merge: số dòng thô vs số khóa
SELECT count() AS raw_rows,
    uniqExact(event_date, category) AS distinct_keys
FROM shop.sum_daily_category;

-- Query đúng: luôn sum() lại
SELECT event_date, category,
    sum(revenue) AS revenue,
    sum(quantity) AS quantity,
    sum(purchases) AS purchases
FROM shop.sum_daily_category
GROUP BY event_date, category
ORDER BY event_date DESC, revenue DESC
LIMIT 20;

-- Ép merge rồi đếm lại: raw_rows = distinct_keys
OPTIMIZE TABLE shop.sum_daily_category FINAL;

SELECT
    count() AS raw_rows_after_merge,
    uniqExact(event_date, category) AS distinct_keys
FROM shop.sum_daily_category;


-- ### Bài 81 — CollapsingMergeTree đảo trạng thái (Hard)
-- Dùng `CollapsingMergeTree(sign)` để theo dõi số lượng tồn kho (ghi +1/-1).
-- > **Gợi ý:** Cột `sign Int8`; `sum(sign * qty)` cho tồn hiện tại. Bản ghi sign=1 và sign=-1 triệt tiêu khi merge.
--

CREATE TABLE IF NOT EXISTS shop.demo_inventory_collapsing (
    product_id UInt64,
    warehouse LowCardinality(String),
    qty Int32,
    sign Int8
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY (product_id, warehouse);

TRUNCATE TABLE shop.demo_inventory_collapsing;

-- Trạng thái ban đầu
INSERT INTO shop.demo_inventory_collapsing VALUES (1, 'HN', 100, 1), (1, 'HCM', 50, 1), (2, 'HN', 30, 1);
-- Bán 20 sp 1 ở HN: hủy dòng cũ (100) + ghi dòng mới (80)
INSERT INTO shop.demo_inventory_collapsing VALUES (1, 'HN', 100, -1), (1, 'HN', 80, 1);
-- Ngừng kinh doanh sp 2 ở HN: chỉ hủy, không ghi mới
INSERT INTO shop.demo_inventory_collapsing VALUES (2, 'HN', 30, -1);

-- Dữ liệu thô (chưa merge): còn đủ mọi dòng
SELECT * FROM shop.demo_inventory_collapsing ORDER BY product_id, warehouse, sign DESC;

-- Tồn kho hiện tại — đúng bất kể đã merge chưa
SELECT
    product_id,
    warehouse,
    sum(qty * sign) AS current_qty
FROM shop.demo_inventory_collapsing
GROUP BY product_id, warehouse
HAVING sum(sign) > 0
ORDER BY product_id, warehouse;


-- ### Bài 82 — VersionedCollapsingMergeTree (Hard)
-- Giải thích khác biệt với Collapsing khi dữ liệu đến không đúng thứ tự, viết query tổng.
-- > **Gợi ý:** Thêm cột `version`; engine dùng version để collapse đúng dù insert lệch thứ tự. Query vẫn `sum(sign * metric)`.
--
CREATE TABLE IF NOT EXISTS shop.demo_inventory_versioned (
    product_id UInt64,
    warehouse LowCardinality(String),
    qty Int32,
    sign Int8,
    version UInt32
)
ENGINE = VersionedCollapsingMergeTree(sign, version)
ORDER BY (product_id, warehouse);

TRUNCATE TABLE shop.demo_inventory_versioned;

-- Dòng hủy đến TRƯỚC (lệch thứ tự)
INSERT INTO shop.demo_inventory_versioned VALUES (1, 'HN', 100, -1, 1), (1, 'HN', 80, 1, 2);
-- Dòng gốc đến SAU
INSERT INTO shop.demo_inventory_versioned VALUES (1, 'HN', 100, 1, 1);

-- Query tổng: đúng ngay cả trước merge
SELECT product_id, warehouse,
    sum(qty * sign) AS current_qty
FROM shop.demo_inventory_versioned
GROUP BY product_id, warehouse
HAVING sum(sign) > 0;

-- Ép merge: cặp version 1 bị triệt tiêu, chỉ còn (80, +1, version 2)
OPTIMIZE TABLE shop.demo_inventory_versioned FINAL;
SELECT * FROM shop.demo_inventory_versioned;


-- ### Bài 83 — Deduplicate theo khóa logic (Medium)
-- Trong một bảng có bản ghi trùng, lấy duy nhất 1 dòng mỗi `event_id` (mới nhất).
-- > **Gợi ý:** `LIMIT 1 BY event_id` sau khi `ORDER BY event_time DESC`. `LIMIT BY` là đặc thù ClickHouse.
--
WITH dup AS (
    SELECT event_id, user_id, event_type, event_time, 'v1' AS copy
    FROM shop.events
    WHERE user_id <= 50
    UNION ALL
    SELECT event_id, user_id, event_type, event_time + 60, 'v2'
    FROM shop.events
    WHERE user_id <= 50 AND cityHash64(event_id) % 3 = 0
)
SELECT
    (SELECT count() FROM dup) AS total_rows,
    (SELECT uniqExact(event_id) FROM dup) AS distinct_event_ids,
    (SELECT count() FROM (SELECT event_id FROM dup ORDER BY event_id, event_time DESC LIMIT 1 BY event_id)) AS rows_after_dedup;

-- Xem dữ liệu sau dedup
WITH dup AS (
    SELECT event_id, user_id, event_type, event_time, 'v1' AS copy
    FROM shop.events
    WHERE user_id <= 50
    UNION ALL
    SELECT event_id, user_id, event_type, event_time + 60, 'v2'
    FROM shop.events
    WHERE user_id <= 50 AND cityHash64(event_id) % 3 = 0
)
SELECT *
FROM dup
ORDER BY event_id, event_time DESC
LIMIT 1 BY event_id
LIMIT 20;


-- ### Bài 84 — LIMIT BY lấy top-N mỗi nhóm (Medium)
-- Lấy 2 sự kiện gần nhất của mỗi user.
-- > **Gợi ý:** `ORDER BY event_time DESC LIMIT 2 BY user_id`.
SELECT user_id, event_time, event_type, product_id
FROM shop.events
WHERE user_id <= 20
ORDER BY user_id, event_time DESC
LIMIT 2 BY user_id;

