# Query B
CREATE DATABASE IF NOT EXISTS shop;
USE shop;

CREATE TABLE shop.events
(
    event_id    UUID,
    user_id     UInt64,
    session_id  UInt64,
    event_type  LowCardinality(String),
    product_id  UInt64,
    category    LowCardinality(String),
    country     LowCardinality(String),
    device      LowCardinality(String),
    price       Decimal(18, 2),
    quantity    UInt32,
    event_time  DateTime,
    event_date  Date DEFAULT toDate(event_time)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_type, event_time, user_id);

CREATE TABLE shop.orders
(
    order_id     UInt64,
    user_id      UInt64,
    order_status LowCardinality(String),
    total_amount Decimal(18, 2),
    discount     Decimal(18, 2),
    country      LowCardinality(String),
    created_at   DateTime,
    updated_at   DateTime
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (order_id);

CREATE TABLE shop.order_items
(
    order_id   UInt64,
    product_id UInt64,
    unit_price Decimal(18, 2),
    quantity   UInt32
)
ENGINE = MergeTree
ORDER BY (order_id, product_id);

CREATE TABLE shop.products
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

CREATE TABLE shop.users
(
    user_id     UInt64,
    signup_date Date,
    country     LowCardinality(String),
    plan        LowCardinality(String),
    is_active   UInt8
)
ENGINE = MergeTree
ORDER BY (user_id);

CREATE TABLE shop.access_logs
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

INSERT INTO shop.products
SELECT
    number + 1                                                      AS product_id,
    concat('Product ', toString(number + 1))                        AS name,
    arrayElement(['electronics','fashion','home','books','toys','sports'], number % 6 + 1) AS category,
    arrayElement(['BrandA','BrandB','BrandC','BrandD','BrandE'], number % 5 + 1)           AS brand,
    toDecimal64(10 + (number % 50) * 3, 2)                          AS cost,
    toDecimal64((10 + (number % 50) * 3) * 1.5, 2)                  AS list_price,
    now() - toIntervalDay(rand() % 700)                             AS created_at
FROM numbers(1000);

INSERT INTO shop.users
SELECT
    number + 1,
    toDate('2023-01-01') + toIntervalDay(rand() % 1000),
    arrayElement(['VN','US','JP','SG','TH','KR','DE'], rand() % 7 + 1),
    multiIf(number % 10 < 7, 'free', number % 10 < 9, 'pro', 'enterprise'),
    if(rand() % 10 < 8, 1, 0)
FROM numbers(100000);

INSERT INTO shop.events
    (event_id, user_id, session_id, event_type, product_id, category,
     country, device, price, quantity, event_time)
SELECT
    generateUUIDv4(),
    user_id,
    user_id * 10 + r_sess,
    multiIf(r_type < 60, 'view', r_type < 80, 'click', r_type < 92, 'add_to_cart', 'purchase'),
    product_id,
    arrayElement(['electronics','fashion','home','books','toys','sports'], (product_id - 1) % 6 + 1),
    arrayElement(['VN','US','JP','SG','TH'], r_country % 5 + 1),
    multiIf(r_dev < 60, 'mobile', r_dev < 90, 'desktop', 'tablet'),
    toDecimal64((10 + ((product_id - 1) % 50) * 3) * 1.5, 2),
    toUInt32(rand() % 3 + 1),
    event_time
FROM
(
    SELECT
        rand() % 100000 + 1                          AS user_id,
        rand() % 1000 + 1                            AS product_id,
        rand() % 100                                 AS r_type,
        rand() % 100                                 AS r_dev,
        rand() % 100                                 AS r_country,
        rand() % 5                                   AS r_sess,
        now() - toIntervalSecond(rand() % (86400 * 180)) AS event_time
    FROM numbers(5000000)
);

INSERT INTO shop.orders
SELECT
    number + 1                                                       AS order_id,
    rand() % 100000 + 1                                              AS user_id,
    multiIf(r < 10, 'created', r < 65, 'paid', r < 85, 'shipped', r < 95, 'cancelled', 'refunded') AS order_status,
    toDecimal64(5 + rand() % 50000 / 100, 2)                         AS total_amount,
    toDecimal64(rand() % 1000 / 100, 2)                              AS discount,
    arrayElement(['VN','US','JP','SG','TH'], rand() % 5 + 1)         AS country,
    created_at,
    created_at + toIntervalSecond(rand() % 86400)                    AS updated_at
FROM
(
    SELECT
        number,
        rand() % 100 AS r,
        now() - toIntervalSecond(rand() % (86400 * 180)) AS created_at
    FROM numbers(1000000)
);

INSERT INTO shop.order_items
SELECT order_id, product_id, unit_price, quantity
FROM
(
    SELECT
        order_id,
        arrayJoin(range(1 + order_id % 4))                              AS k,
        (order_id * 7 + k * 131) % 1000 + 1                             AS product_id,
        toDecimal64((10 + ((product_id - 1) % 50) * 3) * 1.5, 2)        AS unit_price,
        toUInt32(1 + (order_id + k) % 3)                                AS quantity
    FROM shop.orders
);

INSERT INTO shop.access_logs
SELECT
    now() - toIntervalSecond(rand() % (86400 * 7)),
    toIPv4(rand()),
    arrayElement(['GET','POST','PUT','DELETE'], multiIf(r_m < 70, 1, r_m < 90, 2, r_m < 97, 3, 4)),
    arrayElement(['/','/login','/products','/cart','/checkout','/api/v1/items','/api/v1/orders','/search'], rand() % 8 + 1),
    multiIf(r_s < 85, 200, r_s < 90, 301, r_s < 95, 404, r_s < 98, 500, 503),
    rand() % 100000,
    toUInt32(20 + rand() % 200 + if(rand() % 100 < 3, rand() % 3000, 0)),
    arrayElement(['Mozilla/5.0 (Windows NT 10.0)', 'Mozilla/5.0 (iPhone)', 'Mozilla/5.0 (Macintosh)', 'curl/8.0', 'Googlebot/2.1'], rand() % 5 + 1)
FROM
(
    SELECT rand() % 100 AS r_m, rand() % 100 AS r_s
    FROM numbers(2000000)
);

SELECT 'events'      AS tbl, count() AS rows FROM shop.events
UNION ALL SELECT 'orders',      count() FROM shop.orders
UNION ALL SELECT 'order_items', count() FROM shop.order_items
UNION ALL SELECT 'products',    count() FROM shop.products
UNION ALL SELECT 'users',       count() FROM shop.users
UNION ALL SELECT 'access_logs', count() FROM shop.access_logs;



