from models import Product, Order, Catalog, OrderRepository, OrderStatus, InvalidDiscountError, validate_discount, MovingAverage
from utils import line_total, order_index, order_total, timed, memoize, group_by, pluck, pipe, iter_details, safe_div, format_report

if __name__ == "__main__":
    print("=== KIỂM TRA TOÀN BỘ CÁC BÀI TỪ 61 ĐẾN 80 ===\n")

    # --- Bài 61 & 62: Tính tiền line & order total ---
    detail_test = {"quantity": 2, "unit_price": 50.0, "discount": 10.0}
    print(f"Bài 61 - Line total: {line_total(detail_test)}") # 90.0

    idx = order_index([{"order_id": 1, "quantity": 1, "unit_price": 100}])
    print(f"Bài 62 - Order total: {order_total(1, idx)}") # 100.0

    # --- Bài 63 & 72: Product dataclass & Magic methods ---
    p1 = Product(id=1, category="Tech", unit_price=100, cost=60, discontinued=False, stock=10)
    p2 = Product(id=1, category="Tech", unit_price=120, cost=70, discontinued=False, stock=5)
    print(f"Bài 63 - Margin: {p1.margin}") # 40.0
    print(f"Bài 72 - __eq__ (p1 == p2): {p1 == p2}") # True (vì trùng id=1)

    # --- Bài 64 & 79: Order dataclass & __repr__ ---
    order = Order(id=101, customer_id=5, order_date="2026-03-01", status="paid", shipping_fee=15.0, 
                  detail=[{"quantity": 2, "unit_price": 50.0}])
    print(f"Bài 64 - Order total: {order.total()}") # 115.0
    print(f"Bài 79 - Repr: {order}") # Order(id=101, customer_id=5, status='paid')

    # --- Bài 65: Catalog index ---
    catalog = Catalog([p1])
    print(f"Bài 65 - Catalog get product 1: {catalog.get(1)}")

    # --- Bài 66 & 67: Decorators (timed & memoize) ---
    @memoize
    def expensive_calc(x):
        return x * 2

    print(f"Bài 67 - Memoize: {expensive_calc(5)}")

    # --- Bài 68, 69, 70: Functional utils ---
    items = [{"name": "A", "val": 10}, {"name": "B", "val": 20}]
    print(f"Bài 68 - Group by: {group_by(items, lambda x: x['name'])}")
    print(f"Bài 69 - Pluck: {pluck(items, 'name')}")
    
    pipeline = pipe(lambda x: x + 5, lambda x: x * 2)
    print(f"Bài 70 - Pipe (3 + 5) * 2: {pipeline(3)}") # 16

    # --- Bài 71: OrderRepository ---
    repo = OrderRepository()
    repo.add({"id": 1, "customer_id": 10, "status": "pending"})
    print(f"Bài 71 - Repo find by customer: {repo.find_by_customer(10)}")

    # --- Bài 73: Generator iter_details ---
    details_dict = {1: [{"item": "A"}, {"item": "B"}]}
    print("Bài 73 - Iter details:", list(iter_details(1, details_dict)))

    # --- Bài 75: Enum OrderStatus ---
    print(f"Bài 75 - Enum status: {OrderStatus.PAID}")

    # --- Bài 76: Custom Exception & Validate ---
    try:
        validate_discount(150)
    except InvalidDiscountError as e:
        print(f"Bài 76 - Bắt lỗi thành công: {e}")

    # --- Bài 77: Safe division ---
    print(f"Bài 77 - Safe div (5/0): {safe_div(5, 0, default=99.0)}") # 99.0

    # --- Bài 78: MovingAverage ---
    ma = MovingAverage(window=3)
    print(f"Bài 78 - Moving average: {ma.next(10)}, {ma.next(20)}, {ma.next(30)}")

    # --- Bài 80: Singledispatch ---
    print(f"Bài 80 - Format dict: {format_report({'a': 1, 'b': 2})}")
    print(f"Bài 80 - Format list: {format_report([1, 2, 3])}")