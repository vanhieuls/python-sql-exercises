from collections import Counter, defaultdict
import heapq
from mock_data import customers, products, orders, order_details

def bai_1():
    # In ra tên và email của 10 khách hàng đầu tiên trong customers. (Gợi ý: list slicing [:10], vòng lặp.)
    result = []
    for c in customers[:10]:
        result.append((c["name"],c["email"]))
    return result

#Đếm số sản phẩm đang kinh doanh (discontinued == False). (Gợi ý: generator + sum, hoặc list comprehension đếm.)
def bai_2():
    return sum(1 for p in products if not p["discontinued"])

# Lấy danh sách tất cả category duy nhất của sản phẩm, sắp xếp A→Z. (Gợi ý: set để khử trùng, rồi sorted.)
def bai_3():
    categories = set()
    for p in products:
        categories.add(p["category"])
    return sorted(categories)

# Tạo dict ánh xạ product_id -> name từ products. (Gợi ý: dict comprehension.)
def bai_4():
    product_map={}
    for p in products:
        product_map[p["id"]] = p["name"]
    return product_map

# Tìm sản phẩm có unit_price cao nhất. (Gợi ý: max(..., key=...).)
def bai_5():
    return max(products, key=lambda p: p["unit_price"])

# Chuẩn hoá email khách hàng về chữ thường và loại khoảng trắng đầu/cuối. (Gợi ý: string methods .strip().lower().)
def bai_6():
    return [c["email"].strip().lower() for c in customers]

# Đếm số khách hàng theo từng `city`. *(Gợi ý: `dict` tích luỹ hoặc `collections.Counter`.)*
def bai_7():
    return dict(Counter(c["city"] for c in customers))

# Tách tên khách hàng thành `(họ, tên)` dựa trên khoảng trắng cuối. *(Gợi ý: `str.rsplit(" ", 1)` → `tuple`.)*
def bai_8():
    return [tuple(c["name"].rsplit(" ", 1)) for c in customers]

# Lọc các đơn có `status == 'paid'`, trả về list `id`. *(Gợi ý: list comprehension với điều kiện.)*
def bai_9():
    return [o["id"] for o in orders if o["status"]=="paid"]

# Kiểm tra một `email` đã tồn tại trong `customers` chưa với tra cứu O(1). *(Gợi ý: build `set` các email trước.)*
def bai_10(email):
    email_set={c["email"].lower() for c in customers}
    return email.lower() in email_set

# Gộp hai list sản phẩm, loại trùng theo `id`, giữ bản ghi xuất hiện sau. *(Gợi ý: `dict` theo key `id` rồi `.values()`.)*
def bai_11(extra_products):
    # Khi dùng dict, nếu id trùng thì phần tử sau sẽ đè lên phần tử trước (giữ bản ghi sau)
    merged_dict = {p["id"]: p for p in products + extra_products}
    return list(merged_dict.values())

#Tính tổng tiền một đơn `order_id` cho trước từ `order_details`. *(Gợi ý: lọc + `sum` của biểu thức.)*
def bai_12(order_id):
    return sum(item["quantity"] * item["unit_price"] for item in order_details if item["order_id"] == order_id)

#Đảo ngược thứ tự danh sách đơn hàng mà không tạo bản sao mới. *(Gợi ý: `list.reverse()` vs `reversed()`.)*

def bai_13():
    orders.reverse()
    return orders
#Tìm 3 sản phẩm rẻ nhất. *(Gợi ý: `sorted(..., key=...)[:3]` hoặc `heapq.nsmallest`.)*

def bai_14():
    return heapq.nsmallest(3, products, key=lambda p: p["unit_price"])

# Kiểm tra trùng lặp `email` trong `customers`, trả về các email bị trùng. *(Gợi ý: `Counter` rồi lọc `count > 1`.)*
def bai_15():
    email_counts = Counter(c["email"].lower() for c in customers)
    return [email for email, count in email_counts.items() if count > 1]
#Nhóm `product_id` theo `category` thành `dict[str, list]`. *(Gợi ý: `collections.defaultdict(list)`.)*
def bai_16():
    group = defaultdict(list)
    for p in products:
        group[p["category"]].append(p["id"])
    return dict(group) 

# Ghép (zip) hai list `names` và `emails` thành list tuple. *(Gợi ý: `zip`, chú ý độ dài lệch.)*
def bai_17(names, emails):
    return list(zip(names, emails))

# Đếm tần suất xuất hiện mỗi ký tự trong tên một khách hàng. *(Gợi ý: `Counter(string)`.)*
def bai_18(name):
    return dict(Counter(name.lower()))
#Tìm các `product_id` có trong `order_details` nhưng không có trong `products` (dữ liệu rác). *(Gợi ý: phép trừ hai `set`.)*
def bai_19():
    product_ids_in_catalog = {p["id"] for p in products}
    product_ids_in_orders = {item["product_id"] for item in order_details}
    return list(product_ids_in_orders - product_ids_in_catalog)
# Tạo tuple bất biến chứa cấu hình trạng thái hợp lệ và kiểm tra một status có hợp lệ không. *(Gợi ý: `tuple`/`frozenset` hằng số.)*
VALID_STATUS = ("paid", "pending", "shipped", "cancelled")
def bai_20(status_to_check):
    return status_to_check in VALID_STATUS

if __name__ == "__main__":
    print("bai 1", bai_1())
    print("bai 2", bai_2())
    print("bai 3", bai_3())
    print("bai 4", bai_4())
    print("bai 5", bai_5())
    print("bai 6", bai_6())
    print("bai 7", bai_7())
    print("bai 8", bai_8())
    print("bai 9", bai_9())
    print("bai 10", bai_10("nguyen.van.a@gmail.com"))
    mock_products = [{"id": 16, "name": "Bàn phím cơ mới", "category": "Phụ kiện", "unit_price": 1200, "discontinued": False}]
    print("bai 11", bai_11(mock_products))
    print("bai 12", bai_12(103))
    print("bai 13", bai_13())
    print("bai 14", bai_14())
    print("bai 15", bai_15())
    print("bai 16", bai_16())
    print("bai 17", bai_17(["An", "Bình"], ["an@gmail.com", "binh@gmail.com"]))
    print("bai 18", bai_18("Nguyen Van An"))
    print("bai 19:", bai_19())
    print("bai 20", bai_20("paid"))