USE shop;


-- ### Bài 51 — Nhóm theo khung giờ (Medium)
-- Đếm sự kiện theo từng khung 15 phút.
-- > **Gợi ý:** `toStartOfInterval(event_time, INTERVAL 15 MINUTE)`.
SELECT toStartOfInterval(event_time, INTERVAL 15 MINUTE) AS slot, count() AS events
FROM shop.events
WHERE event_time >= now() - INTERVAL 20 DAY
GROUP BY slot
ORDER BY slot; 

-- ### Bài 52 — Doanh thu theo ngày trong tuần (Medium)
-- Trung bình doanh thu theo thứ trong tuần (Mon..Sun).
-- > **Gợi ý:** `toDayOfWeek(created_at)` (1=Mon). Nhóm theo đó, `avg`.
SELECT toDayOfWeek(order_date) AS dow,
       ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dow] AS dow_name,
       count(*) AS n_days,
       round(avg(daily_revenue),2) AS avg_revenue_daily 
FROM(
    SELECT toDate(created_at) AS order_date, sum(total_amount) AS daily_revenue
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY order_date
)
GROUP BY dow
ORDER BY dow;

-- ### Bài 53 — So sánh cùng kỳ năm trước (YoY) (Hard)
-- Doanh thu theo tháng năm nay so với cùng tháng năm trước.
-- > **Gợi ý:** Tính theo `toYYYYMM`, self-join với điều kiện tháng dịch 12, hoặc dùng `lag(revenue, 12)` nếu dữ liệu đủ liên tục.
--

--cách 1
WITH monthly AS (
    SELECT toStartOfMonth(created_at) AS month,
    sum(total_amount) AS revenue
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY month
)
SELECT cur.month AS month,
       cur.revenue AS revenue,
       prev.revenue AS revenue_last_year,
       round((toFloat64(cur.revenue)/nullIf(toFloat64(prev.revenue),0)-1)*100,2) AS yoy_pct
FROM monthly AS cur
LEFT JOIN monthly AS prev ON prev.month = addYears(cur.month,-1)
ORDER BY month;

--cách 2
SELECT
    month,
    revenue,
    lagInFrame(revenue, 12, toDecimal64(0, 2)) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS revenue_last_year
FROM
(
    SELECT toStartOfMonth(created_at) AS month, sum(total_amount) AS revenue
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY month
)
ORDER BY month;

-- ### Bài 54 — Thời lượng phiên trung bình (Medium)
-- Tính thời lượng mỗi session (max time - min time) và lấy trung bình.
-- > **Gợi ý:** `max(event_time) - min(event_time)` theo `session_id`, rồi `avg(duration)`.
--
SELECT
    count() AS sessions,
    round(avg(duration_sec)) AS avg_duration_sec    
FROM
(
    SELECT
        session_id,
        count() AS n_events,
        dateDiff('second', min(event_time), max(event_time)) AS duration_sec
    FROM shop.events
    GROUP BY session_id
    HAVING n_events > 1
);

-- ### Bài 55 — Giữ chân theo cohort tuần (Hard)
-- Cohort theo tuần signup, đo tỉ lệ còn active ở tuần thứ N.
-- > **Gợi ý:** `toStartOfWeek(signup_date)` làm cohort; `dateDiff('week', signup, activity)` làm offset. Pivot bằng `countIf`.
--
EXPLAIN PLAN header = 1, indexes = 1
WITH 
    cohort AS (
        SELECT user_id, toStartOfWeek(signup_date, 1) AS cohort_week
        FROM shop.users
    ),
    activity AS (
        SELECT DISTINCT user_id, toStartOfWeek(event_date,1) AS activity_week
        FROM shop.events
    )
SELECT cohort_week, uniq(user_id) AS cohort_size,
       round(uniqExactIf(user_id, week_n=0)/cohort_size*100,2) AS w0,
       round(uniqExactIf(user_id, week_n=1)/cohort_size*100,2) AS w1,
       round(uniqExactIf(user_id, week_n=2)/cohort_size*100,2) AS w2,
       round(uniqExactIf(user_id, week_n=3)/cohort_size*100,2) AS w3,
       round(uniqExactIf(user_id, week_n=4)/cohort_size*100,2) AS w4
FROM(
    SELECT  c.user_id AS user_id, c.cohort_week AS cohort_week, a.activity_week, dateDiff('week', c.cohort_week, a.activity_week) AS week_n
    FROM cohort AS c LEFT JOIN activity AS a ON c.user_id = a.user_id
)
GROUP BY cohort_week
ORDER BY cohort_week;

-- ### Bài 56 — Fill time series với WITH FILL STEP (Medium)
-- Chuỗi doanh thu theo giờ liên tục, điền giờ trống.
-- > **Gợi ý:** `ORDER BY hour WITH FILL FROM ... TO ... STEP toIntervalHour(1)`.
--
SELECT
    toStartOfHour(created_at) AS hour,
    count() AS orders,
    sum(total_amount) AS revenue
FROM shop.orders FINAL
WHERE order_status = 'paid'
  AND created_at >= toStartOfHour(now() - INTERVAL 2 DAY)
GROUP BY hour
ORDER BY hour WITH FILL
    FROM toStartOfHour(now() - INTERVAL 2 DAY)
    TO toStartOfHour(now()) + INTERVAL 1 HOUR
    STEP toIntervalHour(1);

-- ### Bài 57 — Múi giờ (Medium)
-- Chuyển `event_time` (UTC) sang giờ Việt Nam rồi nhóm theo ngày địa phương.
-- > **Gợi ý:** `toTimezone(event_time, 'Asia/Ho_Chi_Minh')` rồi `toDate(...)`.
SELECT
    toDate(toTimezone(event_time, 'Asia/Ho_Chi_Minh')) AS local_date,
    count() AS events
FROM shop.events
GROUP BY local_date
ORDER BY local_date DESC
LIMIT 14;

-- ### Bài 58 — Thời gian tới sự kiện (time to purchase) (Hard)
-- Với mỗi user, tính thời gian từ signup đến đơn đầu tiên.
-- > **Gợi ý:** `min(created_at)` theo user, join với `signup_date`, `dateDiff('day', signup_date, first_order)`.
--
WITH first_order AS (
    SELECT  user_id, min(created_at) AS first_order_at
    FROM shop.orders FINAL
    WHERE order_status != 'cancelled'
    GROUP BY user_id
)
SELECT u.user_id, u.signup_date, fo.first_order_at, dateDiff('day',u.signup_date, fo.first_order_at) AS day_diff
FROM first_order AS fo INNER JOIN shop.users AS u ON u.user_id = fo.user_id
ORDER BY u.user_id
LIMIT 20;

-- ### Bài 59 — Số sự kiện theo rolling window 24h (Hard)
-- Với mỗi sự kiện, đếm số sự kiện của cùng user trong 24h trước đó.
-- > **Gợi ý:** Window với `RANGE BETWEEN INTERVAL 24 HOUR PRECEDING AND CURRENT ROW` (nếu hỗ trợ), hoặc self-join theo khoảng thời gian.
SELECT
    user_id,
    event_time,
    event_type,
    count() OVER (
        PARTITION BY user_id
        ORDER BY event_time
        RANGE BETWEEN 86400 PRECEDING AND CURRENT ROW
    ) - 1 AS events_prev_24h
FROM shop.events
WHERE user_id <= 1000
ORDER BY user_id, event_time
LIMIT 50;

-- ### Bài 60 — Phát hiện khoảng trống dữ liệu (data gaps) (Hard)
-- Tìm các khoảng > 1 giờ không có sự kiện nào trong `access_logs`.
-- > **Gợi ý:** `lag(ts)` lấy ts trước, lọc `dateDiff('minute', prev, ts) > 60`.
--
SELECT
    prev_ts AS gap_start,
    ts AS gap_end,
    dateDiff('minute', prev_ts, ts) AS gap_minutes
FROM
(
    SELECT ts, lagInFrame(ts, 1, toDateTime(0)) OVER (ORDER BY ts ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS prev_ts
    FROM shop.access_logs
)
WHERE prev_ts != toDateTime(0) AND dateDiff('minute', prev_ts, ts) > 60
ORDER BY gap_start;

-- ### Bài 62 — Toàn bộ ngày trong khoảng (calendar) (Medium)
-- Sinh bảng lịch mọi ngày tháng này.
-- > **Gợi ý:** `SELECT toDate('2024-01-01') + number FROM numbers(31)`.
--
SELECT
    toStartOfMonth(today()) + number AS day,
    toDayOfWeek(day) AS dow,
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dow] AS dow_name,
    dow >= 6 AS is_weekend
FROM numbers(toDayOfMonth(toStartOfMonth(today()) + INTERVAL 1 MONTH - INTERVAL 1 DAY))
ORDER BY day;