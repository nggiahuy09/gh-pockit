# Pockit — Design System source

Nguồn để dựng design system của **Pockit** trên Claude Design. Mọi giá trị dưới đây đọc trực tiếp từ codebase (Flutter, `lib/core/theme/`,
`lib/core/widgets/`, `lib/app/theme/`, ADR-0005 / ADR-0008) ngày 2026-10-06 — dùng đúng các giá trị này thì prototype và UI sau này khớp code mà
không phải đổi. Mục nào **chưa có trong code** được đánh dấu _Đề xuất_.

---

## 1. Sản phẩm

- **Pockit** — app quản lý tài chính cá nhân, **offline-first**: dữ liệu nằm trên máy, UI đọc từ DB local, đồng bộ chạy nền. Không có màn hình nào
  "chờ mạng".
- Nền tảng: **Android trước**, iOS sau. Mobile portrait là chính; breakpoint tablet có sẵn nhưng chưa dùng.
- Ngôn ngữ: **Tiếng Việt** và **English**, đổi trong Settings, lưu trên máy. Mặc định VND.
- Tiền luôn là số nguyên đơn vị nhỏ nhất (VND không có số lẻ; USD có 2 số lẻ). Không bao giờ làm tròn hiển thị.
- 5 tab: **Trang chủ · Tài khoản · Giao dịch · Ngân sách · Cài đặt**.

## 2. Thương hiệu

### App icon

Túi (pocket) đựng một tấm thẻ, đường biểu đồ tăng trưởng vọt lên, mũi tên phá ra khỏi mép thẻ. Flat hình học, không glass/3D. File nguồn:
`docs/design/app-icon/gh-pockit-icon.svg` (canvas 1024).

| Vai trò                  | Hex                   |
| ------------------------ | --------------------- |
| Nền gradient — sáng      | `#E3906F`             |
| Nền gradient — tối       | `#BC5B39`             |
| Cam thương hiệu (phẳng)  | `#D97757`             |
| Túi — kem sáng / tối     | `#F2F0E9` / `#E4E0D4` |
| Thẻ — manilla sáng / tối | `#F3E7CE` / `#DFCBA6` |
| Đường biểu đồ — mực      | `#191919`             |

Gradient nền: linear từ (80,0) tới (944,1024), cộng radial glow trắng 20% tâm (270,230) bán kính 820.

### Tính cách thị giác

- Nền **ấm**: ivory và warm grey, không phải xám trung tính hay trắng lạnh.
- **Terracotta (clay)** là màu thương hiệu, dùng tiết kiệm: một hành động định nghĩa màn hình, trạng thái được chọn của tab.
- Hành động chính mặc định là **mực (ink)** trên nền sáng — không phải màu thương hiệu.
- Phẳng: không splash ripple (`NoSplash`), không elevation Material, không surface tint. Chiều sâu chỉ bằng token shadow ấm, và dark mode **không có
  shadow** — bề mặt tách nhau bằng độ sáng.
- Đỏ hủy (`danger`) cố ý đỏ hơn terracotta để nút xóa không bị nhầm với nút accent.

## 3. Font

**Inter 4.1**, bundle trong app (không tải mạng lúc chạy — offline-first), subset **Latin + Tiếng Việt** (511 codepoint, có `₫`, `€`, `−`, ngoặc
cong, gạch ngang, `ă đ ơ ư` và mọi nguyên âm có dấu). File: `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf` — weight 400/500/600/700.
Không có italic. License SIL OFL 1.1. Trên Claude Design có thể dùng Inter của Google Fonts — cùng thiết kế.

- Số tiền dùng **chữ số tabular** (`font-feature-settings: "tnum"`), subset giữ feature này.
- Cỡ chữ nhỏ nhất: **11** — dưới mức đó Inter không đọc được trên màn Android DPI thấp.

## 4. Màu

### 4.1 Primitive

Chỉ `core/theme/` đọc primitive; widget luôn dùng **role** (4.2).

| Token         | Hex       | Ghi chú                                                                                     |
| ------------- | --------- | ------------------------------------------------------------------------------------------- |
| `white`       | `#FFFFFF` |                                                                                             |
| `ivory50`     | `#FAF9F5` | Nền light                                                                                   |
| `ivory100`    | `#F5F4EF` |                                                                                             |
| `ivory200`    | `#F0EEE6` |                                                                                             |
| `paper`       | `#F5F4EF` | Chữ trên nền dark                                                                           |
| `warmGrey200` | `#E8E6DC` |                                                                                             |
| `warmGrey300` | `#DEDCD1` |                                                                                             |
| `warmGrey400` | `#B8B5AC` |                                                                                             |
| `warmGrey500` | `#828179` |                                                                                             |
| `warmGrey600` | `#6B6862` |                                                                                             |
| `warmGrey700` | `#43423E` |                                                                                             |
| `warmGrey750` | `#3A3937` |                                                                                             |
| `warmGrey800` | `#30302E` |                                                                                             |
| `warmGrey900` | `#262624` | Nền dark                                                                                    |
| `warmGrey950` | `#1F1E1D` |                                                                                             |
| `ink`         | `#141413` | Chữ / hành động chính trên light                                                            |
| `clay100`     | `#F6E5DC` |                                                                                             |
| `clay400`     | `#E0906F` |                                                                                             |
| `clay500`     | `#D97757` | Accent. Chữ trắng trên nó chỉ 3.1:1 — không phải màu hành động                              |
| `clay600`     | `#C15F3C` |                                                                                             |
| `clay700`     | `#A84F2E` | Accent dạng chữ/icon: `clay500` chỉ 2.96:1 trên `ivory50`                                   |
| `clay800`     | `#7A3A22` |                                                                                             |
| `clay900`     | `#4A2D22` |                                                                                             |
| `green400`    | `#5FA681` |                                                                                             |
| `green600`    | `#2F6E4E` | Tối hơn trông có vẻ cần, để chữ sáng trên nó đạt 4.5:1                                      |
| `green700`    | `#23593E` |                                                                                             |
| `amber400`    | `#D9A445` |                                                                                             |
| `amber500`    | `#B8821F` | Nhận nội dung tối: không amber nào còn là amber mà đạt 4.5:1 với trắng                      |
| `amber700`    | `#7A5512` |                                                                                             |
| `red400`      | `#E27A70` | Sáng hơn trông có vẻ cần: số tiền expense là chữ cỡ body, phải đạt 4.5:1 trên `warmGrey900` |
| `red500`      | `#A8332A` | Đỏ hơn terracotta để nút xóa không giống accent                                             |
| `red700`      | `#6E211B` |                                                                                             |
| `shadowWarm`  | `#3D3A32` | Màu của mọi shadow (đen trên nền ivory trông như vết bẩn)                                   |

### 4.2 Role (light / dark)

| Role                 | Light                 | Dark                  | Dùng cho                                                |
| -------------------- | --------------------- | --------------------- | ------------------------------------------------------- |
| `primary`            | `#141413` ink         | `#F5F4EF` paper       | Nút chính, snackbar                                     |
| `onPrimary`          | `#FAF9F5` ivory50     | `#1F1E1D` warmGrey950 | Chữ trên `primary`                                      |
| `primaryContainer`   | `#F0EEE6` ivory200    | `#43423E` warmGrey700 | Nút tonal                                               |
| `onPrimaryContainer` | `#141413`             | `#F5F4EF`             | Chữ trên `primaryContainer`                             |
| `accent`             | `#D97757` clay500     | `#E0906F` clay400     | Nền nút accent (một hành động định nghĩa màn hình)      |
| `onAccent`           | `#141413`             | `#1F1E1D`             | Chữ trên `accent` — luôn tối                            |
| `accentContainer`    | `#F6E5DC` clay100     | `#4A2D22` clay900     | Indicator của tab được chọn                             |
| `onAccentContainer`  | `#7A3A22` clay800     | `#E0906F` clay400     | Icon tab được chọn                                      |
| `accentInk`          | `#A84F2E` clay700     | `#E0906F` clay400     | Accent dạng chữ/icon, focus ring của nút primary/accent |
| `background`         | `#FAF9F5` ivory50     | `#262624` warmGrey900 | Nền màn hình, app bar, navigation bar                   |
| `onBackground`       | `#141413`             | `#F5F4EF`             | Chữ trên nền                                            |
| `surface`            | `#FFFFFF` white       | `#30302E` warmGrey800 | Card                                                    |
| `onSurface`          | `#141413`             | `#F5F4EF`             | Chữ trên card                                           |
| `surfaceVariant`     | `#F0EEE6` ivory200    | `#3A3937` warmGrey750 | Bề mặt phụ; nền nút disabled                            |
| `onSurfaceVariant`   | `#6B6862` warmGrey600 | `#B8B5AC` warmGrey400 | Chữ phụ, icon chưa chọn, chữ disabled                   |
| `outline`            | `#DEDCD1` warmGrey300 | `#43423E` warmGrey700 | Viền nút outlined                                       |
| `outlineVariant`     | `#E8E6DC` warmGrey200 | `#3A3937` warmGrey750 | Divider, viền outlined disabled                         |
| `success`            | `#2F6E4E` green600    | `#5FA681` green400    |                                                         |
| `onSuccess`          | `#FAF9F5`             | `#1F1E1D`             |                                                         |
| `warning`            | `#B8821F` amber500    | `#D9A445` amber400    |                                                         |
| `onWarning`          | `#141413`             | `#1F1E1D`             |                                                         |
| `danger`             | `#A8332A` red500      | `#E27A70` red400      | Nút xóa, lỗi                                            |
| `onDanger`           | `#FAF9F5`             | `#1F1E1D`             |                                                         |
| `income`             | `#2F6E4E` green600    | `#5FA681` green400    | Số tiền thu                                             |
| `expense`            | `#A8332A` red500      | `#E27A70` red400      | Số tiền chi                                             |

### 4.3 Quy tắc contrast (là cổng build — `test/core/theme/contrast_test.dart`)

- Chữ cỡ thường và **số tiền**: ≥ **4.5:1** trên mọi nền nó nằm (cả `background` lẫn `surface`).
- Chữ lớn, icon, viền control, focus ring: ≥ **3:1**.
- `onSurfaceVariant` phải đọc được trên `background`, không chỉ trên `surfaceVariant` (dòng phụ của list nằm thẳng trên nền).
- `outline` đậm hơn `outlineVariant`; divider chỉ cần "thấy được", không cần 3:1.
- `income` và `expense` cố ý **cùng độ sáng, khác hue** — vì vậy **dấu `+` / `-` mang nghĩa**, màu chỉ lặp lại (WCAG 1.4.1, người mù màu đỏ-xanh).
- Không dùng `accent` làm chữ hay focus ring trên nền light — dùng `accentInk`.

## 5. Chữ — type scale

Font `Inter`. Style **không mang màu** — màu lấy từ ngữ cảnh (role).

| Role             | Size | Weight | Line height | Tracking | Dùng hiện tại                        |
| ---------------- | ---- | ------ | ----------- | -------- | ------------------------------------ |
| `displayLarge`   | 40   | 700    | 1.1         | -0.6     |                                      |
| `displayMedium`  | 32   | 700    | 1.1         | -0.6     |                                      |
| `displaySmall`   | 28   | 600    | 1.1         | -0.6     |                                      |
| `headlineLarge`  | 24   | 600    | 1.25        | -0.2     |                                      |
| `headlineMedium` | 22   | 600    | 1.25        | -0.2     | Tiêu đề app bar                      |
| `headlineSmall`  | 20   | 600    | 1.25        | -0.2     |                                      |
| `titleLarge`     | 18   | 600    | 1.25        | -0.2     | Tiêu đề empty state                  |
| `titleMedium`    | 16   | 500    | 1.25        | -0.2     | Label nút medium/large (đẩy lên 600) |
| `titleSmall`     | 14   | 500    | 1.25        | -0.2     | Label nút small (đẩy lên 600)        |
| `bodyLarge`      | 16   | 400    | 1.45        | 0        |                                      |
| `bodyMedium`     | 14   | 400    | 1.45        | 0        | Mô tả empty state, snackbar          |
| `bodySmall`      | 13   | 400    | 1.45        | 0        |                                      |
| `labelLarge`     | 14   | 500    | 1.35        | 0.2      |                                      |
| `labelMedium`    | 12   | 500    | 1.35        | 0.2      | Label navigation bar                 |
| `labelSmall`     | 11   | 500    | 1.35        | 0.2      | Cỡ nhỏ nhất cho phép                 |

## 6. Spacing · Radius · Shadow · Motion · Breakpoint

| Spacing | Giá trị            |     | Radius | Giá trị            |
| ------- | ------------------ | --- | ------ | ------------------ |
| `xxs`   | 2                  |     | `none` | 0                  |
| `xs`    | 4                  |     | `sm`   | 6                  |
| `sm`    | 8                  |     | `md`   | 10 — nút, snackbar |
| `smd`   | 12                 |     | `lg`   | 16 — card          |
| `md`    | 16                 |     | `xl`   | 24                 |
| `lg`    | 24                 |     | `full` | 9999 — pill / tròn |
| `xl`    | 32                 |     |        |                    |
| `xxl`   | 48                 |     |        |                    |
| `xxxl`  | 64 (chỉ primitive) |     |        |                    |

Shadow — màu `#3D3A32`; dark mode: **không có shadow**.

| Token        | CSS                                                              |
| ------------ | ---------------------------------------------------------------- |
| `small`      | `0 1px 2px rgba(61,58,50,0.04)`                                  |
| `medium`     | `0 2px 8px rgba(61,58,50,0.06), 0 1px 2px rgba(61,58,50,0.04)`   |
| `large`      | `0 8px 20px rgba(61,58,50,0.08), 0 2px 6px rgba(61,58,50,0.04)`  |
| `extraLarge` | `0 12px 32px rgba(61,58,50,0.12), 0 4px 8px rgba(61,58,50,0.06)` |

Motion: `fast` 120ms (đổi trạng thái nút) · `normal` 220ms · `slow` 360ms. Breakpoint: `tablet` ≥ 600 · `desktop` ≥ 1024 (chưa dùng).

## 7. tokens.json

Cùng giá trị như trên, ở đúng định dạng design system đọc (mỗi họ là một **danh sách** `{name, value, usage}`, theme light đứng trước).

```json
{
  "name": "Pockit",
  "version": 1,
  "color": {
    "themes": [
      { "id": "light", "name": "Light" },
      { "id": "dark", "name": "Dark" }
    ],
    "tokens": [
      {
        "name": "primary",
        "value": { "light": "#141413", "dark": "#F5F4EF" },
        "usage": "Primary button fill, snackbar."
      },
      {
        "name": "onPrimary",
        "value": { "light": "#FAF9F5", "dark": "#1F1E1D" },
        "usage": "Text and icons on primary."
      },
      {
        "name": "primaryContainer",
        "value": { "light": "#F0EEE6", "dark": "#43423E" },
        "usage": "Tonal button fill."
      },
      {
        "name": "onPrimaryContainer",
        "value": { "light": "#141413", "dark": "#F5F4EF" },
        "usage": "Text on primaryContainer."
      },
      {
        "name": "accent",
        "value": { "light": "#D97757", "dark": "#E0906F" },
        "usage": "Accent button fill: the one gesture that defines a screen. Never text on light."
      },
      {
        "name": "onAccent",
        "value": { "light": "#141413", "dark": "#1F1E1D" },
        "usage": "Text on accent — always dark; white on it is 3.1:1."
      },
      {
        "name": "accentContainer",
        "value": { "light": "#F6E5DC", "dark": "#4A2D22" },
        "usage": "Selected tab indicator."
      },
      {
        "name": "onAccentContainer",
        "value": { "light": "#7A3A22", "dark": "#E0906F" },
        "usage": "Selected tab icon."
      },
      {
        "name": "accentInk",
        "value": { "light": "#A84F2E", "dark": "#E0906F" },
        "usage": "The accent as text or icon; focus ring of primary and accent buttons."
      },
      {
        "name": "background",
        "value": { "light": "#FAF9F5", "dark": "#262624" },
        "usage": "Screen, app bar and navigation bar ground."
      },
      {
        "name": "onBackground",
        "value": { "light": "#141413", "dark": "#F5F4EF" },
        "usage": "Text on background."
      },
      {
        "name": "surface",
        "value": { "light": "#FFFFFF", "dark": "#30302E" },
        "usage": "Cards."
      },
      {
        "name": "onSurface",
        "value": { "light": "#141413", "dark": "#F5F4EF" },
        "usage": "Text on surface."
      },
      {
        "name": "surfaceVariant",
        "value": { "light": "#F0EEE6", "dark": "#3A3937" },
        "usage": "Secondary surfaces; disabled button fill."
      },
      {
        "name": "onSurfaceVariant",
        "value": { "light": "#6B6862", "dark": "#B8B5AC" },
        "usage": "Secondary text, unselected icons, disabled text. 4.5:1 on background too."
      },
      {
        "name": "outline",
        "value": { "light": "#DEDCD1", "dark": "#43423E" },
        "usage": "Outlined button border."
      },
      {
        "name": "outlineVariant",
        "value": { "light": "#E8E6DC", "dark": "#3A3937" },
        "usage": "Dividers; disabled outlined border."
      },
      {
        "name": "success",
        "value": { "light": "#2F6E4E", "dark": "#5FA681" },
        "usage": "Positive status."
      },
      {
        "name": "onSuccess",
        "value": { "light": "#FAF9F5", "dark": "#1F1E1D" },
        "usage": "Text on success."
      },
      {
        "name": "warning",
        "value": { "light": "#B8821F", "dark": "#D9A445" },
        "usage": "Caution status; takes dark content."
      },
      {
        "name": "onWarning",
        "value": { "light": "#141413", "dark": "#1F1E1D" },
        "usage": "Text on warning."
      },
      {
        "name": "danger",
        "value": { "light": "#A8332A", "dark": "#E27A70" },
        "usage": "Destructive buttons, errors. Redder than the accent on purpose."
      },
      {
        "name": "onDanger",
        "value": { "light": "#FAF9F5", "dark": "#1F1E1D" },
        "usage": "Text on danger."
      },
      {
        "name": "income",
        "value": { "light": "#2F6E4E", "dark": "#5FA681" },
        "usage": "Income amounts, always with a + sign."
      },
      {
        "name": "expense",
        "value": { "light": "#A8332A", "dark": "#E27A70" },
        "usage": "Expense amounts, always with a - sign."
      },
      {
        "name": "shadowWarm",
        "value": "#3D3A32",
        "usage": "Base color of every shadow, at low alpha."
      }
    ]
  },
  "type": {
    "families": { "sans": "\"Inter\", system-ui, sans-serif" },
    "groups": [
      {
        "name": "Display",
        "family": "sans",
        "styles": [
          {
            "name": "displayLarge",
            "fontSize": "40px",
            "lineHeight": 1.1,
            "fontWeight": 700,
            "letterSpacing": "-0.6px"
          },
          {
            "name": "displayMedium",
            "fontSize": "32px",
            "lineHeight": 1.1,
            "fontWeight": 700,
            "letterSpacing": "-0.6px"
          },
          {
            "name": "displaySmall",
            "fontSize": "28px",
            "lineHeight": 1.1,
            "fontWeight": 600,
            "letterSpacing": "-0.6px"
          }
        ]
      },
      {
        "name": "Headline",
        "family": "sans",
        "styles": [
          {
            "name": "headlineLarge",
            "fontSize": "24px",
            "lineHeight": 1.25,
            "fontWeight": 600,
            "letterSpacing": "-0.2px"
          },
          {
            "name": "headlineMedium",
            "fontSize": "22px",
            "lineHeight": 1.25,
            "fontWeight": 600,
            "letterSpacing": "-0.2px"
          },
          {
            "name": "headlineSmall",
            "fontSize": "20px",
            "lineHeight": 1.25,
            "fontWeight": 600,
            "letterSpacing": "-0.2px"
          }
        ]
      },
      {
        "name": "Title",
        "family": "sans",
        "styles": [
          {
            "name": "titleLarge",
            "fontSize": "18px",
            "lineHeight": 1.25,
            "fontWeight": 600,
            "letterSpacing": "-0.2px"
          },
          {
            "name": "titleMedium",
            "fontSize": "16px",
            "lineHeight": 1.25,
            "fontWeight": 500,
            "letterSpacing": "-0.2px"
          },
          {
            "name": "titleSmall",
            "fontSize": "14px",
            "lineHeight": 1.25,
            "fontWeight": 500,
            "letterSpacing": "-0.2px"
          }
        ]
      },
      {
        "name": "Body",
        "family": "sans",
        "styles": [
          {
            "name": "bodyLarge",
            "fontSize": "16px",
            "lineHeight": 1.45,
            "fontWeight": 400,
            "letterSpacing": "0px"
          },
          {
            "name": "bodyMedium",
            "fontSize": "14px",
            "lineHeight": 1.45,
            "fontWeight": 400,
            "letterSpacing": "0px"
          },
          {
            "name": "bodySmall",
            "fontSize": "13px",
            "lineHeight": 1.45,
            "fontWeight": 400,
            "letterSpacing": "0px"
          }
        ]
      },
      {
        "name": "Label",
        "family": "sans",
        "styles": [
          {
            "name": "labelLarge",
            "fontSize": "14px",
            "lineHeight": 1.35,
            "fontWeight": 500,
            "letterSpacing": "0.2px"
          },
          {
            "name": "labelMedium",
            "fontSize": "12px",
            "lineHeight": 1.35,
            "fontWeight": 500,
            "letterSpacing": "0.2px"
          },
          {
            "name": "labelSmall",
            "fontSize": "11px",
            "lineHeight": 1.35,
            "fontWeight": 500,
            "letterSpacing": "0.2px"
          }
        ]
      }
    ]
  },
  "spacing": {
    "tokens": [
      { "name": "space-xxs", "value": "2px", "usage": "Hairline gaps." },
      {
        "name": "space-xs",
        "value": "4px",
        "usage": "Icon to text inside a chip."
      },
      {
        "name": "space-sm",
        "value": "8px",
        "usage": "Empty-state title to message; button icon gap."
      },
      {
        "name": "space-smd",
        "value": "12px",
        "usage": "Between related rows."
      },
      {
        "name": "space-md",
        "value": "16px",
        "usage": "Screen side padding; empty-state icon to title."
      },
      {
        "name": "space-lg",
        "value": "24px",
        "usage": "Empty-state vertical padding and gap to its action."
      },
      {
        "name": "space-xl",
        "value": "32px",
        "usage": "Empty-state side padding."
      },
      { "name": "space-xxl", "value": "48px", "usage": "Section breaks." }
    ]
  },
  "radius": {
    "tokens": [
      { "name": "radius-sm", "value": "6px", "usage": "Small chips and tags." },
      { "name": "radius-md", "value": "10px", "usage": "Buttons, snackbar." },
      { "name": "radius-lg", "value": "16px", "usage": "Cards." },
      { "name": "radius-xl", "value": "24px", "usage": "Sheets." },
      { "name": "radius-full", "value": "9999px", "usage": "Pills, circles." }
    ]
  },
  "shadow": {
    "tokens": [
      {
        "name": "shadow-small",
        "value": "0 1px 2px rgba(61,58,50,0.04)",
        "usage": "Light theme only."
      },
      {
        "name": "shadow-medium",
        "value": "0 2px 8px rgba(61,58,50,0.06), 0 1px 2px rgba(61,58,50,0.04)",
        "usage": "Light theme only."
      },
      {
        "name": "shadow-large",
        "value": "0 8px 20px rgba(61,58,50,0.08), 0 2px 6px rgba(61,58,50,0.04)",
        "usage": "Light theme only."
      },
      {
        "name": "shadow-xlarge",
        "value": "0 12px 32px rgba(61,58,50,0.12), 0 4px 8px rgba(61,58,50,0.06)",
        "usage": "Light theme only. Dark theme has no shadows."
      }
    ]
  }
}
```

## 8. Component — đã có trong code

### 8.1 `GPButton`

| Thuộc tính     | Giá trị                                                                                                                                                                                                                      |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cỡ             | `small` cao 40, padding ngang 14, icon 16, khoảng cách icon–chữ 6, label `titleSmall` w600 · `medium` (mặc định) 48, 20, icon 20, gap 8, label `titleMedium` w600 · `large` 56, 24, icon 20, gap 8, label `titleMedium` w600 |
| Bo góc         | `radius-md` 10                                                                                                                                                                                                               |
| Elevation      | 0, không ripple; overlay khi nhấn = màu chữ ở 8%                                                                                                                                                                             |
| Đổi trạng thái | 120ms                                                                                                                                                                                                                        |
| Label          | luôn là chữ, một dòng, ellipsis, căn giữa                                                                                                                                                                                    |

| Variant    | Nền                | Chữ / icon           | Viền          | Focus ring         |
| ---------- | ------------------ | -------------------- | ------------- | ------------------ |
| `primary`  | `primary`          | `onPrimary`          | —             | `accentInk`        |
| `accent`   | `accent`           | `onAccent`           | —             | `accentInk`        |
| `tonal`    | `primaryContainer` | `onPrimaryContainer` | —             | `onSurfaceVariant` |
| `outlined` | trong suốt         | `onBackground`       | `outline` 1px | `onSurfaceVariant` |
| `text`     | trong suốt         | `onBackground`       | —             | `onSurfaceVariant` |
| `danger`   | `danger`           | `onDanger`           | —             | `danger`           |

- **Disabled** (không có handler, hoặc đang loading): nền `surfaceVariant` (outlined/text vẫn trong suốt), chữ `onSurfaceVariant`, viền outlined
  `outlineVariant`, không focus ring.
- **Loading**: spinner (nét 2, màu chữ, cỡ = cỡ icon) thay icon trái, label giữ nguyên; icon phải ẩn. Nút không có icon trái sẽ rộng thêm bằng spinner
  — vì thế nút submit của form dùng `expanded` (full width).
- **Focus ring**: viền 2px **đặc 100%** vẽ bằng shadow (không đổi kích thước nút), hiện khi focus hoặc nhấn. Mờ đi sẽ chỉ còn ~1.5:1.
- `accent` dành cho **một** hành động định nghĩa màn hình (vd. "Thêm giao dịch"); hành động chính thông thường là `primary`.
- `small` (40) dưới chuẩn chạm 48 của Android — chỉ dùng trong một dòng mà cả dòng chạm được.
- Tùy chọn: `leading`, `trailing` (icon), `expanded` (full width).

### 8.2 `GPEmptyState`

Dùng cho cả trạng thái trống lẫn lỗi.

| Phần               | Spec                                                                  |
| ------------------ | --------------------------------------------------------------------- |
| Bố cục             | Căn giữa màn hình, cuộn được khi màn thấp; padding ngang 32, dọc 24   |
| Icon               | 40, màu `onSurfaceVariant` (Material Icons, outlined)                 |
| Khoảng cách        | icon → title 16 · title → message 8 · → action 24                     |
| Title              | `titleLarge`, `onBackground`, căn giữa                                |
| Message (tùy chọn) | `bodyMedium`, `onSurfaceVariant`, căn giữa                            |
| Action (tùy chọn)  | `GPButton` variant `tonal`; có label thì phải có handler và ngược lại |

### 8.3 Material đã được theme hóa

| Thành phần                 | Spec                                                                                                                                                                          |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **App bar**                | Nền `background`, chữ `onBackground`, tiêu đề **căn trái** `headlineMedium`, elevation 0 cả khi cuộn                                                                          |
| **Navigation bar** (5 tab) | Nền `background`, elevation 0; indicator tab chọn `accentContainer`; icon 24 — chọn `onAccentContainer`, chưa chọn `onSurfaceVariant`; label `labelMedium` `onSurfaceVariant` |
| **Card**                   | Nền `surface`, elevation 0, margin 0, bo `radius-lg` 16                                                                                                                       |
| **Divider**                | `outlineVariant`, dày 1                                                                                                                                                       |
| **Snackbar**               | Nổi (floating), nền `primary`, chữ `bodyMedium` `onPrimary`, action `accent`, bo `radius-md` 10                                                                               |
| **List row** (`ListTile`)  | Title + subtitle + trailing; dùng ở Tài khoản và Cài đặt                                                                                                                      |
| **Radio list**             | Chọn ngôn ngữ trong Cài đặt                                                                                                                                                   |

## 9. Icon

Material Icons. Tab dùng cặp outlined (chưa chọn) / filled (đang chọn):

| Tab       | Chưa chọn                         | Đang chọn                |
| --------- | --------------------------------- | ------------------------ |
| Trang chủ | `home_outlined`                   | `home`                   |
| Tài khoản | `account_balance_wallet_outlined` | `account_balance_wallet` |
| Giao dịch | `swap_vert_outlined`              | `swap_vert`              |
| Ngân sách | `pie_chart_outline`               | `pie_chart`              |
| Cài đặt   | `settings_outlined`               | `settings`               |

Empty/error: `account_balance_wallet_outlined` (chưa có tài khoản), `error_outline` (lỗi).

Category mặc định có `iconKey` nhưng **chưa có bộ icon category** — _cần design_: `food`, `transport`, `shopping`, `bills`, `housing`, `health`,
`entertainment`, `education`, `salary`, `other`.

## 10. Màn hình hiện có

| Tab       | Route           | Trạng thái hiện tại                                                                    |
| --------- | --------------- | -------------------------------------------------------------------------------------- |
| Trang chủ | `/home`         | Placeholder — dashboard đến W6 (tổng thu/chi tháng + số dư từng tài khoản)             |
| Tài khoản | `/accounts`     | List thô: mỗi dòng tên tài khoản, nhãn loại, số dư ban đầu; có loading / empty / error |
| Giao dịch | `/transactions` | Placeholder — list theo ngày là UI của W5 (§12)                                        |
| Ngân sách | `/budgets`      | Placeholder — đến Phase 6                                                              |
| Cài đặt   | `/settings`     | Chọn ngôn ngữ (Tiếng Việt / English, mỗi ngôn ngữ tự gọi tên mình)                     |
| —         | link sai        | "Không tìm thấy trang" + nút "Về trang chủ"                                            |

Điều hướng: mỗi tab giữ stack riêng; chạm lại tab đang mở thì về gốc của tab đó.

## 11. Nội dung & giọng văn

- Ngắn, trực tiếp, không xin lỗi. Lỗi nói chuyện gì xảy ra và làm gì tiếp, không có mã lỗi.
- Không có nút "Thử lại" ở lỗi đọc dữ liệu: dữ liệu local, list tự hồi khi có lần ghi tiếp theo.
- Tên ngôn ngữ không dịch: "Tiếng Việt", "English".

| Khóa                       | Tiếng Việt                                                                                              | English                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Tab                        | Trang chủ · Tài khoản · Giao dịch · Ngân sách · Cài đặt                                                 | Home · Accounts · Transactions · Budgets · Settings                                                                    |
| Loại tài khoản             | Tiền mặt · Ngân hàng · Ví điện tử · Thẻ tín dụng · Khác                                                 | Cash · Bank · E-wallet · Credit card · Other                                                                           |
| Tài khoản trống            | Chưa có tài khoản nào / Tiền mặt, tài khoản ngân hàng, ví điện tử và thẻ của bạn sẽ hiện ở đây.         | No accounts yet / Your cash, bank accounts, e-wallets and cards will show up here.                                     |
| Loại giao dịch             | Chi tiêu · Thu nhập · Chuyển khoản                                                                      | Expense · Income · Transfer                                                                                            |
| Ngày                       | Hôm nay · Hôm qua · Thứ Hai, 5 tháng 10 · Thứ Tư, 31 tháng 12, 2025                                     | Today · Yesterday · Monday, October 5 · Wednesday, December 31, 2025                                                   |
| Category chi               | Ăn uống · Di chuyển · Mua sắm · Hóa đơn & tiện ích · Nhà cửa · Sức khỏe · Giải trí · Học tập · Chi khác | Food & drink · Transport · Shopping · Bills & utilities · Housing · Health · Entertainment · Education · Other expense |
| Category thu               | Lương · Thu khác                                                                                        | Salary · Other income                                                                                                  |
| Lỗi đọc dữ liệu            | Không đọc được dữ liệu trên máy.                                                                        | Could not read local data.                                                                                             |
| Xung đột                   | Mục này đã được thay đổi trên một thiết bị khác.                                                        | This item was changed on another device.                                                                               |
| Không còn                  | Mục này không còn tồn tại.                                                                              | That item no longer exists.                                                                                            |
| Xóa tài khoản có giao dịch | Tài khoản đã có giao dịch nên không thể xóa. Hãy lưu trữ để ẩn tài khoản mà vẫn giữ lịch sử.            | This account has transactions, so it can't be deleted. Archive it instead to hide it and keep its history.             |
| Số tiền ≤ 0                | Số tiền phải lớn hơn 0.                                                                                 | Amount must be greater than zero.                                                                                      |

### Định dạng số tiền

|              | Tiếng Việt                                   | English                                  |
| ------------ | -------------------------------------------- | ---------------------------------------- |
| VND          | `45.000 ₫` (khoảng trắng không ngắt trước ₫) | `₫45,000`                                |
| USD          | `12,34 $`                                    | `$12.34`                                 |
| Chi          | `-45.000 ₫`                                  | `-₫45,000` — dấu luôn đứng trước ký hiệu |
| Thu          | `+45.000 ₫`                                  | `+₫45,000`                               |
| Chuyển khoản | `45.000 ₫` (không dấu, màu trung tính)       | `₫45,000`                                |

## 12. Component — _Đề xuất_ (chưa có trong code, W5 Flex)

| Component             | Spec tối thiểu                                                                                                                                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GPMoneyText`         | Chữ số tabular; 3 kiểu `expense` (`-`, màu `expense`), `income` (`+`, màu `income`), `neutral` (không dấu, `onSurface`); nhận style chữ từ chỗ dùng                                                                       |
| Dòng giao dịch        | Tiêu đề = ghi chú, không có thì nhãn loại; số tiền bên phải bằng `GPMoneyText`. Chưa có tên category/tài khoản (đến W8). Biến thể: có/không ghi chú, ghi chú dài (1 dòng, ellipsis), chuyển khoản (icon mũi tên), pressed |
| Header ngày           | "Hôm nay" / "Hôm qua" / "Thứ Hai, 5 tháng 10"; có thể dính khi cuộn                                                                                                                                                       |
| Footer tải thêm       | Spinner cuối list; tự tải khi cuộn gần cuối, không có nút                                                                                                                                                                 |
| Banner lỗi trong list | Khi đã có dòng mà query lỗi: banner `danger`, các dòng vẫn hiện                                                                                                                                                           |
| Thông báo dòng hỏng   | "N giao dịch không hiển thị được" — nhẹ, không chặn list                                                                                                                                                                  |
| Loading lần đầu       | Spinner hoặc skeleton                                                                                                                                                                                                     |

Không có pull-to-refresh: list tự cập nhật khi dữ liệu đổi.

## 13. Đối chiếu sang code (cho prototype)

| Design            | Flutter                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------- |
| Màu role `x`      | `context.colors.x`                                                                          |
| Style chữ `x`     | `context.text.x`                                                                            |
| Spacing `space-x` | `context.spacing.x`                                                                         |
| Radius `radius-x` | `context.radii.borderX` (vd. `borderMd`)                                                    |
| Shadow `shadow-x` | `context.shadows.x` (rỗng ở dark)                                                           |
| Motion            | `GPDurationTokens.fast / normal / slow`                                                     |
| Nút               | `GPButton(label:, onPressed:, variant:, size:, leading:, trailing:, isLoading:, expanded:)` |
| Trống / lỗi       | `GPEmptyState(icon:, title:, message:, actionLabel:, onAction:)`                            |

Component dùng chung mới vào `lib/core/widgets/` với tiền tố `GP`; màn hình của feature không có tiền tố.

## 14. Lộ trình UI (design trước được)

| Thứ                                                                            | Tuần         |
| ------------------------------------------------------------------------------ | ------------ |
| List giao dịch theo ngày + trạng thái (§12)                                    | W5           |
| Nút thêm giao dịch (accent), form tạo/sửa, xóa + undo (snackbar), chuyển khoản | W6           |
| Dashboard: thu/chi tháng + số dư từng tài khoản                                | W6           |
| Icon + tên category, tên tài khoản trên dòng; "Chưa phân loại"                 | W8           |
| Biểu đồ (fl_chart), ngân sách                                                  | Phase 6      |
| Đăng nhập, trạng thái đồng bộ                                                  | Phase 3–4    |
| Thanh lọc (ngày, tài khoản, category, loại)                                    | W26          |
| Đổi theme light/dark trong app                                                 | chưa có lịch |
