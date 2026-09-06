# App Icon — GH Pockit

Chốt ngày 2026-09-06.

## Concept

Túi (pocket) đựng một tấm thẻ/hoá đơn, đường biểu đồ tăng trưởng vọt lên và
mũi tên phá ra khỏi mép thẻ. Phong cách flat hình học, không glass/3D.
Tên "Pockit" → hình túi; thẻ + đường tăng trưởng → budgeting & analytics.

Nguồn chuẩn: `gh-pockit-icon.svg` (canvas 1024×1024). Mọi bản xuất đều sinh
lại từ file này.

## Bảng màu

| Vai trò | Hex |
|---|---|
| Nền — gradient sáng | `#E3906F` |
| Nền — gradient tối | `#BC5B39` |
| Cam thương hiệu (nền phẳng, theme color) | `#D97757` |
| Túi — kem sáng | `#F2F0E9` |
| Túi — kem tối | `#E4E0D4` |
| Thẻ — manilla sáng | `#F3E7CE` |
| Thẻ — manilla tối | `#DFCBA6` |
| Đường biểu đồ — mực | `#191919` |

Gradient nền: linear từ (80,0) tới (944,1024), cộng một lớp radial glow trắng
20% tâm (270,230) bán kính 820.

## Hình học (toạ độ trên canvas 1024)

- Túi: `M208,488 Q512,584 816,488 L816,700 Q816,792 724,792 L300,792 Q208,792 208,700 Z`
- Thẻ: rect x=312 y=232 w=400 h=328 rx=48
- Đường biểu đồ: polyline `372,470 466,376 552,424 700,222`, stroke 46, round cap/join
- Mũi tên: polyline `628,222 700,222 700,294`, cùng stroke
- Viền miệng túi (hem): stroke trắng 60% width 16, clip trong path túi
- Bóng trong túi: gradient đen 20% → 0 từ y=486 đến y=606, clip trong path túi

## Quy tắc xuất

- **iOS**: flatten RGB, không alpha (App Store Connect từ chối icon có alpha).
- **Android adaptive**: foreground scale 0.78 quanh tâm hình (512, 495.5) để nằm
  gọn trong safe zone 66dp. Đã verify với mask tròn / squircle / vuông.
- **Monochrome (themed icon Android 13+)**: bản line-art chỉ gồm túi + mũi tên
  (bỏ tấm thẻ cho đỡ rối), stroke 44, scale 0.86 quanh (512, 520).
- **PWA maskable**: scale 0.72, có nền — khác `Icon-192/512` là full-bleed.
  *(Chưa dùng: project không support Web — xem CLAUDE.md §1.)*

## Các phương án đã cân nhắc

- Monogram chữ P với ruột chữ tô cam (3 biến thể nền cam / kem / mực) — loại,
  kém đặc trưng hơn.
- Ví + cột biểu đồ trên nền kem — loại, 3 cột dính nhau ở 32px.
- Biến thể có thẻ kraft xoay 9° phía sau — loại, gần như không thấy ở size nhỏ.
- Biến thể có đồng xu ló ra bên trái túi — loại, đọc thành khối mơ hồ.
- Đường biểu đồ kết thúc bằng chấm tròn thay vì mũi tên — loại, yếu hơn ở 40px.

## File trong thư mục này

| File | Vai trò |
|---|---|
| `gh-pockit-icon.svg` | **Nguồn chuẩn.** Sửa ở đây rồi xuất lại toàn bộ |
| `gh-pockit-adaptive-foreground.svg` / `-background.svg` | Layer cho Android adaptive icon |
| `gh-pockit-monochrome.svg` | Line-art cho themed icon Android 13+ |
| `gh-pockit-icon-1024.png` / `-2048.png` | Bản raster để preview / nộp store |
| `play-store-512.png` | Icon 512×512 cho Google Play Console |

## Icon đang nằm ở đâu trong project

| Đường dẫn | Nội dung |
|---|---|
| `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/` | `ic_launcher`, `ic_launcher_round`, adaptive `_foreground` / `_background` / `_monochrome` |
| `android/app/src/main/res/mipmap-anydpi-v26/` | `ic_launcher.xml`, `ic_launcher_round.xml` — khai báo adaptive + monochrome |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | Bộ icon iOS đầy đủ, đã flatten alpha |
| `assets/icon/` | PNG 1024 làm input cho `flutter_launcher_icons` (**không** khai báo trong `pubspec.yaml` — không phải runtime asset, khai báo sẽ làm phình app bundle) |

## Sinh lại icon

Icon đã commit sẵn theo từng platform nên build thường ngày không cần chạy gì.
Chỉ khi sửa file SVG nguồn:

```bash
dart pub add --dev flutter_launcher_icons
dart run flutter_launcher_icons
dart pub remove flutter_launcher_icons
```

Config: `flutter_launcher_icons.yaml` ở gốc repo (chỉ android + ios).
`flutter_launcher_icons` **không** nằm trong `dev_dependencies` thường trực —
đây là tool one-shot, không đáng thành dependency cố định (CLAUDE.md §5).

## App name

Display name: **Pockit** (`android:label`, `CFBundleDisplayName`, `CFBundleName`).
Package / bundle id giữ nguyên `com.nggiahuy.ghpockit`, repo `gh-pockit`.
