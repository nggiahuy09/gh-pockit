# W5 — UI brief cho list giao dịch

Brief để dựng file design cho phần UI của W5 (_W5 Flex_ trong `ROADMAP.md`). Mọi giá trị dưới đây lấy từ code (`lib/core/theme/`, ADR-0005), nên design
dùng đúng các giá trị này thì code không phải đổi.

## 1. Design system hiện có trong code

### Màu — primitive

| Token         | Hex       | Token      | Hex       |
| ------------- | --------- | ---------- | --------- |
| `white`       | `#FFFFFF` | `clay100`  | `#F6E5DC` |
| `ivory50`     | `#FAF9F5` | `clay400`  | `#E0906F` |
| `ivory100`    | `#F5F4EF` | `clay500`  | `#D97757` |
| `ivory200`    | `#F0EEE6` | `clay600`  | `#C15F3C` |
| `paper`       | `#F5F4EF` | `clay700`  | `#A84F2E` |
| `warmGrey200` | `#E8E6DC` | `clay800`  | `#7A3A22` |
| `warmGrey300` | `#DEDCD1` | `clay900`  | `#4A2D22` |
| `warmGrey400` | `#B8B5AC` | `green400` | `#5FA681` |
| `warmGrey500` | `#828179` | `green600` | `#2F6E4E` |
| `warmGrey600` | `#6B6862` | `green700` | `#23593E` |
| `warmGrey700` | `#43423E` | `amber400` | `#D9A445` |
| `warmGrey750` | `#3A3937` | `amber500` | `#B8821F` |
| `warmGrey800` | `#30302E` | `amber700` | `#7A5512` |
| `warmGrey900` | `#262624` | `red400`   | `#E27A70` |
| `warmGrey950` | `#1F1E1D` | `red500`   | `#A8332A` |
| `ink`         | `#141413` | `red700`   | `#6E211B` |
| `shadowWarm`  | `#3D3A32` |            |           |

### Màu — role (light / dark)

| Role                 | Light                 | Dark                  |
| -------------------- | --------------------- | --------------------- |
| `primary`            | `ink` #141413         | `paper` #F5F4EF       |
| `onPrimary`          | `ivory50` #FAF9F5     | `warmGrey950` #1F1E1D |
| `primaryContainer`   | `ivory200` #F0EEE6    | `warmGrey700` #43423E |
| `onPrimaryContainer` | `ink` #141413         | `paper` #F5F4EF       |
| `accent`             | `clay500` #D97757     | `clay400` #E0906F     |
| `onAccent`           | `ink` #141413         | `warmGrey950` #1F1E1D |
| `accentContainer`    | `clay100` #F6E5DC     | `clay900` #4A2D22     |
| `onAccentContainer`  | `clay800` #7A3A22     | `clay400` #E0906F     |
| `accentInk`          | `clay700` #A84F2E     | `clay400` #E0906F     |
| `background`         | `ivory50` #FAF9F5     | `warmGrey900` #262624 |
| `onBackground`       | `ink` #141413         | `paper` #F5F4EF       |
| `surface`            | `white` #FFFFFF       | `warmGrey800` #30302E |
| `onSurface`          | `ink` #141413         | `paper` #F5F4EF       |
| `surfaceVariant`     | `ivory200` #F0EEE6    | `warmGrey750` #3A3937 |
| `onSurfaceVariant`   | `warmGrey600` #6B6862 | `warmGrey400` #B8B5AC |
| `outline`            | `warmGrey300` #DEDCD1 | `warmGrey700` #43423E |
| `outlineVariant`     | `warmGrey200` #E8E6DC | `warmGrey750` #3A3937 |
| `success`            | `green600` #2F6E4E    | `green400` #5FA681    |
| `warning`            | `amber500` #B8821F    | `amber400` #D9A445    |
| `danger`             | `red500` #A8332A      | `red400` #E27A70      |
| `income`             | `green600` #2F6E4E    | `green400` #5FA681    |
| `expense`            | `red500` #A8332A      | `red400` #E27A70      |

Ràng buộc đã có test (`test/core/theme/contrast_test.dart`):

- Chữ thường và số tiền ≥ 4.5:1 trên mọi nền chúng nằm; chữ lớn, icon, viền control ≥ 3:1.
- `income` và `expense` cố ý gần cùng độ sáng, chỉ khác hue — **dấu `+` / `-` mới là thứ mang nghĩa**, màu chỉ lặp lại (WCAG 1.4.1).
- Focus ring dùng `accentInk`, không dùng `accent` (`accent` chỉ đạt 2.96:1 trên nền light).

### Chữ — Inter (subset Latin + tiếng Việt)

| Role             | Size | Weight | Line height | Tracking |
| ---------------- | ---- | ------ | ----------- | -------- |
| `displayLarge`   | 40   | 700    | 1.1         | -0.6     |
| `displayMedium`  | 32   | 700    | 1.1         | -0.6     |
| `displaySmall`   | 28   | 600    | 1.1         | -0.6     |
| `headlineLarge`  | 24   | 600    | 1.25        | -0.2     |
| `headlineMedium` | 22   | 600    | 1.25        | -0.2     |
| `headlineSmall`  | 20   | 600    | 1.25        | -0.2     |
| `titleLarge`     | 18   | 600    | 1.25        | -0.2     |
| `titleMedium`    | 16   | 500    | 1.25        | -0.2     |
| `titleSmall`     | 14   | 500    | 1.25        | -0.2     |
| `bodyLarge`      | 16   | 400    | 1.45        | 0        |
| `bodyMedium`     | 14   | 400    | 1.45        | 0        |
| `bodySmall`      | 13   | 400    | 1.45        | 0        |
| `labelLarge`     | 14   | 500    | 1.35        | 0.2      |
| `labelMedium`    | 12   | 500    | 1.35        | 0.2      |
| `labelSmall`     | 11   | 500    | 1.35        | 0.2      |

Số tiền dùng chữ số tabular (`tnum`, font đã giữ feature này) để các cột số thẳng hàng.

### Spacing, radius, motion, shadow

| Spacing    | `none` 0 · `xxs` 2 · `xs` 4 · `sm` 8 · `smd` 12 · `md` 16 · `lg` 24 · `xl` 32 · `xxl` 48 · `xxxl` 64 |
| ---------- | ---------------------------------------------------------------------------------------------------- |
| Radius     | `none` 0 · `sm` 6 · `md` 10 · `lg` 16 · `xl` 24 · `full` 9999                                        |
| Motion     | `fast` 120ms · `normal` 220ms · `slow` 360ms                                                         |
| Breakpoint | `tablet` 600 · `desktop` 1024                                                                        |

Shadow (màu `shadowWarm` #3D3A32, alpha thấp; dark mode không có shadow):

| Token        | Lớp                                      |
| ------------ | ---------------------------------------- |
| `small`      | 4% · blur 2 · y 1                        |
| `medium`     | 6% · blur 8 · y 2 + 4% · blur 2 · y 1    |
| `large`      | 8% · blur 20 · y 8 + 4% · blur 6 · y 2   |
| `extraLarge` | 12% · blur 32 · y 12 + 6% · blur 8 · y 4 |

### Component đã có

- **`GPButton`** — variant `primary` (nền `ink`), `accent` (terracotta, chỉ cho hành động định nghĩa màn hình, vd. "thêm giao dịch"), `tonal`,
  `outlined`, `text`, `danger`. Cỡ `small` 40 / `medium` 48 / `large` 56; label weight 600. Loading thay icon trái bằng spinner. Focus ring là shadow
  full-opacity theo màu variant, không phải border.
- **`GPEmptyState`** — icon + title + message tuỳ chọn + một action tuỳ chọn; cuộn được khi màn hình thấp.

## 2. Tối thiểu cho W5

Đủ để đạt "Done khi" (ghi một row → list tự cập nhật) và hết _W5 Flex_.

### Màn Giao dịch (tab Transactions)

- **App bar**: "Giao dịch" / "Transactions".
- **Header ngày**: "Hôm nay", "Hôm qua", "Thứ Hai, 5 tháng 10" (năm chỉ khi khác năm nay: "Thứ Tư, 31 tháng 12, 2025"). EN: "Today", "Yesterday",
  "Monday, October 5".
- **Dòng giao dịch**:
  - Tiêu đề: note; không có note thì nhãn loại — "Chi tiêu" / "Thu nhập" / "Chuyển khoản".
  - Số tiền bên phải: expense `-45.000 ₫` (màu `expense`), income `+45.000 ₫` (màu `income`), transfer `45.000 ₫` (màu trung tính). EN đặt dấu
    trước ký hiệu: `-₫45,000`.
- **Footer tải thêm**: spinner ở cuối khi cửa sổ còn dữ liệu. Không có nút "tải thêm" — cuộn tới gần cuối là tự tải.
- Không có pull-to-refresh: list tự cập nhật khi dữ liệu đổi.

### `GPMoneyText`

Text số tiền dùng chung: chữ số tabular, 3 kiểu `expense` / `income` / `neutral`, nhận style chữ từ chỗ dùng.

### Trạng thái (T5)

| Trạng thái          | Khi nào                          | Nội dung cần design                                              |
| ------------------- | -------------------------------- | ---------------------------------------------------------------- |
| Loading             | Lần tải đầu, hoặc vừa đổi filter | Spinner hoặc skeleton                                            |
| Empty               | Chưa có giao dịch nào            | Icon + tiêu đề + mô tả (`GPEmptyState`)                          |
| Error, chưa có dòng | Query lỗi trước khi có dữ liệu   | `GPEmptyState` kiểu lỗi; không có nút thử lại                    |
| Error, đã có dòng   | Query lỗi khi list đang hiện     | Banner/strip báo lỗi, các dòng vẫn hiện bên dưới                 |
| Dòng không đọc được | Có N dòng dữ liệu hỏng           | Thông báo nhẹ "N giao dịch không hiển thị được", không chặn list |

Không có nút "thử lại" ở các trạng thái lỗi: list tự hồi khi dữ liệu ghi tiếp theo vào bảng.

### Ngoài phạm vi design

- Nút "thêm giao dịch mẫu" trong Settings — chỉ có ở bản debug.

## 3. Tối đa vẫn trong phạm vi W5

- Biến thể dòng: có / không note, note dài bị cắt (1 dòng, ellipsis), transfer có icon mũi tên, trạng thái pressed (chạm chưa mở gì — chi tiết là W6).
- Header ngày dính khi cuộn (sticky) hay không.
- Light + dark cho mọi màn và trạng thái.
- Độ dài chữ tiếng Việt vs tiếng Anh; cỡ chữ hệ thống lớn (accessibility).
- Hình/icon cho empty và error.
- Polish `AccountsPage` (list account: tên, nhãn loại, số dư ban đầu) — hiện là UI thô.

## 4. Design trước được, không làm trong W5

| Thứ                                           | Tuần                    |
| --------------------------------------------- | ----------------------- |
| Icon + tên category, tên account trên dòng    | W8                      |
| "Chưa phân loại" cho category đã xoá          | W8                      |
| Tổng tiền theo ngày trên header               | W8                      |
| Nút thêm giao dịch (accent), form tạo / sửa   | W6                      |
| Xoá + undo (snackbar)                         | W6                      |
| Dashboard: thu/chi tháng + số dư từng account | W6                      |
| Thanh lọc (ngày, account, category, loại)     | W26                     |
| Nút đổi theme light/dark                      | chưa có lịch (ADR-0005) |
