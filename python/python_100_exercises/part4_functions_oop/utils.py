from collections import defaultdict, Counter, deque
import heapq, time
from functools import wraps
from datetime import datetime, timedelta
from mock_data import customers, products, orders, order_details
from typing import Callable, TypeVar, Hashable
from functools import reduce
from functools import singledispatch

#bài 61
def line_total(detail:dict) -> float:
    quantity = detail["quantity"]
    unit_price = detail["unit_price"]
    discount = detail.get("discount",0.0)
    return quantity*unit_price*(1-discount/100)
#bài 62
def order_index(order_detail: list[dict]) -> dict[int, list[dict]]:
    index = defaultdict(list)
    for detail in order_detail:
        index[detail["order_id"]].append(detail)
    return index
def order_total(order_id:int, order_index:dict[int,list[dict]]) -> float:
    detail = order_index.get(order_id,[])
    return sum(od["quantity"]*od["unit_price"]*(1-od.get("discount",0.0)/100) for od in detail)

#bài 66 
def timed(func):
    #@wraps(func): Giữ lại các thông tin gốc (metadata) của hàm func như tên hàm (__name__) hay tài liệu hướng dẫn (__doc__)
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        result = func(*args, **kwargs)
        end_time = time.perf_counter()
        print(f"[TIMED] Hàm '{func.__name__}' chạy hết: {end_time - start_time:.6f} giây")
        return result
    return wrapper

#bài 67 
def memoize(func):
    cache = {}
    @wraps(func)
    def wrapper(*args):
        if args not in cache:
            cache[args] = func(*args)
        return cache[args]
    return wrapper

#bài 68
K = TypeVar('K', bound=Hashable)
T = TypeVar('T')

def group_by(items: list[T], key_func: Callable[[T], K]) -> dict[K, list[T]]:
    """Gom nhóm danh sách phần tử dựa trên kết quả trả về của key_func."""
    grouped = defaultdict(list)
    for item in items:
        grouped[key_func(item)].append(item)
    return dict(grouped)

#bài 69
def pluck(items: list[dict], field: str) -> list:
    return [item.get(field) for item in items]

#bài 70
def pipe(*funcs):
    """Tạo hàm pipeline thực thi tuần tự các hàm từ trái sang phải."""
    return lambda x: reduce(lambda acc, f: f(acc), funcs, x)

#bài 73
def iter_details(order_id: int, order_details_index: dict[int, list[dict]]):
    details = order_details_index.get(order_id, [])
    for detail in details:
        yield detail

#bài 77
def safe_div(a: float, b: float, default: float = 0.0) -> float:
    try:
        return a / b
    except ZeroDivisionError:
        return default

#bài 80
@singledispatch
def format_report(data) -> str:
    """Hàm gốc xử lý các kiểu dữ liệu mặc định."""
    return f"Default report: {data}"

@format_report.register
def _(data: dict) -> str:
    """Xử lý riêng nếu đầu vào là dict."""
    return f"Báo cáo dạng từ điển gồm các keys: {list(data.keys())}"

@format_report.register
def _(data: list) -> str:
    """Xử lý riêng nếu đầu vào là list."""
    return f"Báo cáo dạng danh sách gồm {len(data)} phần tử."   