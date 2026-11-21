from collections import defaultdict, Counter, deque
import heapq
from datetime import datetime, timedelta
from mock_data import customers, products, orders, order_details
# 41. Parse mọi `order_date` thành `datetime` và sắp xếp đơn theo thời gian. *(Gợi ý: `datetime.fromisoformat`, `sorted(key=...)`.)*
def bai_41():
    return sorted(orders, key = lambda o:datetime.fromisoformat(o["order_date"]))

# 42. Lọc đơn trong 90 ngày gần nhất tính từ hôm nay. *(Gợi ý: `datetime.now() - timedelta(days=90)`.)*
def bai_42():
    cutoff = datetime.now() - timedelta(days=90)
    return [o for o in orders if datetime.fromisoformat(o["order_date"]) >= cutoff]

# 43. Tính số ngày giao hàng (`shipped_date - order_date`). *(Gợi ý: trừ hai `datetime` → `timedelta.days`.)*
def bai_43():
    shipping_durations = {}
    for o in orders:
        if o.get("shipped_date"):
            d1 = datetime.fromisoformat(o["order_date"])
            d2 = datetime.fromisoformat(o["shipped_date"])
            shipping_durations[o["id"]] = (d2-d1).days
    return shipping_durations
# 2. Tìm các đơn giao muộn (> 3 ngày). *(Gợi ý: lọc theo `timedelta`.)*
def bai_44():
    late_order = []
    for o in orders:
        if o.get("shipped_date"):
            d1 = datetime.fromisoformat(o["order_date"])
            d2 = datetime.fromisoformat(o["shipped_date"])
            if (d2-d1).days>3:
                late_order.append(o["id"])
    return late_order

# 45. Nhóm đơn theo tuần ISO. *(Gợi ý: `date.isocalendar()` làm key.)*
def bai_45():
    weekly_order = defaultdict(list)
    for o in orders:
        dt = datetime.fromisoformat(o["order_date"])
        iso_week = dt.isocalendar() # Trả về tuple (năm, tuần,thú trong tuần)
        weekly_order[iso_week[:2]].append(o["id"])
    return dict(weekly_order)

# 46. Doanh thu theo từng ngày trong 30 ngày gần nhất, điền 0 cho ngày trống. *(Gợi ý: sinh dải ngày bằng list, dict mặc định 0.)*
def bai_46():
    order_to_date = {o["id"]:o["order_date"][:10] for o in orders}
    daily = defaultdict(float)
    for i in order_details:
        d = order_to_date.get(i["order_id"])
        if d:
            daily[d] += i["quantity"] * i["unit_price"]
    result = {}
    today = datetime.now().date()
    for i in range(30):
        day = str(today - timedelta(days=i))
        result[day] = daily.get(day,0.0)
# 47. Rolling 7-day revenue (cửa sổ trượt tổng 7 ngày). *(Gợi ý: `collections.deque(maxlen=7)` hoặc prefix sum.)*
def bai_47():
    order_to_date = {o["id"]:o["order_date"] for o in orders}
    daily_revenue = defaultdict(float)
    for i in order_details:
        d = order_to_date.get(i["order_id"])
        if d:
            daily_revenue[d]+= i["quantity"]*i["unit_price"]
    sort_date = sorted(daily_revenue.keys())
    window = deque(maxlen=7)
    rolling_revenue = []
    for d in sort_date:
        window.append(daily_revenue[d])
        total = sum(window)
        rolling_revenue.append((d,total))
    return rolling_revenue

# 48. Trung bình trượt (moving average) 3 đơn gần nhất theo thời gian. *(Gợi ý: `deque(maxlen=3)`.)*
def bai_48():
    order_to_date = {o["id"]:o["order_date"] for o in orders}
    daily_revenue = defaultdict(float)
    for i in order_details:
        d = order_to_date.get(i["order_id"])
        if d:
            daily_revenue[d]+= i["quantity"]*i["unit_price"]
    sort_date = sorted(daily_revenue.keys())
    window = deque(maxlen=3)
    rolling_revenue = []
    for d in sort_date:
        window.append(daily_revenue[d])
        total = sum(window) / len(window)
        rolling_revenue.append((d,total))
    return rolling_revenue

# 49. Tìm khoảng cách ngày trung bình giữa các đơn liên tiếp của một khách. *(Gợi ý: sort ngày, zip cặp liền kề.)*
# def bai_49():

# 50. Sắp xếp sản phẩm theo nhiều khoá: `category` tăng, `unit_price` giảm. *(Gợi ý: `sorted(key=lambda p: (p['category'], -p['unit_price']))`.)*
def bai_50():
    return sorted(products, key=lambda p: (p["category"], -p["unit_price"]))

# 51. Ổn định hoá sắp xếp: giữ thứ tự gốc khi khoá bằng nhau. *(Gợi ý: tận dụng tính stable của `sorted`.)*
def bai_51():
    sorted_products = sorted(products, key=lambda p: p["unit_price"])
    return sorted_products
# 52. Tìm top-k đơn giá trị cao nhất mà không sort toàn bộ. *(Gợi ý: `heapq.nlargest`.)*
def bai_52(k=5):
    # tính tổng tiền cho từng đơn hàng từ order_details
    order_totals = defaultdict(float)
    for item in order_details:
        order_totals[item["order_id"]] += item["quantity"] * item["unit_price"]
    # bổ sung trường "total" vào từng đơn hàng trong bản sao danh sách orders
    orders_with_total = []
    for o in orders:
        o_copy = o.copy()
        o_copy["total"] = order_totals.get(o["id"], 0.0)
        orders_with_total.append(o_copy)
    # dùng heapq.nlargest để lấy top k đơn giá trị cao nhất
    return heapq.nlargest(k, orders_with_total, key=lambda x: x["total"])
# 53. Trộn (merge) hai list đơn đã sắp xếp theo ngày thành một list vẫn có thứ tự. *(Gợi ý: `heapq.merge`.)*
def bai_53(sorted_list1, sorted_list2):
    return list(heapq.merge(sorted_list1, sorted_list2, key=lambda o: o["order_date"]))
# 54. Phát hiện đơn trùng (cùng khách, cùng ngày, cùng tổng tiền). *(Gợi ý: `set` các tuple khoá.)*
def bai_54():
    order_totals = defaultdict(float)
    seen = set()
    duplicates = []
    for item in order_details:
        order_totals[item["order_id"]] += item["quantity"] * item["unit_price"]
    for o in orders:
        # Tạo tuple cho đơn hàng
        key = (o["customer_id"], o["order_date"][:10], order_totals.get(o["id"], 0.0))
        if key in seen:
            duplicates.append(o["id"])
        else:
            seen.add(key)        
    return duplicates
# 55. Xác định tháng cohort (tháng đơn đầu tiên) của mỗi khách. *(Gợi ý: dict `customer_id -> min(order_date)`.)*
def bai_55():
    customer_first_order = {}
    for o in orders:
        c_id = o["customer_id"]
        month = o["order_date"][:7]  # Lấy định dạng "YYYY-MM"
        if c_id not in customer_first_order or month < customer_first_order[c_id]:
            customer_first_order[c_id] = month
    return customer_first_order
# 56. Tính retention: bao nhiêu % khách cohort tháng T quay lại ở T+1. *(Gợi ý: `set` khách theo từng tháng, giao tập.)*
def bai_56(cohort_t_customers, cohort_t1_customers):
    # cohort_t_customers và cohort_t1_customers là set chứa các customer_id của từng tháng
    if not cohort_t_customers:
        return 0
    # Lấy giao
    returning_customers = cohort_t_customers.intersection(cohort_t1_customers)
    return (len(returning_customers) / len(cohort_t_customers)) * 100
# 57. Tìm chuỗi ngày mua liên tiếp dài nhất của một khách (streak). *(Gợi ý: sort ngày, duyệt đếm chuỗi.)*
def customer_orders() -> dict:
    customer_orders_dict = defaultdict(list)
    for o in orders:
        customer_orders_dict[o["customer_id"]].append(o)
    return dict(customer_orders_dict)
def bai_57(customer_orders):
    # Lấy danh sách các ngày độc lập và sắp xếp tăng dần
    date = sorted(list(set(datetime.fromisoformat(o["order_date"][:10]) for o in customer_orders)))
    if not date:
        return 0    
    max_streak = 1
    current_streak = 1
    for i in range(1, len(date)):
        diff = (date[i] - date[i-1]).days
        if diff == 1:
            current_streak += 1     
        elif diff == 0:
            continue                
        else:
            current_streak = 1            
        max_streak = max(max_streak, current_streak)     
    return max_streak
# 58. Gom đơn vào các "phiên" (session): hai đơn cùng khách cách < 1 giờ là một phiên. *(Gợi ý: sort + duyệt tuyến tính gộp nhóm.)*
def bai_58(customer_orders):
    # Sắp xếp đơn hàng theo thời gian tăng dần
    sorted_orders = sorted(customer_orders, key=lambda o: datetime.fromisoformat(o["order_date"]))
    if not sorted_orders:
        return []
    sessions = []
    current_session = [sorted_orders[0]["id"]]
    for i in range(1, len(sorted_orders)):
        prev_time = datetime.fromisoformat(sorted_orders[i-1]["order_date"])
        curr_time = datetime.fromisoformat(sorted_orders[i]["order_date"])
        # Nếu khoảng cách < 1 giờ thì gom chung vào session hiện tại
        if (curr_time - prev_time) < timedelta(hours=1):
            current_session.append(sorted_orders[i]["id"])
        else:
            sessions.append(current_session)
            current_session = [sorted_orders[i]["id"]]  # Mở session mới
    sessions.append(current_session)
    return sessions
# 59. Tìm giờ trong ngày có nhiều đơn nhất (0..23). *(Gợi ý: `Counter` theo `dt.hour`.)*
def bai_59():
    hour = [datetime.fromisoformat(o["order_date"]).hour for o in orders]
    hour_count = Counter(hour)
    return hour_count.most_common(1)[0][0] if hour_count else None
# 60. Tính LTV 365 ngày: doanh thu tích luỹ trong 365 ngày từ đơn đầu tiên của mỗi khách. *(Gợi ý: mốc `first_order_date`, lọc theo window.)*
def bai_60():
    #tìm ngày mua đầu tiên của từng khách
    first_dates = {}
    for o in orders:
        c_id = o["customer_id"]
        dt = datetime.fromisoformat(o["order_date"])
        if c_id not in first_dates or dt < first_dates[c_id]:
            first_dates[c_id] = dt       
    #lập bản đồ thông tin đơn hàng và tính tổng tiền từng đơn
    order_info = {o["id"]: {"customer_id": o["customer_id"], "date": datetime.fromisoformat(o["order_date"])} for o in orders}
    order_totals = defaultdict(float)
    for item in order_details:
        order_totals[item["order_id"]] += item["quantity"] * item["unit_price"]   
    #tính LTV tích lũy trong vòng 365 ngày từ ngày đầu tiên mua
    ltv_results = defaultdict(float)
    for o_id, info in order_info.items():
        c_id = info["customer_id"]
        o_date = info["date"]
        start_date = first_dates.get(c_id)
        if start_date and start_date <= o_date <= start_date + timedelta(days=365):
            ltv_results[c_id] += order_totals.get(o_id, 0.0)
            
    return dict(ltv_results)
if __name__ == "__main__":
    bai_50()