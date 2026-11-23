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
