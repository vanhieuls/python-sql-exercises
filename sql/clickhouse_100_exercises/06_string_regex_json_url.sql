USE shop;

-- =====================================================================
-- Chủ đề 6 — Chuỗi, Regex, JSON, URL (bài 63–74)
-- Một số bài cần cột không có trong schema (utm, text tự do, JSON, csv, tên giống 'iphone').
-- Những bài đó dựng dữ liệu mẫu tại chỗ bằng arrayJoin([...]) để chạy được ngay,
-- sau đó (nếu hợp lý) áp lại cùng kỹ thuật lên bảng thật.
-- Nhắc lại: trong chuỗi SQL của ClickHouse, '\\d' nghĩa là regex \d (phải escape dấu \).
-- =====================================================================


-- ### Bài 63 — Parse path thành segment (Medium)
-- Từ `access_logs.path`, tách segment đầu tiên (ví dụ `/api/users` → `api`).
-- > **Gợi ý:** `splitByChar('/', path)[2]` (index bắt đầu từ 1, phần tử [1] rỗng do dấu `/` đầu).
--

SELECT if(seg = '', '(root)', seg) AS first_segment, count() AS hits
FROM
(
    SELECT splitByChar('/', path)[2] AS seg
    FROM shop.access_logs
)
GROUP BY first_segment
ORDER BY hits DESC;


-- ### Bài 64 — Trích query param từ URL (Hard)
-- Lấy giá trị tham số `utm_source` từ URL.
-- > **Gợi ý:** `extractURLParameter(path, 'utm_source')` hoặc regex `extract(path, 'utm_source=([^&]+)')`.
--

--Không có cột nào chứa query param, mã đơn, JSON, CSV nên sẽ thêm một bảng text_samples vào shop
CREATE TABLE shop.text_samples
(
    id           UInt32,
    url          String,
    note         String,
    payload      String,
    csv_tags     String,
    product_name String
)
ENGINE = MergeTree ORDER BY id;

INSERT INTO shop.text_samples VALUES
(1, '/landing?utm_source=google&utm_medium=cpc',
    'Khach hoi ve don ORD-1001 va ORD-1002',
    '{"amount": 120.5, "status": "paid", "user": {"id": 7}}',
    'sale,new,hot', '  iPhone 15 Pro Max  '),
(2, '/products?utm_medium=email&utm_source=newsletter',
    'Don ORD-2050 bi tre',
    '{"amount": 35, "status": "created"}',
    'new,hot', 'Iphone 14'),
(3, '/search?q=laptop',
    'Khong co ma don',
    '{"amount": 999.99, "status": "refunded"}',
    'sale', 'Samsung Galaxy S24'),
(4, '/cart',
    'ORD-3001,ORD-3002,ORD-3003 giao gop',
    '{"status": "shipped"}',
    'hot,hot,sale', 'iPhoen 13'),
(5, '/landing?utm_source=fb%20ads',
    'ord-4000 viet thuong',
    '{"amount": "15.5", "status": "paid"}',
    '', 'Ốp lưng iPhone');
SELECT *
FROM shop.text_samples
;


SELECT id, url, extractURLParameter(url,'utm_source') AS src_fn, extract(url, 'utm_source=([^&]+)') AS src_regex
FROM shop.text_samples
ORDER BY id;

-- ### Bài 65 — Phân loại trình duyệt từ user_agent (Medium)
-- Phân loại `user_agent` thành 'mobile'/'desktop' bằng khớp chuỗi.
-- > **Gợi ý:** `multiIf(position(user_agent,'Mobile')>0,'mobile', 'desktop')` hoặc `like`.
--
SELECT
    multiIf(position(user_agent, 'Mobile') > 0, 'mobile', 'desktop') AS device_class, count() AS hits
FROM shop.access_logs
GROUP BY device_class;

-- ### Bài 66 — Regex trích mã đơn (Hard)
-- Trích mã đơn dạng `ORD-\d+` từ một cột text tự do.
-- > **Gợi ý:** `extract(text, 'ORD-(\\d+)')` hoặc `extractAll` để lấy nhiều mã.
--
SELECT id, note, 
       extract(note,'ORD-(\\d+)') AS first_code,
       extractAll(note, 'ORD-(\\d+)') AS all_code 
FROM shop.text_samples
ORDER BY id;

-- ### Bài 67 — JSON extract (Hard)
-- Cột `payload String` chứa JSON. Trích trường `amount` kiểu số và `status` kiểu chuỗi.
-- > **Gợi ý:** `JSONExtractFloat(payload, 'amount')`, `JSONExtractString(payload, 'status')`, hoặc `simpleJSONExtract*` cho JSON phẳng.
--
SELECT id, payload, JSONExtractFloat(payload,'amount'), JSONExtractString(payload,'status')
FROM shop.text_samples
ORDER BY id;

-- ### Bài 68 — Đếm từ trong chuỗi (Medium)
-- Đếm số từ trong một cột mô tả sản phẩm.
-- > **Gợi ý:** `length(splitByChar(' ', trimBoth(name)))` hoặc `countMatches(name, '\\w+')`.
--
SELECT
    id, product_name,
    length(splitByChar(' ', trimBoth(product_name)))   AS words_hint,
    countMatches(product_name, '\\w+')                 AS words_regex_ascii -- \w+ trong re2 chỉ khớp ký tự ASCII, nên ví dụ từ Ốp bị cắt còn p, lưng bị cắt thành l và ng
FROM shop.text_samples
ORDER BY id;

-- ### Bài 69 — Chuẩn hóa chữ thường + bỏ dấu (Medium)
-- Chuẩn hóa tên về chữ thường để nhóm không phân biệt hoa thường.
-- > **Gợi ý:** `lower(name)`. Bỏ khoảng trắng thừa bằng `trimBoth`/`replaceRegexpAll`.
--
SELECT product_name,
       lowerUTF8(trimBoth(product_name)) AS s1_lower, --Dùng lowerUTF8 thay vì lower bỏ qua chữ có dấu (Ố giữ nguyên).
       replaceRegexpAll(s1_lower,'\\s+',' ') AS s1_spaces
FROM shop.text_samples
ORDER BY id;

-- ### Bài 70 — Khớp nhiều mẫu cùng lúc (Hard)
-- Kiểm tra `path` có khớp bất kỳ mẫu nào trong danh sách (multiMatch).
-- > **Gợi ý:** `multiMatchAny(path, ['^/api', '^/admin', 'login'])` trả 1 nếu khớp ít nhất 1.
--
SELECT
    multiMatchAny(path, ['^/api', '^/admin', 'login']) AS is_special, count() AS hits
FROM shop.access_logs
GROUP BY is_special;

-- ### Bài 71 — Tách và pivot CSV trong một cột (Hard)
-- Cột `csv_tags = 'a,b,c'`, bung thành hàng và đếm.
-- > **Gợi ý:** `arrayJoin(splitByChar(',', csv_tags))`.
-- 
SELECT tag, count() AS occurrences,
FROM
(
    SELECT id, arrayJoin(splitByChar(',', csv_tags)) AS tag
    FROM shop.text_samples
)
WHERE tag != ''
GROUP BY tag
ORDER BY occurrences DESC, tag;

-- ### Bài 72 — Fuzzy/similarity chuỗi (Hard)
-- Tìm sản phẩm có tên gần giống 'iphone' (ngram distance).
-- > **Gợi ý:** `ngramDistance(lower(name), 'iphone')` — giá trị nhỏ là gần giống; lọc ngưỡng.
--
SELECT
    product_name,
    round(ngramDistanceCaseInsensitiveUTF8(product_name, 'iphone'), 3) AS dist,
    round(ngramSearchCaseInsensitiveUTF8(product_name, 'iphone'), 3)   AS search_score
FROM shop.text_samples
ORDER BY dist;

-- ### Bài 73 — Mặt nạ IP / subnet (Medium)
-- Nhóm `access_logs` theo subnet /24.
-- > **Gợi ý:** `IPv4NumToString(bitAnd(toUInt32(ip), 0xFFFFFF00))` hoặc `IPv4CIDRToRange`.
--
SELECT
    toIPv4('192.168.1.77')                                  AS ip,
    IPv4CIDRToRange(ip, 24)                                 AS range24,
    range24.1                                               AS network_addr,
    range24.2                                               AS broadcast_addr,
    concat(toString(range24.1), '/24')                      AS cidr;
    
-- ### Bài 74 — Thay thế có điều kiện hàng loạt (Medium)
-- Chuẩn hóa `order_status` cũ sang nhãn mới (map).
-- > **Gợi ý:** `transform(order_status, ['created','paid'], ['new','completed'], 'other')`.
--
SELECT
    transform(order_status, ['created', 'paid'], ['new', 'completed'], 'other') AS new_status,
    count() AS orders,
    round(count() / sum(count()) OVER () * 100, 1) AS pct
FROM shop.orders FINAL
GROUP BY new_status
ORDER BY orders DESC;