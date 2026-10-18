# Học Python cấp tốc qua 100 bài tập thực chiến (kèm gợi ý Data Structure)

Bộ 100 bài tập Python nâng level dần, xoay quanh cùng mô hình dữ liệu bán hàng với file SQL: `customers`, `products`, `orders`, `order_details`.
Mục tiêu: rèn tư duy chọn **đúng cấu trúc dữ liệu** cho từng vấn đề, từ cú pháp cơ bản đến thuật toán và thiết kế.

> Mỗi bài có gợi ý nhỏ **Data Structure / kỹ thuật** nên dùng. Gợi ý không phải đáp án — chỉ định hướng để chọn công cụ phù hợp.

## Mô hình dữ liệu (giả định — dạng Python)

```python
# Mỗi bản ghi là một dict; mỗi bảng là một list[dict]

customers = [
    {"id": 1, "name": "An", "email": "an@x.com", "city": "HCM", "tier": 1,
     "created_at": "2024-01-05T10:00:00"},
    # ...
]

products = [
    {"id": 10, "name": "Bàn phím", "category": "Phụ kiện",
     "unit_price": 350000, "cost": 200000, "discontinued": False, "stock": 40},
    # ...
]

orders = [
    {"id": 100, "customer_id": 1, "order_date": "2024-06-01T09:00:00",
     "status": "paid", "shipped_date": "2024-06-03T09:00:00",
     "shipping_fee": 20000, "payment_method": "card"},
    # ...
]

order_details = [
    {"order_id": 100, "product_id": 10, "quantity": 2,
     "unit_price": 350000, "discount": 10.0},
    # ...
]
```

Quy ước chung:
- Ngày giờ ở dạng chuỗi ISO 8601 → parse bằng `datetime.fromisoformat`.
- `status` thuộc `{'pending','paid','shipped','cancelled','refunded'}`.
- `discount` là phần trăm (0..100).
- Tổng tiền dòng = `quantity * unit_price * (1 - discount/100)`.

---

## Phần 1 — 20 bài nền tảng (list, dict, set, tuple, string)

1. In ra tên và email của 10 khách hàng đầu tiên trong `customers`. *(Gợi ý: list slicing `[:10]`, vòng lặp.)*
2. Đếm số sản phẩm đang kinh doanh (`discontinued == False`). *(Gợi ý: generator + `sum`, hoặc list comprehension đếm.)*
3. Lấy danh sách tất cả `category` duy nhất của sản phẩm, sắp xếp A→Z. *(Gợi ý: `set` để khử trùng, rồi `sorted`.)*
4. Tạo dict ánh xạ `product_id -> name` từ `products`. *(Gợi ý: dict comprehension.)*
5. Tìm sản phẩm có `unit_price` cao nhất. *(Gợi ý: `max(..., key=...)`.)*
6. Chuẩn hoá email khách hàng về chữ thường và loại khoảng trắng đầu/cuối. *(Gợi ý: string methods `.strip().lower()`.)*
7. Đếm số khách hàng theo từng `city`. *(Gợi ý: `dict` tích luỹ hoặc `collections.Counter`.)*
8. Tách tên khách hàng thành `(họ, tên)` dựa trên khoảng trắng cuối. *(Gợi ý: `str.rsplit(" ", 1)` → `tuple`.)*
9. Lọc các đơn có `status == 'paid'`, trả về list `id`. *(Gợi ý: list comprehension với điều kiện.)*
10. Kiểm tra một `email` đã tồn tại trong `customers` chưa với tra cứu O(1). *(Gợi ý: build `set` các email trước.)*
11. Gộp hai list sản phẩm, loại trùng theo `id`, giữ bản ghi xuất hiện sau. *(Gợi ý: `dict` theo key `id` rồi `.values()`.)*
12. Tính tổng tiền một đơn `order_id` cho trước từ `order_details`. *(Gợi ý: lọc + `sum` của biểu thức.)*
13. Đảo ngược thứ tự danh sách đơn hàng mà không tạo bản sao mới. *(Gợi ý: `list.reverse()` vs `reversed()`.)*
14. Tìm 3 sản phẩm rẻ nhất. *(Gợi ý: `sorted(..., key=...)[:3]` hoặc `heapq.nsmallest`.)*
15. Kiểm tra trùng lặp `email` trong `customers`, trả về các email bị trùng. *(Gợi ý: `Counter` rồi lọc `count > 1`.)*
16. Nhóm `product_id` theo `category` thành `dict[str, list]`. *(Gợi ý: `collections.defaultdict(list)`.)*
17. Ghép (zip) hai list `names` và `emails` thành list tuple. *(Gợi ý: `zip`, chú ý độ dài lệch.)*
18. Đếm tần suất xuất hiện mỗi ký tự trong tên một khách hàng. *(Gợi ý: `Counter(string)`.)*
19. Tìm các `product_id` có trong `order_details` nhưng không có trong `products` (dữ liệu rác). *(Gợi ý: phép trừ hai `set`.)*
20. Tạo tuple bất biến chứa cấu hình trạng thái hợp lệ và kiểm tra một status có hợp lệ không. *(Gợi ý: `tuple`/`frozenset` hằng số.)*

---

## Phần 2 — 20 bài gom nhóm & tổng hợp (aggregation bằng dict)

21. Tính doanh thu từng đơn (`order_total`) cho đơn `status in {'paid','shipped'}`. *(Gợi ý: `defaultdict(float)` theo `order_id`.)*
22. Tính doanh thu theo từng khách hàng (join `orders` ↔ `order_details`). *(Gợi ý: index `order_id -> customer_id` bằng dict trước khi gom.)*
23. Doanh thu theo `category` sản phẩm. *(Gợi ý: lookup `product_id -> category`, gom bằng `defaultdict`.)*
24. Đếm số đơn theo từng `payment_method`. *(Gợi ý: `Counter`.)*
25. Tính AOV (doanh thu trung bình mỗi đơn) toàn hệ thống. *(Gợi ý: hai bộ đếm tổng doanh thu và số đơn.)*
26. Tìm khách hàng chưa từng đặt đơn nào. *(Gợi ý: `set(all_ids) - set(customer_id trong orders)`.)*
27. Với mỗi khách, tìm ngày đặt đơn gần nhất. *(Gợi ý: dict `customer_id -> max(order_date)`.)*
28. Tính số lượng bán ra theo từng `product_id`. *(Gợi ý: `Counter` cộng dồn `quantity`.)*
29. Top 10 sản phẩm bán chạy theo số lượng. *(Gợi ý: gom bằng dict rồi `heapq.nlargest(10, ...)`.)*
30. Doanh thu theo tháng (`YYYY-MM`). *(Gợi ý: key = chuỗi tháng cắt từ `order_date`, `defaultdict`.)*
31. Tính biên lợi nhuận gộp theo đơn (`unit_price - cost`). *(Gợi ý: lookup `product_id -> cost`, gom theo `order_id`.)*
32. Weighted discount mỗi đơn = `sum(qty*discount)/sum(qty)`. *(Gợi ý: hai dict tích luỹ tử số và mẫu số.)*
33. Số khách hàng duy nhất đã mua mỗi `category`. *(Gợi ý: `defaultdict(set)` để đếm distinct.)*
34. Trung bình số dòng chi tiết trên mỗi đơn. *(Gợi ý: `Counter` số dòng theo `order_id`, rồi mean.)*
35. Tìm `payment_method` có doanh thu cao nhất. *(Gợi ý: gom dict rồi `max(..., key=dict.get)`.)*
36. Với mỗi khách: số đơn, tổng chi, chi trung bình. *(Gợi ý: dict giá trị là `dict`/`dataclass` tích luỹ nhiều trường.)*
37. Tỷ lệ đơn bị huỷ/hoàn trên tổng đơn theo `city`. *(Gợi ý: hai `Counter` theo thành phố, chia theo key.)*
38. Sản phẩm "mồ côi": `discontinued == False` và không xuất hiện trong đơn nào. *(Gợi ý: `set` product bán ra, phép trừ.)*
39. Doanh thu tích luỹ (running total) theo thứ tự ngày. *(Gợi ý: sort theo ngày rồi cộng dồn biến tích luỹ.)*
40. Pivot: ma trận doanh thu `category x tháng`. *(Gợi ý: `defaultdict` lồng nhau `dict[tuple]` hoặc `dict[dict]`.)*

---

## Phần 3 — 20 bài ngày giờ, sắp xếp, cửa sổ trượt

41. Parse mọi `order_date` thành `datetime` và sắp xếp đơn theo thời gian. *(Gợi ý: `datetime.fromisoformat`, `sorted(key=...)`.)*
42. Lọc đơn trong 90 ngày gần nhất tính từ hôm nay. *(Gợi ý: `datetime.now() - timedelta(days=90)`.)*
43. Tính số ngày giao hàng (`shipped_date - order_date`). *(Gợi ý: trừ hai `datetime` → `timedelta.days`.)*
44. Tìm các đơn giao muộn (> 3 ngày). *(Gợi ý: lọc theo `timedelta`.)*
45. Nhóm đơn theo tuần ISO. *(Gợi ý: `date.isocalendar()` làm key.)*
46. Doanh thu theo từng ngày trong 30 ngày gần nhất, điền 0 cho ngày trống. *(Gợi ý: sinh dải ngày bằng list, dict mặc định 0.)*
47. Rolling 7-day revenue (cửa sổ trượt tổng 7 ngày). *(Gợi ý: `collections.deque(maxlen=7)` hoặc prefix sum.)*
48. Trung bình trượt (moving average) 3 đơn gần nhất theo thời gian. *(Gợi ý: `deque(maxlen=3)`.)*
49. Tìm khoảng cách ngày trung bình giữa các đơn liên tiếp của một khách. *(Gợi ý: sort ngày, zip cặp liền kề.)*
50. Sắp xếp sản phẩm theo nhiều khoá: `category` tăng, `unit_price` giảm. *(Gợi ý: `sorted(key=lambda p: (p['category'], -p['unit_price']))`.)*
51. Ổn định hoá sắp xếp: giữ thứ tự gốc khi khoá bằng nhau. *(Gợi ý: tận dụng tính stable của `sorted`.)*
52. Tìm top-k đơn giá trị cao nhất mà không sort toàn bộ. *(Gợi ý: `heapq.nlargest`.)*
53. Trộn (merge) hai list đơn đã sắp xếp theo ngày thành một list vẫn có thứ tự. *(Gợi ý: `heapq.merge`.)*
54. Phát hiện đơn trùng (cùng khách, cùng ngày, cùng tổng tiền). *(Gợi ý: `set` các tuple khoá.)*
55. Xác định tháng cohort (tháng đơn đầu tiên) của mỗi khách. *(Gợi ý: dict `customer_id -> min(order_date)`.)*
56. Tính retention: bao nhiêu % khách cohort tháng T quay lại ở T+1. *(Gợi ý: `set` khách theo từng tháng, giao tập.)*
57. Tìm chuỗi ngày mua liên tiếp dài nhất của một khách (streak). *(Gợi ý: sort ngày, duyệt đếm chuỗi.)*
58. Gom đơn vào các "phiên" (session): hai đơn cùng khách cách < 1 giờ là một phiên. *(Gợi ý: sort + duyệt tuyến tính gộp nhóm.)*
59. Tìm giờ trong ngày có nhiều đơn nhất (0..23). *(Gợi ý: `Counter` theo `dt.hour`.)*
60. Tính LTV 365 ngày: doanh thu tích luỹ trong 365 ngày từ đơn đầu tiên của mỗi khách. *(Gợi ý: mốc `first_order_date`, lọc theo window.)*

---

## Phần 4 — 20 bài hàm, lớp, OOP, tổ chức code

61. Viết hàm `line_total(detail)` trả về tổng tiền một dòng. *(Gợi ý: hàm thuần, không side-effect.)*
62. Viết hàm `order_total(order_id)` dùng index dựng sẵn thay vì quét lại. *(Gợi ý: dict index `order_id -> list[detail]`.)*
63. Thiết kế `dataclass Product` với property `margin` (lợi nhuận đơn vị). *(Gợi ý: `@dataclass`, `@property`.)*
64. Thiết kế `dataclass Order` và method `total(with_shipping=True)`. *(Gợi ý: method + tham số mặc định.)*
65. Lớp `Catalog` bọc list sản phẩm, hỗ trợ `get(id)` O(1). *(Gợi ý: dict index nội bộ.)*
66. Viết decorator `@timed` đo thời gian chạy một hàm tổng hợp. *(Gợi ý: `functools.wraps`, `time.perf_counter`.)*
67. Viết decorator `@memoize` cache kết quả theo tham số. *(Gợi ý: `functools.lru_cache` hoặc dict cache tự viết.)*
68. Hàm `group_by(items, key_func)` tổng quát trả về `dict[key, list]`. *(Gợi ý: `defaultdict(list)`, hàm bậc cao.)*
69. Hàm `pluck(items, field)` lấy một trường từ list dict. *(Gợi ý: list comprehension hoặc `operator.itemgetter`.)*
70. Hàm `pipe(*funcs)` tạo pipeline xử lý dữ liệu tuần tự. *(Gợi ý: `functools.reduce` để compose.)*
71. Lớp `OrderRepository` với `add`, `find_by_customer`, `find_by_status`. *(Gợi ý: nhiều dict index để tra cứu nhanh.)*
72. Dùng `__eq__` và `__hash__` để `Product` bỏ được vào `set` theo `id`. *(Gợi ý: định nghĩa hash theo khoá bất biến.)*
73. Viết generator `iter_details(order_id)` yield từng dòng chi tiết. *(Gợi ý: `yield`, lazy evaluation.)*
74. Viết context manager ghi log mở/đóng một "transaction" tính toán. *(Gợi ý: `contextlib.contextmanager`.)*
75. Dùng `Enum` cho `OrderStatus` thay cho chuỗi tự do. *(Gợi ý: `enum.Enum`.)*
76. Tạo custom exception `InvalidDiscountError` và validate `discount` 0..100. *(Gợi ý: kế thừa `Exception`.)*
77. Hàm `safe_div(a, b, default=0)` xử lý chia 0 khi tính AOV. *(Gợi ý: try/except hoặc kiểm tra trước.)*
78. Lớp `MovingAverage(window)` cập nhật trung bình trượt theo stream. *(Gợi ý: `deque(maxlen=window)` + biến tổng.)*
79. Viết `__repr__` gọn cho `Order` để debug. *(Gợi ý: f-string trong `__repr__`.)*
80. Dùng `functools.singledispatch` để format báo cáo khác nhau theo kiểu dữ liệu. *(Gợi ý: single dispatch theo type.)*

---

## Phần 5 — 20 bài thuật toán & cấu trúc dữ liệu nâng cao

81. Dùng `heapq` duy trì top-5 khách chi tiêu cao khi dữ liệu chảy theo stream. *(Gợi ý: min-heap kích thước cố định.)*
82. Kết hợp median giá trị đơn theo `payment_method`. *(Gợi ý: sort từng nhóm + lấy phần tử giữa, hoặc two-heaps.)*
83. Streaming median giá trị đơn (cập nhật liên tục). *(Gợi ý: hai heap (max-heap + min-heap) cân bằng.)*
84. Z-score doanh thu từng khách so với toàn bộ. *(Gợi ý: tính mean/stddev một lượt, `statistics`.)*
85. Basket analysis: top cặp sản phẩm hay mua chung một đơn. *(Gợi ý: `itertools.combinations` + `Counter` theo cặp.)*
86. Tìm sản phẩm đồng xuất hiện bằng đồ thị kề. *(Gợi ý: `defaultdict(set)` làm adjacency list.)*
87. Phát hiện thành phần liên thông của đồ thị đồng mua (cụm sản phẩm). *(Gợi ý: BFS/DFS trên adjacency list, `deque`.)*
88. Union-Find gộp các khách hàng trùng (cùng email/điện thoại). *(Gợi ý: Disjoint Set Union với path compression.)*
89. Đề xuất sản phẩm "mua kèm" bằng xếp hạng đồng xuất hiện. *(Gợi ý: dict điểm số + `heapq.nlargest`.)*
90. LRU cache thủ công cho truy vấn `order_total` hay gọi lại. *(Gợi ý: `OrderedDict` hoặc `collections` + move-to-end.)*
91. Trie tra cứu nhanh sản phẩm theo tiền tố tên. *(Gợi ý: cây Trie bằng dict lồng nhau.)*
92. Tìm k sản phẩm giá gần nhất với một mức giá cho trước. *(Gợi ý: sort + binary search `bisect`, lấy 2 phía.)*
93. Dùng `bisect` chèn đơn mới vào list luôn giữ thứ tự ngày. *(Gợi ý: `bisect.insort`.)*
94. Lập lịch giao hàng không chồng khung giờ (interval scheduling). *(Gợi ý: sort theo giờ kết thúc, greedy.)*
95. Gộp các khoảng khuyến mãi chồng nhau thành khoảng lớn. *(Gợi ý: sort theo start, merge intervals.)*
96. Prefix sum doanh thu để truy vấn tổng khoảng ngày bất kỳ O(1). *(Gợi ý: mảng tích luỹ.)*
97. Sliding window maximum doanh thu ngày trong cửa sổ k. *(Gợi ý: `deque` đơn điệu (monotonic queue).)*
98. Phân trang (pagination) list đơn với `page`, `page_size`. *(Gợi ý: slicing, `itertools.islice` cho iterator.)*
99. Đọc dữ liệu rất lớn theo dòng mà không nạp hết vào RAM. *(Gợi ý: generator pipeline, lazy evaluation.)*
100. Thiết kế mini in-memory "query engine": `filter → group → aggregate → sort` ghép chuỗi được. *(Gợi ý: kết hợp iterator/generator, dict index, heap — tổng hợp mọi kỹ thuật trên.)*

---

## Lộ trình học gợi ý

- **Phần 1–2:** nắm vững `list`, `dict`, `set`, `tuple`, `Counter`, `defaultdict` — nền tảng mọi xử lý dữ liệu.
- **Phần 3:** thời gian, sắp xếp đa khoá, `heapq`, `deque`, cửa sổ trượt.
- **Phần 4:** đóng gói code bằng hàm/lớp, generator, decorator — viết code sạch và tái dùng.
- **Phần 5:** thuật toán & cấu trúc nâng cao (heap, graph, trie, union-find, bisect, prefix sum, monotonic queue).

## Bảng tra cứu nhanh Data Structure

| Nhu cầu | Cấu trúc nên dùng |
|---|---|
| Khử trùng, kiểm tra tồn tại O(1) | `set` / `frozenset` |
| Tra cứu theo khoá, index dữ liệu | `dict` |
| Đếm tần suất | `collections.Counter` |
| Gom nhóm | `collections.defaultdict` |
| Hàng đợi, cửa sổ trượt | `collections.deque` |
| Top-k, streaming priority | `heapq` |
| Giữ list luôn sắp xếp, tìm nhị phân | `bisect` |
| Cache | `functools.lru_cache` / `OrderedDict` |
| Đồ thị | adjacency list (`defaultdict(set)`) + BFS/DFS |
| Gộp nhóm liên thông | Union-Find (DSU) |
| Tra cứu theo tiền tố | Trie (dict lồng nhau) |
| Xử lý dữ liệu lớn/lazy | generator + `itertools` |
