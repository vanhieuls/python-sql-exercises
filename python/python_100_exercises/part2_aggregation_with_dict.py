from collections import defaultdict, Counter
import heapq
from mock_data import customers, products, orders, order_details
# 21. Tính doanh thu từng đơn (`order_total`) cho đơn `status in {'paid','shipped'}`. *(Gợi ý: `defaultdict(float)` theo `order_id`.)*
def bai_21():
    order_id = {o["id"] for o in orders if o["status"] in {"paid","shipped"}}
    order_total = defaultdict(float)
    for item in order_details:
        if item["order_id"] in order_id:
            order_total[item["order_id"]]+=item["quantity"] * item["unit_price"]
    return dict(order_total)

# 22. Tính doanh thu theo từng khách hàng (join `orders` ↔ `order_details`). *(Gợi ý: index `order_id -> customer_id` bằng dict trước khi gom.)*
def bai_22():
    order_to_customer = {o["id"]:o["customer_id"] for o in orders}
    customer_revenue = defaultdict(float)
    for item in order_details:
        customer_id = order_to_customer.get(item["order_id"])
        if customer_id:    
            customer_revenue[customer_id] += item["quantity"] * item["unit_price"]
    return dict(customer_revenue)

# 23. Doanh thu theo `category` sản phẩm. *(Gợi ý: lookup `product_id -> category`, gom bằng `defaultdict`.)*
def bai_23():
    product_to_cate = {p["id"] : p["category"] for p in products}
    category_revenue = defaultdict(float)
    for item in order_details:
        category = product_to_cate.get(item["product_id"])
        if category:
            category_revenue[category] += item["quantity"] * item["unit_price"]
    return dict(category_revenue)

# 24. Đếm số đơn theo từng `payment_method`. *(Gợi ý: `Counter`.)*
def bai_24():
    return dict(Counter(o["payment_method"] for o in orders))

# 25. Tính AOV (doanh thu trung bình mỗi đơn) toàn hệ thống. *(Gợi ý: hai bộ đếm tổng doanh thu và số đơn.)*
def bai_25():
    total_revenue = sum(item["quantity"] * item["unit_price"] for item in order_details)
    total_orders = len(orders)
    return total_revenue/total_orders if total_orders > 0 else 0

# 26. Tìm khách hàng chưa từng đặt đơn nào. *(Gợi ý: `set(all_ids) - set(customer_id trong orders)`.)*
def bai_26():
    all_customers_id = {c["id"] for c in customers}
    ordered_customer_id = {o["customer_id"] for o in orders}
    return list(all_customers_id - ordered_customer_id)

# 27. Với mỗi khách, tìm ngày đặt đơn gần nhất. *(Gợi ý: dict `customer_id -> max(order_date)`.)*
def bai_27():
    customer_latest = {}
    for o in orders:
        customer_id = o["customer_id"]
        date = o["order_date"]
        if customer_id not in customer_latest or date > customer_latest[customer_id]:
            customer_latest[customer_id] = date

# 28. Tính số lượng bán ra theo từng `product_id`. *(Gợi ý: `Counter` cộng dồn `quantity`.)*
def bai_28():
    product_quantity = defaultdict(int)
    for item in order_details:
        product_quantity[item["product_id"]] += item["quantity"]
    return dict(product_quantity)
# 29. Top 10 sản phẩm bán chạy theo số lượng. *(Gợi ý: gom bằng dict rồi `heapq.nlargest(10, ...)`.)*
def bai_29():
    product_quantity = defaultdict(int)
    for i in order_details:
        product_quantity[i["product_id"]] += i["quantity"]
    return heapq.nlargest(10, product_quantity.items(), key=lambda x: x[1])

# 30. Doanh thu theo tháng (`YYYY-MM`). *(Gợi ý: key = chuỗi tháng cắt từ `order_date`, `defaultdict`.)*
def bai_30():
    order_to_month = {o["id"]: o["order_date"][:7] for o in orders}
    monthly_revenue = defaultdict(float)
    for i in order_details:
        month = order_to_month.get(i["order_id"])
        if month:
            monthly_revenue[month] += i["quantity"] * i["unit_price"]        
    return dict(monthly_revenue)

# 31. Tính biên lợi nhuận gộp theo đơn (`unit_price - cost`). *(Gợi ý: lookup `product_id -> cost`, gom theo `order_id`.)*
def bai_31():
    product_cost = {p["id"]: p.get("cost", 0) for p in products}
    order_profit = defaultdict(float)
    for item in order_details:
        cost = product_cost.get(item["product_id"], 0)
        profit_per_item = item["unit_price"] - cost
        order_profit[item["order_id"]] += profit_per_item * item["quantity"] 
    return dict(order_profit)

# 32. Weighted discount mỗi đơn = `sum(qty*discount)/sum(qty)`. *(Gợi ý: hai dict tích luỹ tử số và mẫu số.)*

# 33. Số khách hàng duy nhất đã mua mỗi `category`. *(Gợi ý: `defaultdict(set)` để đếm distinct.)*
def bai_33():
    order_to_customer = {o["id"]: o["customer_id"] for o in orders}
    product_to_category = {p["id"]: p["category"] for p in products}
    category_customers = defaultdict(set)
    for item in order_details:
        customer_id = order_to_customer.get(item["order_id"])
        category = product_to_category.get(item["product_id"])
        if customer_id and category:
            category_customers[category].add(customer_id)            
    return {cat: len(cus) for cat, cus in category_customers.items()}
# 34. Trung bình số dòng chi tiết trên mỗi đơn. *(Gợi ý: `Counter` số dòng theo `order_id`, rồi mean.)*
def bai_34():
    count = Counter(i["order_id"] for i in order_details)
    total_line=0
    for s in count.values():
        total_line += s
    return total_line/len(count)
# 35. Tìm `payment_method` có doanh thu cao nhất. *(Gợi ý: gom dict rồi `max(..., key=dict.get)`.)*
def bai_35():
    order_to_payment = {o["id"]: o["payment_method"] for o in orders}
    payment_revenue = defaultdict(float)
    for i in order_details:
        method = order_to_payment.get(i["order_id"])
        if method:
            payment_revenue[method] += i["quantity"] * i["unit_price"]
    return max(payment_revenue, key=payment_revenue.get)

# 36. Với mỗi khách: số đơn, tổng chi, chi trung bình. *(Gợi ý: dict giá trị là `dict`/`dataclass` tích luỹ nhiều trường.)*
# 37. Tỷ lệ đơn bị huỷ/hoàn trên tổng đơn theo `city`. *(Gợi ý: hai `Counter` theo thành phố, chia theo key.)*
# 38. Sản phẩm "mồ côi": `discontinued == False` và không xuất hiện trong đơn nào. *(Gợi ý: `set` product bán ra, phép trừ.)*
def bai_38():
    sold_product_id = {i["product_id"] for i in order_details}
    return [p for p in products if not p["discontinued"] and p["id"] not in sold_product_id] 
# 39. Doanh thu tích luỹ (running total) theo thứ tự ngày. *(Gợi ý: sort theo ngày rồi cộng dồn biến tích luỹ.)*
# 40. Pivot: ma trận doanh thu `category x tháng`. *(Gợi ý: `defaultdict` lồng nhau `dict[tuple]` hoặc `dict[dict]`.)*


if __name__ == "__main__":
    print(bai_21())
    print(bai_22())
    print(bai_23())
    print(bai_24())
    print(bai_25())
    print(bai_26())
    print(bai_27())
    print(bai_28())
    print(bai_29())
    print(bai_30())
    print(bai_31())
    print(bai_33())
    print(bai_34())
    print(bai_35())
    print(bai_38())
