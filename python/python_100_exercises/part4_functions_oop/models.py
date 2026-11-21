from dataclasses import dataclass, field 
import string
from collections import defaultdict
from enum import Enum
from collections import deque
#bài 63 + 72
@dataclass
class Product:
    id: int
    category: str
    unit_price: float
    cost:float
    discontinued: bool
    stock: int
    #bai 63 
    @property
    def margin(self) -> float:
        """lợi nhậu đơn vị = giá bán - giá vốn"""
        return self.unit_price-self.cost
    #baif 72
    def __eq__(self, other):
        if not isinstance(other, Product):
            return False
        return self.id == other.id

    def __hash__(self):
        return hash(self.id)
#bài 64 + 79
@dataclass(repr=False)
class Order:
    id: int
    customer_id: int
    order_date: str
    status: str
    shipping_fee: float =0.0
    detail: list[dict] = field(default_factory=list) # ép Python phải tạo danh sách mới mỗi khi có đối tượng mới ra đời
    def total(self, with_shipping: bool = True) -> float:
        goods_total = sum(d["quantity"] * d["unit_price"] * (1 - d.get("discount", 0.0) / 100) for d in self.detail)
        return goods_total + self.shipping_fee
    #bai 79
    def __repr__(self) -> str:
        return f"Order(id={self.id}, customer_id={self.customer_id}, status='{self.status}')"
#bài 65
@dataclass
class Catalog:
    products: list[Product]
    # khai baso thuộc tính âen _index, init=False để ngăn @dataclass tự thêm vào __init__
    _index: dict[int, Product] = field(default_factory = dict, init = False)
    # Tự động chạy sau khi __init__ của dataclass chạy xong
    def __post_init__(self):
        self._index = {p.id: p for p in self.products}
    def get(self, product_id: int) -> Product | None:
        return self._index.get(product_id)

#bài 71
class OrderRepository:
    def __init__(self):
        self._orders = {}                  
        self._by_customer = defaultdict(list) 
        self._by_status = defaultdict(list)   
    def add(self, order: dict):
        """Thêm đơn hàng và tự động cập nhật vào các index."""
        oid = order["id"]
        cid = order["customer_id"]
        status = order["status"]

        self._orders[oid] = order
        self._by_customer[cid].append(order)
        self._by_status[status].append(order)

    def find_by_customer(self, customer_id: int) -> list[dict]:
        return self._by_customer.get(customer_id, [])

    def find_by_status(self, status: str) -> list[dict]:
        return self._by_status.get(status, [])
#bài 75
class OrderStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"

#bài 76
class InvalidDiscountError(Exception):
    """Ngoại lệ khi discount không hợp lệ."""
    pass
def validate_discount(discount: float):
    if not (0 <= discount <= 100):
        raise InvalidDiscountError(f"Giá trị discount ({discount}%) không hợp lệ.")

#bài 78
class MovingAverage:
    def __init__(self, window: int):
        self.window = window
        self.queue = deque(maxlen=window)
        self._sum = 0.0

    def next(self, val: float)->float:
        if len(self.queue) == self.window:
            self._sum -= self.queue[0]
        self.queue.append(val)
        self._sum += val
        return self._sum / len(self.queue)  
    