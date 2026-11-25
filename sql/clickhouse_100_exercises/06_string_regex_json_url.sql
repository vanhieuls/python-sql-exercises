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

