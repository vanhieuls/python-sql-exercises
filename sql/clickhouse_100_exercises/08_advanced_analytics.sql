USE shop;
-- =====================================================================
-- Chủ đề 8 — Phân tích nâng cao & tối ưu (bài 87–100)
-- Quy ước dùng chung cho các bài về doanh thu:
--   • "Đơn có doanh thu" = order_status IN ('paid', 'shipped') — đã trả tiền, chưa hủy/hoàn.
--   • orders là ReplacingMergeTree → đọc qua FINAL để mỗi đơn chỉ lấy bản mới nhất (bài 78–79).
-- =====================================================================

USE shop;
-- ## Chủ đề 8 — Phân tích nâng cao & tối ưu (bài 87–100)

-- ### Bài 87 — RFM segmentation (Hard)
-- Tính Recency, Frequency, Monetary cho mỗi user và chia nhóm ntile.
-- > **Gợi ý:** Recency = `dateDiff('day', max(order_date), today())`; Frequency = `count()`; Monetary = `sum(amount)`. Dùng `ntile(5)` cho mỗi chiều.


-- ### Bài 88 — Customer Lifetime Value theo cohort (Hard)
-- Tính CLV trung bình theo tháng cohort trong 6 tháng đầu.
-- > **Gợi ý:** Cohort theo tháng signup, tổng doanh thu trong 6 tháng đầu / số user cohort.

-- ### Bài 89 — Phân tích giỏ hàng (association) (Hard)
-- Tính support & confidence cho luật "mua A thì mua B".
-- > **Gợi ý:** `count(A&B)/count(all)` = support; `count(A&B)/count(A)` = confidence. Dựa trên self-join cặp sản phẩm (xem bài 31).

-- ### Bài 90 — Phát hiện bất thường bằng z-score (Hard)
-- Tìm ngày có doanh thu lệch > 3 độ lệch chuẩn so với trung bình.
-- > **Gợi ý:** `(revenue - avg(revenue) OVER ()) / stddevPop(revenue) OVER ()`, lọc `abs(z) > 3`.


-- ### Bài 91 — Churn: user không hoạt động 30 ngày (Medium)
-- Đánh dấu user churn nếu đơn/hoạt động gần nhất > 30 ngày.
-- > **Gợi ý:** `max(event_time)` theo user, `dateDiff('day', last, today()) > 30`.

SELECT user_id, last_order_date, date_disctant, date_disctant>30 AS churn
FROM(
    SELECT user_id, max(toDate(created_at)) AS last_order_date,
           dateDiff('day', last_order_date, today()) AS date_disctant
    FROM shop.orders FINAL
    WHERE order_status = 'paid'
    GROUP BY user_id
)
ORDER BY date_disctant DESC
LIMIT 50;


-- ### Bài 92 — A/B test so sánh conversion (Hard)
-- Có cột `variant`, so sánh tỉ lệ purchase giữa nhóm A và B kèm khoảng tin cậy xấp xỉ.
-- > **Gợi ý:** `countIf(purchase)/countDistinct(user)` theo `variant`. CI xấp xỉ bằng công thức tỉ lệ (p±z*sqrt(p(1-p)/n)).

-- ### Bài 93 — Tính tỉ lệ chuyển đổi funnel nhiều bước (Hard)
-- Tính tỉ lệ rớt (drop-off) giữa các bước view→cart→purchase.
-- > **Gợi ý:** Đếm user duy nhất ở mỗi bước (dùng `windowFunnel` ở bài 41), rồi chia bước sau / bước trước.

-- ### Bài 94 — Median theo nhóm hiệu quả (Medium)
-- Trung vị giá trị đơn theo category.
-- > **Gợi ý:** `quantileExact(0.5)(total_amount)` hoặc `median(...)` theo `GROUP BY category`.
SELECT category,
       count() AS purchases,
       round(quantileExact(0.5)(amount),2) AS median_exact,
       round(avg(amount),2) AS mean_value,
       round(median(amount),2) AS median_approx
FROM(
    SELECT category, toFloat64(price*quantity) AS amount
    FROM shop.events
    WHERE event_type = 'purchase'
)
GROUP BY category
ORDER BY category;
-- ### Bài 95 — Sampling để ước lượng nhanh (Hard)
-- Dùng `SAMPLE` để ước lượng doanh thu trung bình trên bảng lớn.
-- > **Gợi ý:** Bảng cần `SAMPLE BY`. `SELECT avg(amount) FROM t SAMPLE 0.1` rồi hiểu kết quả là ước lượng. Không nhân lại cho avg (chỉ nhân cho sum/count).

-- ### Bài 96 — EXPLAIN đọc kế hoạch truy vấn (Hard)
-- Dùng `EXPLAIN` để kiểm tra một query có dùng được index (primary key) không.
-- > **Gợi ý:** `EXPLAIN indexes = 1 SELECT ...` cho biết số granule/part được đọc. Điều kiện phải khớp prefix của `ORDER BY`.

-- ### Bài 97 — PREWHERE tối ưu lọc (Medium)
-- Viết lại query dùng `PREWHERE` để lọc sớm cột rẻ trước khi đọc cột nặng.
-- > **Gợi ý:** `PREWHERE event_type='purchase'` chạy trước, giảm dữ liệu đọc cho các cột khác. ClickHouse đôi khi tự chuyển, nhưng viết tay giúp kiểm soát.
SELECT category, event_type
FROM shop.events
PREWHERE event_type='purchase'
GROUP BY event_type, category
ORDER BY event_type
LIMIT 10;

-- ### Bài 98 — Xấp xỉ top-K bằng topK (Medium)
-- Lấy 10 sản phẩm bán chạy nhất (xấp xỉ, nhanh) bằng `topK`.
-- > **Gợi ý:** `topK(10)(product_id)` trả mảng top xấp xỉ — nhanh hơn `GROUP BY ... ORDER BY count DESC LIMIT 10` trên dữ liệu rất lớn.
SELECT topK(10)(product_id) AS top10_approx
FROM shop.events
WHERE event_type = 'purchase';

-- ### Bài 99 — Correlation giữa 2 chỉ số (Hard)
-- Tính tương quan giữa discount và quantity bán.
-- > **Gợi ý:** Hàm `corr(discount, quantity)`. Có thể kèm `covarPop`, `stddevPop` để tự tính.
SELECT
    count() AS n_orders,
    round(corr(d, q), 5) AS pearson_r,
    round(covarPop(d, q), 5) AS covariance,
    round(stddevPop(d), 4) AS std_discount,
    round(stddevPop(q), 4) AS std_quantity
FROM
(
    SELECT o.order_id AS order_id, toFloat64(o.discount) AS d, toFloat64(i.q) AS q
    FROM (SELECT order_id, discount FROM shop.orders FINAL) AS o
    INNER JOIN
    (
        SELECT order_id, sum(quantity) AS q
        FROM shop.order_items
        GROUP BY order_id
    ) AS i ON o.order_id = i.order_id
);
-- ### Bài 100 — Báo cáo tổng hợp một query (Hard)
-- Dựng một dashboard query: tổng doanh thu, số đơn, số user, AOV, tỉ lệ hoàn, top category — trong một kết quả.
-- > **Gợi ý:** Dùng nhiều hàm `*If`/`uniqExact` trong 1 `SELECT`, kết hợp subquery scalar cho top category (`argMax` theo doanh thu). Kết hợp tất cả kỹ thuật đã học.
WITH
(
    SELECT argMax(tuple(category, rev), rev)
    FROM
    (
        SELECT p.category AS category, sum(oi.unit_price * oi.quantity) AS rev
        FROM shop.order_items AS oi
        INNER JOIN (SELECT order_id FROM shop.orders FINAL WHERE order_status = 'paid') AS o
                   ON oi.order_id = o.order_id
        INNER JOIN shop.products AS p ON oi.product_id = p.product_id
        GROUP BY category
    )
) AS top_cat
SELECT countIf(order_status = 'paid') AS paid_orders,
    sumIf(total_amount, order_status = 'paid') AS revenue,
    uniqExactIf(user_id, order_status = 'paid') AS paying_users,
    round(toFloat64(revenue) / paid_orders, 2) AS aov,
    round(countIf(order_status = 'refunded') / count() * 100, 2) AS refund_rate_pct,
    top_cat.1 AS top_category,
    top_cat.2 AS top_category_revenue
FROM shop.orders FINAL;