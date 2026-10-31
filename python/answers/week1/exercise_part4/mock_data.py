customers = [
    {"id": 1, "name": "Nguyễn Văn An", "email": "an@x.com", "city": "HCM", "tier": 1, "created_at": "2024-01-05T10:00:00"},
    {"id": 2, "name": "Trần Thị Bình", "email": "binh@gmail.com", "city": "HN", "tier": 2, "created_at": "2024-01-10T11:00:00"},
    {"id": 3, "name": "Lê Hoài Nam", "email": "nam@x.com", "city": "HCM", "tier": 1, "created_at": "2024-02-01T09:00:00"},
    {"id": 4, "name": "Phạm Minh Tâm", "email": "tam@yahoo.com", "city": "DN", "tier": 3, "created_at": "2024-02-15T14:00:00"},
    {"id": 5, "name": "Hoàng Thị Hoa", "email": "hoa.ht@gmail.com", "city": "HN", "tier": 2, "created_at": "2024-03-01T08:30:00"},
    {"id": 6, "name": "Vũ Đình Khoa", "email": "khoa_vu@x.com", "city": "HCM", "tier": 1, "created_at": "2024-03-12T15:20:00"},
]

products = [
    {"id": 10, "name": "Bàn phím cơ", "category": "Phụ kiện", "unit_price": 350000, "cost": 200000, "discontinued": False, "stock": 40},
    {"id": 11, "name": "Chuột không dây", "category": "Phụ kiện", "unit_price": 150000, "cost": 90000, "discontinued": False, "stock": 100},
    {"id": 12, "name": "Màn hình cũ", "category": "Màn hình", "unit_price": 2000000, "cost": 1500000, "discontinued": True, "stock": 0},
    {"id": 13, "name": "Tai nghe gaming", "category": "Phụ kiện", "unit_price": 500000, "cost": 300000, "discontinued": False, "stock": 25},
    {"id": 14, "name": "Laptop văn phòng", "category": "Laptop", "unit_price": 12000000, "cost": 9500000, "discontinued": False, "stock": 10},
    {"id": 15, "name": "Ghế công thái học", "category": "Nội thất", "unit_price": 3000000, "cost": 2100000, "discontinued": False, "stock": 15},
]

orders = [
    {"id": 100, "customer_id": 1, "order_date": "2024-06-01T09:00:00", "status": "paid", "shipped_date": "2024-06-03T09:00:00", "shipping_fee": 20000, "payment_method": "card"},
    {"id": 101, "customer_id": 2, "order_date": "2024-06-02T10:00:00", "status": "pending", "shipped_date": None, "shipping_fee": 30000, "payment_method": "cash"},
    {"id": 102, "customer_id": 1, "order_date": "2024-06-05T08:30:00", "status": "paid", "shipped_date": "2024-06-06T12:00:00", "shipping_fee": 20000, "payment_method": "card"},
    {"id": 103, "customer_id": 3, "order_date": "2024-06-10T14:15:00", "status": "shipped", "shipped_date": "2024-06-12T10:00:00", "shipping_fee": 50000, "payment_method": "card"},
    {"id": 104, "customer_id": 5, "order_date": "2024-06-11T16:00:00", "status": "cancelled", "shipped_date": None, "shipping_fee": 0, "payment_method": "cash"},
]

order_details = [
    {"order_id": 100, "product_id": 10, "quantity": 2, "unit_price": 350000, "discount": 10.0},
    {"order_id": 100, "product_id": 11, "quantity": 1, "unit_price": 150000, "discount": 0.0},
    {"order_id": 101, "product_id": 13, "quantity": 1, "unit_price": 500000, "discount": 5.0},
    {"order_id": 102, "product_id": 10, "quantity": 1, "unit_price": 350000, "discount": 5.0},
    {"order_id": 103, "product_id": 14, "quantity": 1, "unit_price": 12000000, "discount": 10.0},
    {"order_id": 103, "product_id": 15, "quantity": 2, "unit_price": 3000000, "discount": 0.0},
    {"order_id": 104, "product_id": 11, "quantity": 3, "unit_price": 150000, "discount": 0.0},
]