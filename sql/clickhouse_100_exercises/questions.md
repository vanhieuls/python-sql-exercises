# 100 Bài Tập SQL trên ClickHouse

> Tập hợp 100 bài tập SQL dành cho ClickHouse, chia theo nhiều chủ đề. Mỗi bài gồm: **Đề bài**, **Độ khó** (Medium / Hard), và **Gợi ý cho junior**.
>
> Các bài giả định một schema thương mại điện tử / logs phổ biến. Bạn có thể tự tạo bảng mẫu theo mô tả trong phần "Schema tham khảo" bên dưới. Cú pháp tập trung vào đặc thù ClickHouse (các hàm `*State`/`*Merge`, `arrayJoin`, `GROUP BY ... WITH ROLLUP/CUBE`, `ASOF JOIN`, `window functions`, `uniqExact`, `quantile`, `argMax`, ...).

---

## Schema tham khảo

```sql
-- Sự kiện người dùng (clickstream)
CREATE TABLE events
(
    event_id    UUID,
    user_id     UInt64,
    session_id  UInt64,
    event_type  LowCardinality(String),   -- 'view', 'add_to_cart', 'purchase', 'click'
    product_id  UInt64,
    category    LowCardinality(String),
    country     LowCardinality(String),
    device      LowCardinality(String),   -- 'mobile', 'desktop', 'tablet'
    price       Decimal(18, 2),
    quantity    UInt32,
    event_time  DateTime,
    event_date  Date DEFAULT toDate(event_time)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_type, event_time, user_id);

-- Đơn hàng
CREATE TABLE orders
(
    order_id     UInt64,
    user_id      UInt64,
    order_status LowCardinality(String),  -- 'created', 'paid', 'shipped', 'cancelled', 'refunded'
    total_amount Decimal(18, 2),
    discount     Decimal(18, 2),
    country      LowCardinality(String),
    created_at   DateTime,
    updated_at   DateTime
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (order_id);

-- Chi tiết đơn hàng
CREATE TABLE order_items
(
    order_id   UInt64,
    product_id UInt64,
    unit_price Decimal(18, 2),
    quantity   UInt32
)
ENGINE = MergeTree
ORDER BY (order_id, product_id);

-- Sản phẩm
CREATE TABLE products
(
    product_id UInt64,
    name       String,
    category   LowCardinality(String),
    brand      LowCardinality(String),
    cost       Decimal(18, 2),
    list_price Decimal(18, 2),
    created_at DateTime
)
ENGINE = MergeTree
ORDER BY (product_id);

-- Người dùng
CREATE TABLE users
(
    user_id      UInt64,
    signup_date  Date,
    country      LowCardinality(String),
    plan         LowCardinality(String),  -- 'free', 'pro', 'enterprise'
    is_active    UInt8
)
ENGINE = MergeTree
ORDER BY (user_id);

-- Log truy cập web server (text/ad-hoc)
CREATE TABLE access_logs
(
    ts          DateTime,
    ip          IPv4,
    method      LowCardinality(String),
    path        String,
    status_code UInt16,
    bytes_sent  UInt64,
    response_ms UInt32,
    user_agent  String
)
ENGINE = MergeTree
PARTITION BY toDate(ts)
ORDER BY (ts);
```

---

## Chủ đề 1 — Aggregation & GROUP BY nâng cao (bài 1–12)

### Bài 1 — Doanh thu theo danh mục và quốc gia (Medium)
Tính tổng doanh thu (`price * quantity`) của các sự kiện `purchase`, nhóm theo `category` và `country`, sắp xếp giảm dần theo doanh thu, lấy top 20.
> **Gợi ý:** Lọc `event_type = 'purchase'` trong `WHERE`. Dùng `sum(price * quantity)`. Nhóm hai cột trong `GROUP BY`. Dùng `ORDER BY ... DESC LIMIT 20`.

### Bài 2 — Subtotal với WITH ROLLUP (Medium)
Tính doanh thu theo `country` và `category`, đồng thời có dòng tổng phụ (subtotal) cho từng `country` và một dòng tổng chung.
> **Gợi ý:** Thêm `WITH ROLLUP` sau `GROUP BY country, category`. Các dòng subtotal có giá trị `category` rỗng/0; dùng hàm như `if` để gán nhãn "ALL" cho dễ đọc.

### Bài 3 — Ma trận tổng với WITH CUBE (Medium)
Tạo báo cáo đa chiều: tổng doanh thu cho mọi tổ hợp con của (`country`, `device`, `category`).
> **Gợi ý:** Dùng `GROUP BY country, device, category WITH CUBE`. CUBE sinh tất cả tổ hợp con, khác ROLLUP (chỉ theo thứ tự phân cấp).

### Bài 4 — Số người dùng duy nhất chính xác vs xấp xỉ (Medium)
So sánh số user duy nhất theo ngày bằng `uniqExact`, `uniq` và `uniqHLL12`. Hiển thị 3 cột trong cùng một query.
> **Gợi ý:** `uniqExact(user_id)` chính xác nhưng tốn RAM; `uniq(user_id)` xấp xỉ nhanh; `uniqHLL12` dùng HyperLogLog. Nhóm theo `event_date`.

### Bài 5 — Doanh thu và AOV theo ngày (Medium)
Tính doanh thu hàng ngày và giá trị đơn trung bình (AOV = tổng doanh thu / số đơn) từ bảng `orders` trạng thái `paid`.
> **Gợi ý:** `sum(total_amount)` và `sum(total_amount) / count()`. Lọc `order_status = 'paid'`. Nhóm theo `toDate(created_at)`.

### Bài 6 — Top sản phẩm theo từng danh mục (Hard)
Với mỗi `category`, tìm 3 sản phẩm có doanh thu cao nhất.
> **Gợi ý:** Dùng window function `row_number() OVER (PARTITION BY category ORDER BY revenue DESC)` trong subquery, sau đó lọc `rn <= 3`. Hoặc dùng `arrayJoin` kết hợp `groupArray` + `arraySlice`.

### Bài 7 — argMax để lấy giá trị kèm theo (Medium)
Với mỗi `user_id`, tìm `product_id` của sự kiện `purchase` gần nhất (theo `event_time`).
> **Gợi ý:** `argMax(product_id, event_time)` trả về `product_id` ứng với `event_time` lớn nhất. Không cần self-join.

### Bài 8 — Phân phối phân vị response time (Medium)
Từ `access_logs`, tính p50, p90, p95, p99 của `response_ms` theo từng giờ.
> **Gợi ý:** `quantile(0.5)(response_ms)`, hoặc `quantiles(0.5, 0.9, 0.95, 0.99)(response_ms)` trả về mảng. Nhóm theo `toStartOfHour(ts)`.
### Bài 9 — Tỉ lệ đóng góp doanh thu (share) (Hard)
Tính doanh thu từng `category` và % đóng góp của nó trên tổng doanh thu toàn hệ thống.
> **Gợi ý:** Dùng window `sum(revenue) OVER ()` làm mẫu số, hoặc `CROSS JOIN` với subquery tính tổng. `revenue / total * 100`.

### Bài 10 — Đếm có điều kiện (conditional aggregation) (Medium)
Trong một query, đếm số sự kiện `view`, `add_to_cart`, `purchase` thành 3 cột riêng, nhóm theo `event_date`.
> **Gợi ý:** `countIf(event_type = 'view')`, `countIf(event_type = 'add_to_cart')`, ... Đây là pivot thủ công bằng `*If`.

### Bài 11 — Doanh thu trung bình có trọng số (Hard)
Tính giá bán trung bình có trọng số theo `quantity` cho mỗi `category` (weighted average price).
> **Gợi ý:** `sum(price * quantity) / sum(quantity)`. Không dùng `avg(price)` vì bỏ qua số lượng.

### Bài 12 — groupArray và sort trong mảng (Hard)
Với mỗi `user_id`, lấy mảng các `product_id` đã mua, sắp xếp theo thời gian mua tăng dần, loại trùng.
> **Gợi ý:** `groupArray(product_id)` kết hợp sắp xếp qua `arraySort`/`arrayDistinct`, hoặc dùng `groupArray` trên subquery đã `ORDER BY event_time`. Chú ý ClickHouse không đảm bảo thứ tự trong `groupArray` nếu không sắp xếp trước.

---

## Chủ đề 2 — Window Functions (bài 13–26)

### Bài 13 — Running total doanh thu (Medium)
Tính doanh thu lũy kế theo ngày (cumulative sum).
> **Gợi ý:** `sum(daily_revenue) OVER (ORDER BY day ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`. Tính `daily_revenue` ở subquery trước.

### Bài 14 — Moving average 7 ngày (Medium)
Tính trung bình trượt 7 ngày của số đơn hàng mỗi ngày.
> **Gợi ý:** `avg(order_count) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)`.

### Bài 15 — So sánh với ngày trước (lag) (Medium)
Tính % tăng trưởng doanh thu ngày so với ngày liền trước.
> **Gợi ý:** `lag(revenue) OVER (ORDER BY day)` hoặc `lagInFrame`. Tính `(today - yesterday) / yesterday * 100`. Cẩn thận chia cho 0.

### Bài 16 — Xếp hạng user theo chi tiêu (Medium)
Xếp hạng user theo tổng chi tiêu dùng `rank`, `dense_rank`, `row_number` — hiển thị cả 3 để thấy khác biệt.
> **Gợi ý:** `rank()` để lại khoảng trống khi đồng hạng, `dense_rank()` không, `row_number()` luôn duy nhất. `OVER (ORDER BY total_spent DESC)`.

### Bài 17 — Phần trăm tích lũy (percent of running total) (Hard)
Xếp sản phẩm theo doanh thu giảm dần và tính % lũy kế để phân tích Pareto (80/20).
> **Gợi ý:** Running sum chia cho tổng: `sum(rev) OVER (ORDER BY rev DESC) / sum(rev) OVER ()`. Lọc ngưỡng 80% để tìm nhóm sản phẩm chủ lực.

### Bài 18 — First/last value trong phiên (Hard)
Với mỗi `session_id`, tìm trang/sự kiện đầu tiên và cuối cùng của phiên.
> **Gợi ý:** `first_value(event_type) OVER (PARTITION BY session_id ORDER BY event_time)` và `last_value(...)` với frame `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. Chú ý frame mặc định của `last_value`.

### Bài 19 — Khoảng cách thời gian giữa 2 sự kiện (Medium)
Tính số giây giữa mỗi sự kiện và sự kiện trước đó của cùng user.
> **Gợi ý:** `event_time - lagInFrame(event_time) OVER (PARTITION BY user_id ORDER BY event_time)`, rồi `dateDiff('second', ...)` hoặc trừ trực tiếp `DateTime`.

### Bài 20 — Ntile phân nhóm user (Medium)
Chia user thành 10 nhóm (decile) theo tổng chi tiêu.
> **Gợi ý:** `ntile(10) OVER (ORDER BY total_spent DESC)`. Mỗi nhóm ~10% user.

### Bài 21 — Số phiên đồng thời (sessionization) (Hard)
Xác định ranh giới phiên mới khi khoảng cách giữa 2 sự kiện của cùng user > 30 phút, đánh số phiên.
> **Gợi ý:** Dùng `lag` để lấy thời gian trước, tạo cờ `new_session = gap > 1800`, rồi `sum(new_session) OVER (PARTITION BY user_id ORDER BY event_time)` làm session index.

### Bài 22 — Streak đăng nhập liên tiếp (Hard)
Tìm chuỗi ngày hoạt động liên tiếp dài nhất của mỗi user.
> **Gợi ý:** Kỹ thuật "gaps and islands": `date - toIntervalDay(row_number() OVER (PARTITION BY user_id ORDER BY date))` tạo khóa nhóm cho các ngày liên tiếp, rồi đếm theo nhóm.

### Bài 23 — Top-N thay đổi theo thời gian (Hard)
Với mỗi tháng, tìm category có doanh thu cao nhất và so sánh với tháng trước.
> **Gợi ý:** Window `argMax`/`row_number` theo tháng, rồi `lag` để lấy category tháng trước. Nhiều tầng subquery.

### Bài 24 — Chênh lệch so với trung bình nhóm (Medium)
So sánh giá mỗi sản phẩm với giá trung bình của category nó thuộc.
> **Gợi ý:** `list_price - avg(list_price) OVER (PARTITION BY category)`.

### Bài 25 — Running distinct count xấp xỉ (Hard)
Số user duy nhất lũy kế theo ngày (approx).
> **Gợi ý:** ClickHouse không có `count(distinct) OVER`. Dùng trick: tính `uniqState` theo ngày rồi merge lũy kế, hoặc tính ngày first_seen của mỗi user rồi cộng dồn số user mới. Cách thứ hai đơn giản hơn cho junior.

### Bài 26 — Lead để dự đoán sự kiện kế tiếp (Medium)
Với mỗi sự kiện `view`, xác định sự kiện kế tiếp của cùng user có phải `purchase` không.
> **Gợi ý:** `leadInFrame(event_type) OVER (PARTITION BY user_id ORDER BY event_time)`, so sánh `= 'purchase'`.

---

## Chủ đề 3 — JOIN & ASOF JOIN (bài 27–38)

### Bài 27 — Join đơn hàng với chi tiết (Medium)
Nối `orders` với `order_items` để tính tổng số lượng sản phẩm mỗi đơn, đối chiếu với `total_amount`.
> **Gợi ý:** `INNER JOIN order_items USING (order_id)`, rồi `GROUP BY order_id`.

### Bài 28 — Lợi nhuận gộp theo sản phẩm (Medium)
Nối `order_items` với `products` để tính lợi nhuận = `(unit_price - cost) * quantity`.
> **Gợi ý:** JOIN theo `product_id`, dùng `cost` từ bảng `products`. `sum((unit_price - cost) * quantity)`.

### Bài 29 — User chưa từng mua (anti join) (Medium)
Tìm user có trong `users` nhưng không có đơn `paid` nào.
> **Gợi ý:** `LEFT JOIN orders ... WHERE order_id IS NULL`, hoặc `WHERE user_id NOT IN (SELECT user_id FROM orders WHERE order_status='paid')`. ClickHouse có `LEFT ANTI JOIN`.

### Bài 30 — ASOF JOIN khớp giá theo thời điểm (Hard)
Có bảng `price_history(product_id, price, valid_from)`. Với mỗi sự kiện bán, lấy giá hiệu lực tại thời điểm `event_time`.
> **Gợi ý:** `ASOF LEFT JOIN price_history ON e.product_id = p.product_id AND e.event_time >= p.valid_from`. ASOF lấy bản ghi gần nhất thỏa bất đẳng thức cuối.

### Bài 31 — Self join tìm cặp sản phẩm mua chung (Hard)
Tìm các cặp sản phẩm thường xuất hiện cùng trong một đơn (market basket).
> **Gợi ý:** Self join `order_items a JOIN order_items b ON a.order_id = b.order_id AND a.product_id < b.product_id`, rồi `GROUP BY a.product_id, b.product_id COUNT()`. Điều kiện `<` để tránh trùng cặp.

### Bài 32 — Join nhiều bảng dựng báo cáo (Medium)
Nối `orders`, `users`, để báo cáo doanh thu theo `plan` của user và `country`.
> **Gợi ý:** JOIN `orders` với `users USING(user_id)`, group theo `plan, country`.

### Bài 33 — Dictionary thay cho JOIN (Hard)
Giả sử có dictionary `product_dict`. Lấy tên sản phẩm bằng `dictGet` thay vì join bảng.
> **Gợi ý:** `dictGet('product_dict', 'name', toUInt64(product_id))`. Dictionary nhanh hơn JOIN khi tra cứu key-value và nằm trong RAM.

### Bài 34 — Semi join: user có mua category X (Medium)
Tìm user từng mua ít nhất một sản phẩm thuộc category 'electronics'.
> **Gợi ý:** `LEFT SEMI JOIN` hoặc `WHERE user_id IN (SELECT ...)`. SEMI JOIN trả mỗi hàng trái tối đa 1 lần.

### Bài 35 — Join với subquery tổng hợp (Medium)
Hiển thị mỗi đơn kèm tổng chi tiêu toàn thời gian của user đó.
> **Gợi ý:** JOIN `orders` với subquery `(SELECT user_id, sum(total_amount) ... GROUP BY user_id)`.

### Bài 36 — Cross join sinh lịch đầy đủ (Hard)
Tạo báo cáo doanh thu theo ngày cho mọi ngày trong khoảng, kể cả ngày không có đơn (fill gaps).
> **Gợi ý:** Sinh dải ngày bằng `arrayJoin(range(...))` hoặc `numbers()`, `CROSS JOIN` / `LEFT JOIN` với dữ liệu thật. Hoặc dùng `WITH FILL` trong `ORDER BY`.

### Bài 37 — Join phân tán (GLOBAL JOIN) (Hard)
Giải thích và viết query dùng `GLOBAL JOIN` khi bảng phải ở cluster phân tán.
> **Gợi ý:** Trên `Distributed` table, `JOIN` thường phải là `GLOBAL JOIN` để bảng phải được phát tán tới mọi shard. Lưu ý chi phí network.

### Bài 38 — Điền giá trị bị thiếu bằng WITH FILL (Medium)
Doanh thu theo ngày, điền 0 cho ngày trống dùng `ORDER BY day WITH FILL`.
> **Gợi ý:** `ORDER BY day WITH FILL STEP toIntervalDay(1)`. Các cột aggregate sẽ là 0/NULL cho ngày được điền.

---

## Chủ đề 4 — Array & Nested (bài 39–50)

### Bài 39 — arrayJoin bung mảng (Medium)
Giả sử cột `tags Array(String)`. Đếm tần suất mỗi tag.
> **Gợi ý:** `arrayJoin(tags)` biến mỗi phần tử mảng thành 1 hàng, rồi `GROUP BY tag COUNT()`.

### Bài 40 — groupArray gom lịch sử (Medium)
Gom tất cả `event_type` của mỗi session thành một mảng theo thứ tự thời gian.
> **Gợi ý:** Sắp xếp trước trong subquery rồi `groupArray(event_type)`, hoặc `groupArray` + `arraySort` với cặp (time, type).

### Bài 41 — Phân tích funnel bằng windowFunnel (Hard)
Tính số user đi qua các bước view → add_to_cart → purchase trong vòng 1 giờ.
> **Gợi ý:** `windowFunnel(3600)(event_time, event_type='view', event_type='add_to_cart', event_type='purchase')`. Hàm trả về số bước liên tiếp đạt được; `GROUP BY user_id` trước.

### Bài 42 — Retention bằng retention() (Hard)
Tính retention: user active ngày 0 và còn active ngày 1, ngày 7.
> **Gợi ý:** Hàm `retention(cond0, cond1, cond7)` trả mảng 0/1. `sumForEach` / `arraySum` để tổng hợp theo cohort.

### Bài 43 — arrayMap biến đổi phần tử (Medium)
Có mảng `prices Array(Decimal)`, tạo mảng mới đã áp thuế 10%.
> **Gợi ý:** `arrayMap(x -> x * 1.1, prices)`.

### Bài 44 — arrayFilter lọc phần tử (Medium)
Từ mảng `amounts`, chỉ giữ các giá trị > 100 và tính tổng.
> **Gợi ý:** `arraySum(arrayFilter(x -> x > 100, amounts))`.

### Bài 45 — arrayReduce áp dụng aggregate lên mảng (Hard)
Tính trung vị (median) của một mảng số trong từng hàng.
> **Gợi ý:** `arrayReduce('median', amounts)` áp dụng hàm tổng hợp dạng chuỗi tên lên mảng.

### Bài 46 — Nested columns truy vấn song song (Hard)
Với bảng có cột Nested `items.product_id`, `items.qty`, tính tổng qty mỗi hàng.
> **Gợi ý:** Nested thực chất là nhiều mảng song song cùng độ dài. `arraySum(items.qty)`, hoặc `arrayJoin` song song để bung.

### Bài 47 — arrayEnumerate đánh số thứ tự (Medium)
Với mảng sự kiện trong session, gắn số thứ tự cho từng phần tử.
> **Gợi ý:** `arrayEnumerate(events_arr)` trả `[1,2,3,...]`. Kết hợp `arrayZip` để ghép index với giá trị.

### Bài 48 — sequenceMatch phát hiện mẫu hành vi (Hard)
Tìm user có mẫu hành vi: view rồi purchase mà không add_to_cart ở giữa.
> **Gợi ý:** `sequenceMatch('(?1).*(?2)')(event_time, cond_view, cond_purchase)` kết hợp điều kiện phủ định, hoặc `sequenceCount`. Tham khảo cú pháp pattern của ClickHouse.

### Bài 49 — arrayCumSum lũy kế trong mảng (Medium)
Có mảng doanh thu theo tháng của mỗi user, tính mảng lũy kế.
> **Gợi ý:** `arrayCumSum(monthly_revenue)`.

### Bài 50 — Mảng giao/nhau giữa 2 tập (Hard)
Với 2 mảng sản phẩm của 2 user, tính số sản phẩm chung (Jaccard-like).
> **Gợi ý:** `arrayIntersect(a, b)` rồi `length(...)`. Jaccard = `length(intersect) / length(arrayDistinct(arrayConcat(a,b)))`.

---

## Chủ đề 5 — Thời gian & Chuỗi thời gian (bài 51–62)

### Bài 51 — Nhóm theo khung giờ (Medium)
Đếm sự kiện theo từng khung 15 phút.
> **Gợi ý:** `toStartOfInterval(event_time, INTERVAL 15 MINUTE)`.

### Bài 52 — Doanh thu theo ngày trong tuần (Medium)
Trung bình doanh thu theo thứ trong tuần (Mon..Sun).
> **Gợi ý:** `toDayOfWeek(created_at)` (1=Mon). Nhóm theo đó, `avg`.

### Bài 53 — So sánh cùng kỳ năm trước (YoY) (Hard)
Doanh thu theo tháng năm nay so với cùng tháng năm trước.
> **Gợi ý:** Tính theo `toYYYYMM`, self-join với điều kiện tháng dịch 12, hoặc dùng `lag(revenue, 12)` nếu dữ liệu đủ liên tục.

### Bài 54 — Thời lượng phiên trung bình (Medium)
Tính thời lượng mỗi session (max time - min time) và lấy trung bình.
> **Gợi ý:** `max(event_time) - min(event_time)` theo `session_id`, rồi `avg(duration)`.

### Bài 55 — Giữ chân theo cohort tuần (Hard)
Cohort theo tuần signup, đo tỉ lệ còn active ở tuần thứ N.
> **Gợi ý:** `toStartOfWeek(signup_date)` làm cohort; `dateDiff('week', signup, activity)` làm offset. Pivot bằng `countIf`.

### Bài 56 — Fill time series với WITH FILL STEP (Medium)
Chuỗi doanh thu theo giờ liên tục, điền giờ trống.
> **Gợi ý:** `ORDER BY hour WITH FILL FROM ... TO ... STEP toIntervalHour(1)`.

### Bài 57 — Múi giờ (Medium)
Chuyển `event_time` (UTC) sang giờ Việt Nam rồi nhóm theo ngày địa phương.
> **Gợi ý:** `toTimezone(event_time, 'Asia/Ho_Chi_Minh')` rồi `toDate(...)`.

### Bài 58 — Thời gian tới sự kiện (time to purchase) (Hard)
Với mỗi user, tính thời gian từ signup đến đơn đầu tiên.
> **Gợi ý:** `min(created_at)` theo user, join với `signup_date`, `dateDiff('day', signup_date, first_order)`.

### Bài 59 — Số sự kiện theo rolling window 24h (Hard)
Với mỗi sự kiện, đếm số sự kiện của cùng user trong 24h trước đó.
> **Gợi ý:** Window với `RANGE BETWEEN INTERVAL 24 HOUR PRECEDING AND CURRENT ROW` (nếu hỗ trợ), hoặc self-join theo khoảng thời gian.
### Bài 60 — Phát hiện khoảng trống dữ liệu (data gaps) (Hard)
Tìm các khoảng > 1 giờ không có sự kiện nào trong `access_logs`.
> **Gợi ý:** `lag(ts)` lấy ts trước, lọc `dateDiff('minute', prev, ts) > 60`.

### Bài 61 — Tốc độ tăng trưởng kép (Hard)
Tính CMGR (compound monthly growth rate) doanh thu giữa tháng đầu và cuối.
> **Gợi ý:** Lấy doanh thu tháng đầu/cuối bằng `argMin`/`argMax` theo tháng, công thức `pow(last/first, 1/n) - 1`.

### Bài 62 — Toàn bộ ngày trong khoảng (calendar) (Medium)
Sinh bảng lịch mọi ngày tháng này.
> **Gợi ý:** `SELECT toDate('2024-01-01') + number FROM numbers(31)`.

---

## Chủ đề 6 — Chuỗi, Regex, JSON, URL (bài 63–74)

### Bài 63 — Parse path thành segment (Medium)
Từ `access_logs.path`, tách segment đầu tiên (ví dụ `/api/users` → `api`).
> **Gợi ý:** `splitByChar('/', path)[2]` (index bắt đầu từ 1, phần tử [1] rỗng do dấu `/` đầu).

### Bài 64 — Trích query param từ URL (Hard)
Lấy giá trị tham số `utm_source` từ URL.
> **Gợi ý:** `extractURLParameter(path, 'utm_source')` hoặc regex `extract(path, 'utm_source=([^&]+)')`.

### Bài 65 — Phân loại trình duyệt từ user_agent (Medium)
Phân loại `user_agent` thành 'mobile'/'desktop' bằng khớp chuỗi.
> **Gợi ý:** `multiIf(position(user_agent,'Mobile')>0,'mobile', 'desktop')` hoặc `like`.

### Bài 66 — Regex trích mã đơn (Hard)
Trích mã đơn dạng `ORD-\d+` từ một cột text tự do.
> **Gợi ý:** `extract(text, 'ORD-(\\d+)')` hoặc `extractAll` để lấy nhiều mã.

### Bài 67 — JSON extract (Hard)
Cột `payload String` chứa JSON. Trích trường `amount` kiểu số và `status` kiểu chuỗi.
> **Gợi ý:** `JSONExtractFloat(payload, 'amount')`, `JSONExtractString(payload, 'status')`, hoặc `simpleJSONExtract*` cho JSON phẳng.

### Bài 68 — Đếm từ trong chuỗi (Medium)
Đếm số từ trong một cột mô tả sản phẩm.
> **Gợi ý:** `length(splitByChar(' ', trimBoth(name)))` hoặc `countMatches(name, '\\w+')`.

### Bài 69 — Chuẩn hóa chữ thường + bỏ dấu (Medium)
Chuẩn hóa tên về chữ thường để nhóm không phân biệt hoa thường.
> **Gợi ý:** `lower(name)`. Bỏ khoảng trắng thừa bằng `trimBoth`/`replaceRegexpAll`.

### Bài 70 — Khớp nhiều mẫu cùng lúc (Hard)
Kiểm tra `path` có khớp bất kỳ mẫu nào trong danh sách (multiMatch).
> **Gợi ý:** `multiMatchAny(path, ['^/api', '^/admin', 'login'])` trả 1 nếu khớp ít nhất 1.

### Bài 71 — Tách và pivot CSV trong một cột (Hard)
Cột `csv_tags = 'a,b,c'`, bung thành hàng và đếm.
> **Gợi ý:** `arrayJoin(splitByChar(',', csv_tags))`.

### Bài 72 — Fuzzy/similarity chuỗi (Hard)
Tìm sản phẩm có tên gần giống 'iphone' (ngram distance).
> **Gợi ý:** `ngramDistance(lower(name), 'iphone')` — giá trị nhỏ là gần giống; lọc ngưỡng.

### Bài 73 — Mặt nạ IP / subnet (Medium)
Nhóm `access_logs` theo subnet /24.
> **Gợi ý:** `IPv4NumToString(bitAnd(toUInt32(ip), 0xFFFFFF00))` hoặc `IPv4CIDRToRange`.

### Bài 74 — Thay thế có điều kiện hàng loạt (Medium)
Chuẩn hóa `order_status` cũ sang nhãn mới (map).
> **Gợi ý:** `transform(order_status, ['created','paid'], ['new','completed'], 'other')`.

---

## Chủ đề 7 — Aggregate State, Materialized View, dedup (bài 75–86)

### Bài 75 — uniqState + uniqMerge (Hard)
Giải thích và viết query lưu `uniqState(user_id)` theo ngày rồi merge lại thành tổng theo tháng.
> **Gợi ý:** `uniqState` tạo trạng thái trung gian (dùng trong MV); `uniqMerge` gộp lại. Query đọc từ bảng `AggregatingMergeTree`: `uniqMerge(users_state)`.

### Bài 76 — AggregatingMergeTree MV (Hard)
Viết `CREATE MATERIALIZED VIEW` tổng hợp doanh thu ngày dùng `sumState`.
> **Gợi ý:** MV đích là `AggregatingMergeTree`, cột là `sumState(amount)`. Khi đọc dùng `sumMerge`. MV cập nhật khi insert vào bảng nguồn.

### Bài 77 — quantileState kết hợp nhiều phần (Hard)
Lưu `quantileState(0.95)(response_ms)` theo giờ, truy vấn p95 theo ngày từ state.
> **Gợi ý:** `quantileState` → `quantileMerge(0.95)`. Không thể trung bình các p95 theo cách thường, phải merge state.

### Bài 78 — Dedup với ReplacingMergeTree (Medium)
`orders` dùng `ReplacingMergeTree(updated_at)`. Viết query lấy bản mới nhất của mỗi đơn an toàn (chưa merge).
> **Gợi ý:** `SELECT ... FROM orders FINAL`, hoặc `argMax(col, updated_at) GROUP BY order_id`. `FINAL` tốn tài nguyên; argMax thường tốt hơn cho query.

### Bài 79 — FINAL vs argMax (Hard)
So sánh kết quả `FROM orders FINAL` và cách dùng `argMax` theo `updated_at`; giải thích khi nào dùng cái nào.
> **Gợi ý:** `FINAL` merge toàn bộ cột tự động nhưng chậm; `argMax` chỉ lấy cột cần, nhanh hơn nhưng phải liệt kê cột thủ công.

### Bài 80 — SummingMergeTree (Medium)
Thiết kế bảng `SummingMergeTree` cộng dồn doanh thu theo (ngày, category) và query tổng.
> **Gợi ý:** `ORDER BY (date, category)`; các cột numeric tự cộng khi merge. Query vẫn nên `sum()` để gộp phần chưa merge.

### Bài 81 — CollapsingMergeTree đảo trạng thái (Hard)
Dùng `CollapsingMergeTree(sign)` để theo dõi số lượng tồn kho (ghi +1/-1).
> **Gợi ý:** Cột `sign Int8`; `sum(sign * qty)` cho tồn hiện tại. Bản ghi sign=1 và sign=-1 triệt tiêu khi merge.

### Bài 82 — VersionedCollapsingMergeTree (Hard)
Giải thích khác biệt với Collapsing khi dữ liệu đến không đúng thứ tự, viết query tổng.
> **Gợi ý:** Thêm cột `version`; engine dùng version để collapse đúng dù insert lệch thứ tự. Query vẫn `sum(sign * metric)`.

### Bài 83 — Deduplicate theo khóa logic (Medium)
Trong một bảng có bản ghi trùng, lấy duy nhất 1 dòng mỗi `event_id` (mới nhất).
> **Gợi ý:** `LIMIT 1 BY event_id` sau khi `ORDER BY event_time DESC`. `LIMIT BY` là đặc thù ClickHouse.

### Bài 84 — LIMIT BY lấy top-N mỗi nhóm (Medium)
Lấy 2 sự kiện gần nhất của mỗi user.
> **Gợi ý:** `ORDER BY event_time DESC LIMIT 2 BY user_id`.

### Bài 85 — Projection tối ưu truy vấn (Hard)
Thêm `PROJECTION` để tăng tốc query group-by theo category; viết query dùng projection.
> **Gợi ý:** `ALTER TABLE ... ADD PROJECTION p (SELECT category, sum(amount) GROUP BY category)`. ClickHouse tự chọn projection khi query khớp.

### Bài 86 — TTL tổng hợp dữ liệu cũ (Hard)
Thiết kế TTL nén dữ liệu cũ hơn 90 ngày thành tổng hợp theo ngày.
> **Gợi ý:** `TTL event_time + INTERVAL 90 DAY GROUP BY toDate(event_time) SET amount = sum(amount)`.

---

## Chủ đề 8 — Phân tích nâng cao & tối ưu (bài 87–100)

### Bài 87 — RFM segmentation (Hard)
Tính Recency, Frequency, Monetary cho mỗi user và chia nhóm ntile.
> **Gợi ý:** Recency = `dateDiff('day', max(order_date), today())`; Frequency = `count()`; Monetary = `sum(amount)`. Dùng `ntile(5)` cho mỗi chiều.

### Bài 88 — Customer Lifetime Value theo cohort (Hard)
Tính CLV trung bình theo tháng cohort trong 6 tháng đầu.
> **Gợi ý:** Cohort theo tháng signup, tổng doanh thu trong 6 tháng đầu / số user cohort.

### Bài 89 — Phân tích giỏ hàng (association) (Hard)
Tính support & confidence cho luật "mua A thì mua B".
> **Gợi ý:** `count(A&B)/count(all)` = support; `count(A&B)/count(A)` = confidence. Dựa trên self-join cặp sản phẩm (xem bài 31).

### Bài 90 — Phát hiện bất thường bằng z-score (Hard)
Tìm ngày có doanh thu lệch > 3 độ lệch chuẩn so với trung bình.
> **Gợi ý:** `(revenue - avg(revenue) OVER ()) / stddevPop(revenue) OVER ()`, lọc `abs(z) > 3`.

### Bài 91 — Churn: user không hoạt động 30 ngày (Medium)
Đánh dấu user churn nếu đơn/hoạt động gần nhất > 30 ngày.
> **Gợi ý:** `max(event_time)` theo user, `dateDiff('day', last, today()) > 30`.

### Bài 92 — A/B test so sánh conversion (Hard)
Có cột `variant`, so sánh tỉ lệ purchase giữa nhóm A và B kèm khoảng tin cậy xấp xỉ.
> **Gợi ý:** `countIf(purchase)/countDistinct(user)` theo `variant`. CI xấp xỉ bằng công thức tỉ lệ (p±z*sqrt(p(1-p)/n)).

### Bài 93 — Tính tỉ lệ chuyển đổi funnel nhiều bước (Hard)
Tính tỉ lệ rớt (drop-off) giữa các bước view→cart→purchase.
> **Gợi ý:** Đếm user duy nhất ở mỗi bước (dùng `windowFunnel` ở bài 41), rồi chia bước sau / bước trước.

### Bài 94 — Median theo nhóm hiệu quả (Medium)
Trung vị giá trị đơn theo category.
> **Gợi ý:** `quantileExact(0.5)(total_amount)` hoặc `median(...)` theo `GROUP BY category`.

### Bài 95 — Sampling để ước lượng nhanh (Hard)
Dùng `SAMPLE` để ước lượng doanh thu trung bình trên bảng lớn.
> **Gợi ý:** Bảng cần `SAMPLE BY`. `SELECT avg(amount) FROM t SAMPLE 0.1` rồi hiểu kết quả là ước lượng. Không nhân lại cho avg (chỉ nhân cho sum/count).

### Bài 96 — EXPLAIN đọc kế hoạch truy vấn (Hard)
Dùng `EXPLAIN` để kiểm tra một query có dùng được index (primary key) không.
> **Gợi ý:** `EXPLAIN indexes = 1 SELECT ...` cho biết số granule/part được đọc. Điều kiện phải khớp prefix của `ORDER BY`.

### Bài 97 — PREWHERE tối ưu lọc (Medium)
Viết lại query dùng `PREWHERE` để lọc sớm cột rẻ trước khi đọc cột nặng.
> **Gợi ý:** `PREWHERE event_type='purchase'` chạy trước, giảm dữ liệu đọc cho các cột khác. ClickHouse đôi khi tự chuyển, nhưng viết tay giúp kiểm soát.

### Bài 98 — Xấp xỉ top-K bằng topK (Medium)
Lấy 10 sản phẩm bán chạy nhất (xấp xỉ, nhanh) bằng `topK`.
> **Gợi ý:** `topK(10)(product_id)` trả mảng top xấp xỉ — nhanh hơn `GROUP BY ... ORDER BY count DESC LIMIT 10` trên dữ liệu rất lớn.

### Bài 99 — Correlation giữa 2 chỉ số (Hard)
Tính tương quan giữa discount và quantity bán.
> **Gợi ý:** Hàm `corr(discount, quantity)`. Có thể kèm `covarPop`, `stddevPop` để tự tính.

### Bài 100 — Báo cáo tổng hợp một query (Hard)
Dựng một dashboard query: tổng doanh thu, số đơn, số user, AOV, tỉ lệ hoàn, top category — trong một kết quả.
> **Gợi ý:** Dùng nhiều hàm `*If`/`uniqExact` trong 1 `SELECT`, kết hợp subquery scalar cho top category (`argMax` theo doanh thu). Kết hợp tất cả kỹ thuật đã học.

---

## Gợi ý lộ trình luyện tập

- **Tuần 1 (Medium nền tảng):** Chủ đề 1, 4, một phần 3 và 5 — nắm chắc aggregation, GROUP BY, JOIN cơ bản, hàm thời gian.
- **Tuần 2 (Window & Array):** Chủ đề 2 và 4 — window functions và thao tác mảng là thế mạnh của ClickHouse.
- **Tuần 3 (Engine & tối ưu):** Chủ đề 7 — hiểu `*State/*Merge`, MergeTree family, FINAL vs argMax.
- **Tuần 4 (Phân tích thực chiến):** Chủ đề 6 và 8 — funnel, retention, RFM, A/B test, EXPLAIN/PREWHERE.

**Mẹo chung cho junior:**
1. Luôn lọc sớm (`WHERE`/`PREWHERE`) để giảm dữ liệu.
2. Ưu tiên hàm xấp xỉ (`uniq`, `quantile`, `topK`) trên dữ liệu lớn khi không cần chính xác tuyệt đối.
3. Tránh lạm dụng `FINAL`; ưu tiên `argMax`/`LIMIT BY`.
4. ClickHouse đánh index mảng từ 1, không phải 0.
5. Đọc `EXPLAIN` khi query chậm để biết có quét thừa part/granule không.













# Query C

```
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
```
