from collections import Counter, defaultdict, deque
import heapq, bisect, statistics
from mock_data import customers, products, orders, order_details
from itertools import combinations
# 81. Dùng `heapq` duy trì top-5 khách chi tiêu cao khi dữ liệu chảy theo stream. *(Gợi ý: min-heap kích thước cố định.)*
def bai_81_stream(customer_streams, k=5):
    # Min-heap lưu các tuple (total_spent, customer_id)
    min_heap = []
    for c_id, total in customer_streams:
        if len(min_heap)<k:
            heapq.heappush(min_heap, (total, c_id))
        elif total>min_heap[0][0]:
            heapq.heapreplace(min_heap, (total, c_id))    
    # Trả về top k giảm dần
    return sorted(min_heap, key=lambda x:x[0], reverse=True)
# 82. Kết hợp median giá trị đơn theo `payment_method`. *(Gợi ý: sort từng nhóm + lấy phần tử giữa, hoặc two-heaps.)*
def bai_82(orders):
    grouped = defaultdict(list)
    for o in orders:
        grouped[o["payment_method"]].append(o["total"])
    medians = {}
    for method, totals in grouped.items():
        medians[method] = statistics.median(totals)
    return medians
# 83. Streaming median giá trị đơn (cập nhật liên tục). *(Gợi ý: hai heap (max-heap + min-heap) cân bằng.)*
# 84. Z-score doanh thu từng khách so với toàn bộ. *(Gợi ý: tính mean/stddev một lượt, `statistics`.)*
def bai_84(customer_totals):
    # customer_totals là dict: {customer_id: total_spent}
    values = list(customer_totals.values())
    mean_val = statistics.mean(values)
    stdev_val = statistics.stdev(values) if len(values)>1 else 1
    z_scores = {}
    for c_id, val in customer_totals.items():
        z_scores[c_id] = (val - mean_val)/stdev_val if stdev_val!=0 else 0      
    return z_scores
# 85. Basket analysis: top cặp sản phẩm hay mua chung một đơn. *(Gợi ý: `itertools.combinations` + `Counter` theo cặp.)*
def bai_85(orders, order_details, products):
    product_name_map={p["id"]: p["name"] for p in products}
    order_items_dict=defaultdict(list)
    for item in order_details:
        order_id=item["order_id"]
        p_id=item["product_id"]
        #Lấy tên sản phẩm từ map 
        p_name=product_name_map.get(p_id, p_id)
        order_items_dict[order_id].append(p_name)
    #Chuyển đổi thành danh sách các mảng sản phẩm 
    orders_with_products=list(order_items_dict.values())
    pair_counts=Counter()
    for products in orders_with_products:
        #Sắp xếp sản phẩm trong đơn để tránh trùng cặp (A, B) và (B, A)
        unique_products=sorted(list(set(products)))
        for pair in combinations(unique_products, 2):
            pair_counts[pair]+=1
    return pair_counts.most_common(5)
# 86. Tìm sản phẩm đồng xuất hiện bằng đồ thị kề. *(Gợi ý: `defaultdict(set)` làm adjacency list.)*
def bai_86(orders_with_products): # Tìm orders_with_products tương tự như bài 85
    graph=defaultdict(set)
    for products in orders_with_products:
        unique=list(set(products))
        for i in range(len(unique)):
            for j in range(i + 1, len(unique)):
                p1, p2=unique[i], unique[j]
                graph[p1].add(p2)
                graph[p2].add(p1)
    return dict(graph)
# 87. Phát hiện thành phần liên thông của đồ thị đồng mua (cụm sản phẩm). *(Gợi ý: BFS/DFS trên adjacency list, `deque`.)*
# 88. Union-Find gộp các khách hàng trùng (cùng email/điện thoại). *(Gợi ý: Disjoint Set Union với path compression.)*
# 89. Đề xuất sản phẩm "mua kèm" bằng xếp hạng đồng xuất hiện. *(Gợi ý: dict điểm số + `heapq.nlargest`.)*
# 90. LRU cache thủ công cho truy vấn `order_total` hay gọi lại. *(Gợi ý: `OrderedDict` hoặc `collections` + move-to-end.)*
# 91. Trie tra cứu nhanh sản phẩm theo tiền tố tên. *(Gợi ý: cây Trie bằng dict lồng nhau.)*
# 92. Tìm k sản phẩm giá gần nhất với một mức giá cho trước. *(Gợi ý: sort + binary search `bisect`, lấy 2 phía.)*
def bai_92(sorted_products, target_price, k=3):
    # sorted_products đã sắp xếp tăng dần theo 'price'
    prices=[p["price"] for p in sorted_products]
    idx=bisect.bisect_left(prices, target_price)
    # Lấy ra các phần tử xung quanh vị trí idx
    left=idx-1
    right=idx
    result=[]
    while len(result)<k and (left>=0 or right<len(prices)):
        if right>=len(prices) or (left>=0 and abs(prices[left]-target_price)<=abs(prices[right]-target_price)):
            result.append(sorted_products[left])
            left-=1
        else:
            result.append(sorted_products[right])
            right+=1
            
    return result
# 93. Dùng `bisect` chèn đơn mới vào list luôn giữ thứ tự ngày. *(Gợi ý: `bisect.insort`.)*
def bai_93(orders, new_order):
    orders.sort(key=lambda o:o["order_date"])
    bisect.insort(orders, new_order, key=lambda o:o["order_date"])
    return orders
# 94. Lập lịch giao hàng không chồng khung giờ (interval scheduling). *(Gợi ý: sort theo giờ kết thúc, greedy.)*
def bai_94(intervals):
    # intervals là list dict hoặc tuple: [(start, end), ...]
    if not intervals:
        return []
    # Sắ xếp theo thời gian kết thúc tăng dần (Greedy choice)
    sorted_intervals=sorted(intervals, key=lambda x: x[1])
    selected=[sorted_intervals[0]]
    last_end=sorted_intervals[0][1]
    for current in sorted_intervals[1:]:
        if current[0]>=last_end:  # Không bị chồng lấn
            selected.append(current)
            last_end=current[1]
    return selected
# 95. Gộp các khoảng khuyến mãi chồng nhau thành khoảng lớn. *(Gợi ý: sort theo start, merge intervals.)*
def bai_95(promos):
    # promos là list các tuple ví dụ như [(start_date, end_date), ...]
    if not promos:
        return []    
    sorted_promos=sorted(promos, key=lambda x: x[0])
    merged=[sorted_promos[0]] 
    for current in sorted_promos[1:]:
        prev_start, prev_end=merged[-1]
        curr_start, curr_end=current
        if curr_start<=prev_end:  # Có chồng lấn
            merged[-1]=(prev_start, max(prev_end, curr_end))
        else:
            merged.append(current)
    return merged
# 96. Prefix sum doanh thu để truy vấn tổng khoảng ngày bất kỳ O(1). *(Gợi ý: mảng tích luỹ.)*
def bai_96(daily_revenues):
    # daily_revenues là list doanh thu theo ngày [rev_day1, rev_day2, ...]
    prefix_sums = []
    current_sum = 0
    for rev in daily_revenues:
        current_sum+=rev
        prefix_sums.append(current_sum)
    # Hàm query tổng từ ngày L đến ngày R trong O(1)
    def sum_query(L, R):
        if L==0:
            return prefix_sums[R]
        return prefix_sums[R]-prefix_sums[L-1]
    return prefix_sums, sum_query
# 97. Sliding window maximum doanh thu ngày trong cửa sổ k. *(Gợi ý: `deque` đơn điệu (monotonic queue).)*
def bai_97(revenues, k):
    # revenues là list doanh thu theo ngày
    if not revenues or k<=0:
        return []
    dq=deque()  
    result=[]
    for i, val in enumerate(revenues):
        # Loại bỏ các phần tử nằm ngoài cửa sổ hiện tại
        if dq and dq[0]<i-k+1:
            dq.popleft()   
        # Loại bỏ các phần tử nhỏ hơn giá trị hiện tại ở phía sau deque
        while dq and revenues[dq[-1]]<=val:
            dq.pop()  
        dq.append(i)
        # Bắt đầu ghi nhận kết quả khi đủ cửa sổ k
        if i>=k-1:
            result.append(revenues[dq[0]])
    return result
# 98. Phân trang (pagination) list đơn với `page`, `page_size`. *(Gợi ý: slicing, `itertools.islice` cho iterator.)*
def bai_98(orders, page=1, page_size=10):
    start = (page-1)*page_size
    end = start+page_size
    return orders[start:end]
# 99. Đọc dữ liệu rất lớn theo dòng mà không nạp hết vào RAM. *(Gợi ý: generator pipeline, lazy evaluation.)*
def bai_99(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            yield line.strip().split(',')
# 100. Thiết kế mini in-memory "query engine": `filter → group → aggregate → sort` ghép chuỗi được. *(Gợi ý: kết hợp iterator/generator, dict index, heap — tổng hợp mọi kỹ thuật trên.)*
if __name__ == "__main__":
    print("=== TEST KẾT QUẢ CÁC BÀI ĐÃ LÀM ===")

    # 1. Test Bài 98: Phân trang
    dummy_orders = [{"id": i, "customer_id": f"C{i}"} for i in range(1, 26)]
    print("\n[Bài 98] Phân trang (Trang 2, mỗi trang 5 đơn):")
    print(bai_98(dummy_orders, page=2, page_size=5))

    # 2. Test Bài 93: Bisect insort giữ thứ tự ngày
    orders_sorted_date = [
        {"id": 1, "order_date": "2026-03-01"},
        {"id": 3, "order_date": "2026-03-05"}
    ]
    new_ord = {"id": 2, "order_date": "2026-03-03"}
    print("\n[Bài 93] Chèn đơn hàng mới giữ nguyên thứ tự ngày:")
    print(bai_93(orders_sorted_date, new_ord))

    # 3. Test Bài 82: Median giá trị đơn theo payment_method
    test_orders_med = [
        {"payment_method": "COD", "total": 100},
        {"payment_method": "COD", "total": 200},
        {"payment_method": "COD", "total": 300},
        {"payment_method": "Momo", "total": 150},
        {"payment_method": "Momo", "total": 250}
    ]
    print("\n[Bài 92 / 82] Median giá trị đơn theo phương thức thanh toán:")
    print(bai_82(test_orders_med))

    # 4. Test Bài 96: Prefix sum doanh thu O(1)
    revenues = [100, 200, 150, 300, 250]
    p_sums, query_func = bai_96(revenues)
    print("\n[Bài 96] Prefix sums:", p_sums)
    print("Tổng doanh thu từ ngày index 1 đến 3:", query_func(1, 3)) # 200 + 150 + 300 = 650

    # 5. Test Bài 95: Gộp khoảng khuyến mãi (Merge Intervals)
    promos = [(1, 5), (3, 8), (10, 12), (11, 15)]
    print("\n[Bài 95] Gộp khoảng khuyến mãi chồng nhau:")
    print(bai_95(promos))

    # 6. Test Bài 84: Z-score doanh thu khách hàng
    c_totals = {"C01": 500, "C02": 1500, "C03": 1000, "C04": 200}
    print("\n[Bài 84] Z-score doanh thu từng khách:")
    print(bai_84(c_totals))

    # 7. Test Bài 85: Basket Analysis
    mock_orders = [{"id": "O1"}, {"id": "O2"}]
    mock_details = [
        {"order_id": "O1", "product_id": "p1"},
        {"order_id": "O1", "product_id": "p2"},
        {"order_id": "O1", "product_id": "p3"},
        {"order_id": "O2", "product_id": "p1"},
        {"order_id": "O2", "product_id": "p2"}
    ]
    mock_prods = [{"id": "p1", "name": "Áo"}, {"id": "p2", "name": "Quần"}, {"id": "p3", "name": "Giày"}]
    print("\n[Bài 85] Top cặp sản phẩm mua chung:")
    print(bai_85(mock_orders, mock_details, mock_prods))

    # 8. Test Bài 92: Tìm k sản phẩm giá gần nhất
    sorted_prods = [
        {"name": "A", "price": 100},
        {"name": "B", "price": 120},
        {"name": "C", "price": 150},
        {"name": "D", "price": 200}
    ]
    print("\n[Bài 92] 2 sản phẩm có giá gần 140 nhất:")
    print(bai_92(sorted_prods, target_price=140, k=2))

    # 9. Test Bài 94: Lập lịch giao hàng (Interval Scheduling)
    intervals = [(1, 3), (2, 5), (4, 7), (6, 9)]
    print("\n[Bài 94] Lập lịch giao hàng không chồng chéo tối ưu:")
    print(bai_94(intervals))

    # 10. Test Bài 97: Sliding window maximum
    rev_window = [10, 5, 2, 7, 8, 7]
    print("\n[Bài 97] Sliding window maximum (k=3):")
    print(bai_97(rev_window, k=3))

    # 11. Test Bài 81: Stream Top-K chi tiêu
    stream_data = [("C1", 100), ("C2", 500), ("C3", 300), ("C4", 1200), ("C5", 400)]
    print("\n[Bài 81] Top-3 khách chi tiêu cao nhất từ stream:")
    print(bai_81_stream(stream_data, k=3))