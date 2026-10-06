# ROADMAP — Finance App (offline-first Flutter)

**Ngày bắt đầu:** Thứ Hai 07/09/2026
**Ngày CV-ready:** Chủ Nhật 21/03/2027 (W28)
**Ngân sách thời gian:** 1–2h/ngày × 5 ngày trong tuần (~7,5h) + cuối tuần flex (0–4h) ≈ **8–11h/tuần**
**Tổng:** ~28 tuần ≈ 250–300h

---

## Luật chơi

Timeline này chỉ hữu ích nếu bạn tin nó. Vài luật để nó không sụp:

1. **Slot cố định.** Chọn 1 khung giờ (vd 21:00–22:30) và bảo vệ nó. Không "làm khi rảnh".
2. **Miss 1 ngày = bỏ luôn, không dồn.** Dồn task là cách nhanh nhất để bỏ cuộc. Tuần nào chỉ làm được 3/5 ngày thì đẩy phần thừa sang **cuối tuần flex**, không đẩy sang tuần sau.
3. **Miss cả tuần → dùng tuần đệm.** Có 3 tuần đệm sẵn (W16, W17, W22). Đốt đệm trước khi kéo dài deadline.
4. **Mỗi ngày phải có ít nhất 1 commit.** Kể cả commit `docs:` hay `test:`. Green streak trên GitHub chính là bằng chứng discipline khi đi phỏng vấn.
5. **Chủ Nhật 15 phút review:** tick checklist tuần, cập nhật mục _Current status_ trong `CLAUDE.md`, ghi 1 dòng "tuần này học được gì".
6. **Không nhảy phase.** Đặc biệt: **không làm OCR trước sync engine**, không polish animation trước migration.
7. **Scope creep → issue, không → code.** Ý tưởng mới ghi vào GitHub Issues với label `later`, đừng làm ngay.

### Ký hiệu

- 🔴 = critical path, không được skip
- 🟡 = quan trọng nhưng có thể rút gọn nếu kẹt
- 🟢 = nice-to-have, cắt được
- 🎄🧧 = tuần lễ/Tết, tải nhẹ có chủ đích

> **Số ADR không đặt trước.** Số được cấp tuần tự lúc ADR thật sự được viết, theo `docs/adr/` — các dòng dưới chỉ ghi _tiêu đề_ dự kiến. Ngoại lệ duy nhất là **0001** (_Use Drift_), một lỗ trống cố ý đã ghi trong header ADR-0002. Đặt trước số chính là cách W1 lấy mất slot 0003/0004 vốn dành cho outbox và soft-delete.

---

## Bản đồ tổng thể

| Tuần    | Ngày        | Phase   | Chủ đề                                  |
| ------- | ----------- | ------- | --------------------------------------- |
| W1      | 07–13/09    | P0      | Foundation                              |
| W2–W6   | 14/09–18/10 | P1      | Local-only vertical slice               |
| W7–W9   | 19/10–08/11 | P2      | Database quality, benchmark, migration  |
| W10–W11 | 09–22/11    | P3      | Backend + Auth                          |
| W12–W15 | 23/11–20/12 | P4      | **Sync V1** ← milestone quan trọng nhất |
| W16–W17 | 21/12–03/01 | 🎄      | Diagnostics + đệm nghỉ lễ               |
| W18–W21 | 04/01–31/01 | P5      | Sync robustness                         |
| W22     | 01–07/02    | 🧧      | Đệm Tết                                 |
| W23     | 08–14/02    | P7      | Security                                |
| W24–W26 | 15/02–07/03 | P6      | Budget / Analytics / Search             |
| W27–W28 | 08–21/03    | P10     | Polish + release + case study           |
| W29+    | từ 22/03    | mở rộng | OCR, Recurring, NestJS backend          |

---

# PHASE 0 — Foundation

## W1 · 07–13/09/2026 🔴

**Mục tiêu:** repo chạy được, CI xanh, DI + router + theme + error abstraction xong. Chưa có feature nào.

| Ngày           | Task (1–2h)                                                                                                                                                                                                                                                                                                                                                                                                          | Trạng thái                                                                                                                                                                                                                          |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2             | `flutter create`, pin Flutter/Dart SDK vào `.fvmrc`, set package name, tạo repo GitHub, push commit đầu                                                                                                                                                                                                                                                                                                              | ✅ Done                                                                                                                                                                                                                             |
| T3             | `analysis_options.yaml` strict (very_good_analysis hoặc custom), `dart format` hook, tạo `docs/` + copy blueprint vào `docs/blueprint.md`, copy `CLAUDE.md`                                                                                                                                                                                                                                                          | ✅ Done — `very_good_analysis` 10.0.0 + override, `.githooks/pre-commit` (format + analyze)                                                                                                                                         |
| T4             | GitHub Actions: format → analyze → test. Bật branch protection cho `main`                                                                                                                                                                                                                                                                                                                                            | ✅ CI xong — `.github/workflows/ci.yml`; branch protection phải bật tay (checklist ở README §CI)                                                                                                                                    |
| T5             | `get_it` setup: `configureCoreDependencies()`, đăng ký `Clock`, `UuidGenerator`, `Logger` (3 abstraction này sẽ cứu bạn ở phần test sync)                                                                                                                                                                                                                                                                            | ✅ Done — `lib/app/di/injector.dart` + `bootstrap.dart`; v7 monotonic counter (ADR-0002), redaction bắt buộc trong `GPAppLogger.log`; prefix `GP` cho core type (CLAUDE.md §3)                                                      |
| T6             | `go_router` shell + 5 route rỗng (`/home`, `/accounts`, `/transactions`, `/budgets`, `/settings`), bottom nav                                                                                                                                                                                                                                                                                                        | ✅ Done — `StatefulShellRoute.indexedStack` (ADR-0003), `lib/app/router/`; `go_router` **17.2.3** chứ không phải 18.0.1 (18.x cần Dart ≥3.12, ta pin 3.9.2); `/home` nằm ở feature mới `dashboard/`                                 |
| Cuối tuần flex | `sealed class Failure` (Appendix B của blueprint, **trừ** `ValidationFailure(this.message)` — ADR-0004 bác: Failure mang type, message do presentation map sang `l10n.error.*`), theme + design tokens, ADR-0001 draft, **bật branch protection cho `dev`** (nợ T4 — `main` đã bật; `dev` là staging cut build AB-test nên phải require PR + check `format → analyze → test`, chặn force-push, theo `CLAUDE.md` §10) | ✅ 4/4 — `GPFailure` (ADR-0004 shape, no `message`), theme + design tokens (ADR-0005, palette Claude/Anthropic, port từ `ngh09_ui_kit@dev`), ADR-0001 draft xong, branch protection cho `dev` đã bật (14/09 — trễ 1 ngày so với W1) |
| Ngoài kế hoạch | Chốt app name **Pockit** + cài app icon (android adaptive/themed + ios), lưu SVG master & spec vào `docs/design/app-icon/`                                                                                                                                                                                                                                                                                           | ✅ Done                                                                                                                                                                                                                             |
| Ngoài kế hoạch | **Localization EN/VI** — `core/localization/` viết tay (ADR-0004), `flutter_localizations`, language picker trong Settings. Làm sớm vì `Failure` (W1 flex), seed category (W3 T5) và `Money` (W3) đều bake sẵn câu trả lời nếu không chốt trước                                                                                                                                                                      | ✅ Done                                                                                                                                                                                                                             |

### Chốt hạ tầng T2 (06/09/2026)

| Hạng mục                              | Giá trị                                                                        |
| ------------------------------------- | ------------------------------------------------------------------------------ |
| Flutter SDK                           | `3.35.6` (stable, Dart 3.9.2) — pin trong `.fvmrc`, `.fvm/` đã gitignore       |
| Dart SDK constraint                   | `^3.9.2` (`pubspec.yaml`)                                                      |
| App display name                      | **Pockit** (`android:label`, `CFBundleDisplayName`, `CFBundleName`)            |
| App icon                              | android (adaptive + monochrome, 5 density) + ios (15 size, đã flatten alpha)   |
| Nguồn icon                            | `docs/design/app-icon/` — SVG master + spec; input regenerate ở `assets/icon/` |
| Package name (pubspec)                | `ghpockit`                                                                     |
| Android `namespace` / `applicationId` | `com.nggiahuy.ghpockit`                                                        |
| iOS `PRODUCT_BUNDLE_IDENTIFIER`       | `com.nggiahuy.ghpockit`                                                        |
| GitHub repo                           | `nggiahuy09/gh-pockit` (branch làm việc: `dev`)                                |

**Lệnh hằng ngày:** dùng `fvm flutter …` / `fvm dart …` để đảm bảo đúng version đã pin.

**Tên vs id:** display name là **Pockit** (ngắn, không bị launcher cắt, khớp metaphor cái túi trong icon).
Bundle id / repo giữ `com.nggiahuy.ghpockit` / `gh-pockit` — hai thứ này không cần trùng display name,
đổi id về sau tốn công mà không được gì.

**Deliverable:** app chạy, bottom nav hoạt động, CI badge xanh trong README.
**Done khi:** `flutter analyze` = 0 issue, CI xanh, có ≥5 commit.
**Soundbite:** _"Tôi bắt đầu bằng CI và error model, không bằng login screen."_

---

# PHASE 1 — Local-only vertical slice

> Không backend. Mục tiêu cuối phase: app dùng được hoàn chỉnh offline.

## W2 · 14–20/09 🔴 Drift + Account

| Ngày | Task                                                                                                                                                            | Trạng thái                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Cài `drift` + `drift_flutter`, tạo `AppDatabase`, chạy được query đầu tiên. **Lưu ý:** không thêm `sqlite3_flutter_libs` theo tutorial cũ                       | ✅ Done — `GPAppDatabase` + `settings`, `schemaVersion` 1, baseline dump `drift_schema_v1.json`. `drift` phải là 2.31.0 / `drift_flutter` 0.2.8 chứ không phải 2.34.x / 0.3.x (cần Dart ≥3.10, ta pin 3.9.2) — CLAUDE.md §5 đã ghi                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| T3   | Drift table `accounts` đủ cột sync-ready (`id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at`) | ✅ Done — `features/accounts/data/tables/accounts_table.dart`, `schemaVersion` 2 + migration v1→v2 thật (không dùng ngoại lệ wipe của golden rule 7) + 4 migration test trên fixture v1, 8 test cho bảng. ADR-0001 chốt `owner_id` = sentinel `localOwnerId`, NOT NULL                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| T4   | `AccountDao`: insert / update / `watchAccounts()` / `archive()`                                                                                                 | ✅ Done — `features/accounts/data/daos/`, 12 test. Viết theo `docs/patterns/local-storage-with-drift.md` §6.2: DAO chỉ có SQL + row, **không** clock/uuid/policy — `now` là tham số bắt buộc, write nhận companion do mapper dựng. `watchAccounts(ownerId)` **bắt buộc scope theo owner** (index `(owner_id, is_archived)` mới seek được, và W10 mới không lộ row chéo tài khoản) và **ẩn archived mặc định** → có thêm `unarchive()`. `updateAccount` guard `baseVersion`, trả số row (0 = conflict, §7); `version` là của server, client không bao giờ bump                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| T5   | Domain: `Account` entity, `AccountType` enum, `AccountRepository` interface                                                                                     | ✅ Done — `features/accounts/domain/`, 47 test (suite: 213). Quyết định lớn nhất là **ADR-0006**: repository trả `GPResult<T>` (`GPOk`/`GPErr`, tự viết trong `core/error/`, không thêm `dartz`/`fpdart`) chứ không throw — vì write hỏng là **im lặng** (stream không re-emit), nên quên `try/catch` = user bấm Save mà không thấy gì. Ranh giới: outcome user tạo ra → return type; bug → throw `Error`. **`Money` kéo sớm từ W3 T2** vào `core/money/`, không prefix (§3 liệt `Money` ở cột unprefixed) — `MoneyFormatter` + `CurrencyCode` catalog vẫn ở W3 T4. `GPValidationFailure` giờ mang `GPValidationCode`, bỏ string `error.validation` chung → user đọc đúng field sai thay vì "kiểm tra lại thông tin". Entity **không** mang `ownerId`/`deletedAt` (repo + DAO lo), **có** `version` vì §7 làm conflict thành outcome user nhìn thấy. Read là `Stream`, write là `Future<GPResult>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| T6   | `AccountRepositoryImpl` + `AccountMapper` (row ↔ entity). Test mapper                                                                                           | ✅ Done — `data/mapper/` + `data/repositories/`, 62 test mới (suite: 275). **Mapper**: mọi lỗi parse row đều thành `GPDatabaseFailure`, kể cả khi row vi phạm domain rule — user đang **đọc danh sách** chứ không gõ, nói "Tên tài khoản không được để trống" là nói về một ô input không có trên màn hình. Thêm `Money.fromStorage` (trả `null`) để mapper **không phải catch `Error`**. **Repo**: `updateAccount` phân biệt 3 tình huống của `written == 0` bằng `findById` **bên trong transaction** → thêm `GPNotFoundFailure` (conflict mời reload, not-found thì đóng màn hình — hai câu khác nhau). `watchAccounts` gặp 1 row hỏng thì **fail cả list**, không skip — số dư thiếu một tài khoản mà không báo tệ hơn một error state; error channel luôn mang `GPFailure`. DAO thêm `watchAccount` + `softDelete`. DI: `configureAccountsDependencies`, đúng **một** `AccountDao`. **Sửa lại API T5**: `AccountEntity.update()` bỏ tham số `updatedAt` (mọi caller truyền một giá trị rồi repo vứt đi) → thêm `stampedAt()`; nhờ vậy repo hết nhánh validate chết. **Soi lại sau khi viết xong**: mapper trả `AccountMapping` (sealed) kèm `AccountMapperReason` — user vẫn chỉ thấy **một** câu, nhưng log phân biệt được 3 bug để P7 khỏi gộp thành 1 cụm; thêm `ThrowingAccountDao` vì SQL thật không lỗi theo yêu cầu được — giờ đủ cả 3 `catch` site + test **`Error` không bị nuốt**. Nợ đã ghi trong ADR-0006: row hỏng chưa có đường chữa (quarantine) |
| Flex | ADR-0001 _Use Drift as local source of truth_. Repository test với in-memory DB                                                                                 | ✅ ADR-0001 **Accepted** (T4) — `create → watchAccounts emit` pass. Repository test thật **xong ở T6**: 25 test trên in-memory Drift, không mock DAO — mock chỉ khẳng định repo gọi đúng hàm, cái đáng khẳng định là thứ user thấy (conflict bị từ chối, row xoá biến khỏi stream), và cái đó cần SQL thật                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Flex | Nợ từ W1: bảng `settings` local-only + `GPDriftLocaleStore` thay `GPInMemoryLocaleStore` (ADR-0004). Chưa làm = ngôn ngữ user chọn không sống qua restart       | ✅ Done (T4) — `core/localization/drift_locale_store.dart`, 9 test, đổi đúng 1 dòng trong `injector.dart` như ADR-0004 hứa. Code lạ đọc ra `null` (= theo máy) chứ không fallback `en`. `bootstrap()` giờ mở DB trước frame đầu → lỗi storage **không được thoát ra**: read hỏng = coi như chưa chọn, write hỏng = log `error`, cả hai không giết app (ADR-0004 amend)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

**Done khi:** test `create → watchAccounts emit` pass.

## W3 · 21–27/09 🔴 Money + Category

| Ngày | Task                                                                                                                                                                                                        | Trạng thái                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | `Money` value object: `minorUnits` + `currencyCode`, `add/subtract/compare`                                                                                                                                 | ✅ Done — kéo sớm vào **W2 T5**, `core/money/money.dart`. `minorUnits` + `currencyCode`, `+` / `-` / unary `-` / `abs()`, `Comparable` + 4 toán tử so sánh, `==` theo value (0 VND ≠ 0 USD). Ngoài phạm vi T2: `Money.zero`, `Money.fromStorage` (trả `null` thay vì throw, cho row đọc từ SQLite), validate shape `^[A-Z]{3}$` (membership ISO-4217 là việc của catalog ở T4), `MoneyCurrencyMismatchError` là `Error` chứ không phải `Exception` — ADR-0006                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| T3   | Test `Money` kỹ: cộng khác currency phải throw, format VND vs USD, số âm, số lớn                                                                                                                            | ✅ Done — 24 test (19 từ W2 T5 + group `magnitude`). Phần **số lớn** chốt theo **option A: test + document, không guard**. Lý do không guard: trần 64-bit là 9.2 quintillion VND (exponent 0) — quá tổng lượng tiền mặt VND đang tồn tại; thêm một nhánh check vào mọi phép `+` để giữ một bound không ai chạm tới, mà vẫn **không** phủ được đường thật sự tràn được là `SUM()` của W4 chạy trong SQLite (INTEGER cũng 64-bit, tràn độc lập) → an toàn giả. 4 hành vi được pin lại thay vì để tự khám phá: giữ đúng ở 2^53+1 (số nguyên đầu tiên `double` không biểu diễn nổi — golden rule 2 gói trong 1 assert), `fromStorage` round-trip nguyên dải INTEGER, `+` quá trần **wrap âm im lặng** (test này là nơi phải tranh luận nếu sau muốn đổi sang throw), và `-minInt == minInt` nên `abs()` của floor vẫn âm. Dartdoc `Money` có section "The range is 64-bit, and it wraps". "Format VND vs USD" thuộc T4, không phải T3                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| T4   | `MoneyFormatter` dùng `intl` (promote từ transitive lên direct dep, pin cứng); format **và parse** theo locale đang bật — `1.234,56` vs `1,234.56`; `CurrencyCode` catalog (VND exponent 0, USD exponent 2) | ✅ Done — `core/money/currency_code.dart` + `core/money/money_formatter.dart`, 26 test (suite: 306). Đặt tên lệch ROADMAP một chỗ: **`GPMoneyFormatter`** chứ không `MoneyFormatter` — §3 nói core/ thì prefix, `Money`/`CurrencyCode` là ngoại lệ vì chúng là domain value; formatter thì cần locale + thư viện format, `domain/` không đụng tới, nên nó là infrastructure. Chính bảng §3 đã chia y vậy: `GPMoneyText` có prefix, `Money` không. **Quyết định kỹ thuật chính: không `double` nào chạm vào số tiền trên đường ra màn hình.** `NumberFormat.currency().format()` nhận `num`, dùng đúng ý nó nghĩa là tính `minorUnits / 100` — ở $12.34 không ai thấy, ở 2^53 minor units thì số in ra không còn là số trong row. Nên tách `~/` và `remainder`, chỉ đưa **phần nguyên (int chính xác)** cho `intl`, phần thập phân nối tay bằng `DECIMAL_SEP`. Ký hiệu đặt trước hay sau là việc của **locale** chứ không phải của currency (`₫1,500,000` vs `1.500.000 ₫`), và vị trí đó **hỏi `intl`** bằng cách format số 0 rồi cắt hai bên, không hardcode. Dấu trừ luôn nằm ngoài ký hiệu (`-$12.34`), và `-5` USD vẫn ra `-$0.05` dù phần nguyên là 0. Currency lạ (row từ bản mới hơn — `Money.fromStorage` chỉ check shape) **không throw**: in exponent 0 + mã gốc, vì format chạy trong `build()`. `parse` trả `Money?`, strip symbol/khoảng trắng/group sep, **strip group chứ không validate** (`1.500.00` là `1.500.000` gõ dở), từ chối khi thừa chữ số thập phân so với exponent (`1.234,56` là USD hợp lệ, VND thì vô nghĩa) hoặc tràn `int`. Mã currency sai thì **throw ngay đầu hàm** — ADR-0006, và check sớm để bug không lúc ẩn lúc hiện theo nội dung field. `intl 0.20.2` pin cứng: `flutter_localizations` của SDK 3.35.6 phụ thuộc đúng version đó, số khác là fail resolve                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| T5   | Drift table `categories` + `CategoryDao` + seed default categories (is_system = true). Tên lưu `name_key` (`category.food`) chứ không lưu text đã dịch, cột `name` do user sửa thì thắng — ADR-0004         | ✅ Done — schema **v3**, `features/categories/` (table + DAO + seeder) + `core/localization/` strings, 55 test (suite: 361). \*\*Quyết định lớn nhất — id của seeded category là `v5` tất định từ `ownerId\|nameKey`, không phải `v7`.** Hai máy của cùng một user seed offline độc lập: id random thì lần sync đầu tiên user thấy 22 category, và lúc đó mỗi bản copy có thể đã dính transaction nên không merge tự động được. Derive id thì hai máy ra cùng primary key, pull ở W13 ghi đè thay vì nhân đôi. Đây là **ngoại lệ có ghi chép của golden rule 4** ("UUID v4/v7") — tinh thần "id sinh ở client, không chờ server" không đổi, `v5`tính local từ dữ liệu client đã có; ghi rõ trong dartdoc`GPUuidGenerator.v5`. Kéo theo: seed **idempotent by construction** (`INSERT OR IGNORE`trên cùng id), chạy mỗi lần mở app, **không resurrect category user đã xóa** (row tombstone vẫn giữ id — với`v7`thì nó sẽ mọc lại), và`insertOrIgnore`chứ không`insertOrReplace`nên rename của user không bị seed ghi đè. **Hai cột tên:**`name_key` (`category.food`, cho row seed) + `name`(user gõ, **thắng** khi có) +`CHECK (name_key IS NOT NULL OR name IS NOT NULL)`— cross-column nên là`customConstraints`chứ không`.check()`. Giữ cả hai thay vì một cột: rename mà đè lên key thì mất luôn dấu vết row đó vốn là default nào. `UNIQUE(owner_id, name_key)`— không cần partial index vì SQLite coi NULL là distinct, nên user tạo bao nhiêu category riêng cũng được (có test). **Seed KHÔNG nằm trong migration**:`onUpgrade`không có owner lẫn clock, và migration ghi row thì sẽ dựng lại đúng những category user đã xóa ở version trước → chạy ở`bootstrap()`. Chuỗi ADR-0004 khép kín: thêm 1 `DefaultCategory`→ switch trong`DefaultCategoryName`thiếu case → không compile → phải thêm getter → cả`GPLocaleEn`và`GPLocaleVi`đều phải dịch. 11 category, EN + VI.`CategoryType`kéo sớm từ T6 (seeder cần gọi tên type), y như`Money`từng kéo vào W2 T5. Test migration thêm cả **v1→v3\*\* — nhánh "máy bỏ lỡ 1 release" mà`if (from < N)` viết ra để phục vụ, trước giờ chưa ai test                                                                                                                                                                                                                                                                        |
| T6   | Domain `Category` + repository + mapper + test                                                                                                                                                              | ✅ Done — `CategoryEntity` + `CategoryRepository` + `CategoryMapper` + `CategoryRepositoryImpl`, 44 test (suite: 405). Khung giống hệt slice `accounts` (đọc là Stream, ghi là `GPResult`, `ownerId` không lên tới domain, row hỏng thì **fail cả list** — quyết lại chứ không chép: cỡ vài chục row là ca accounts, không phải ca 50k của W4 T6). **Phần riêng của category là hai cột tên, và nó được ép bằng _chữ ký hàm_ chứ không bằng check.** `CategoryEntity.update` **không có** tham số `nameKey` lẫn `isSystem`, và `CategoryMapper.toPatch` **không** phát hai cột đó — nên "rename giữ nguyên key" đúng ngay cả khi ai đó tự dựng patch bằng tay; provenance không edit đi đâu được. `create` chuẩn hóa `name`: trim → rỗng thành `null` → mới check độ dài, nên `''` và "chưa có tên" là **một** state chứ không phải hai state nhìn giống nhau mà so sánh khác nhau. Cả hai tên cùng null → `categoryNameEmpty` (đúng invariant của CHECK, nhưng nói ở chỗ user đọc được). Thêm `clearName: true` vì `name: null` đã mang nghĩa "đừng đụng" — không có nó thì thao tác "trả tên về mặc định" của system category là **không diễn đạt được**; `toPatch` ghi `Value(null)` thật nên cột về NULL chứ không phải bị bỏ qua. Entity **cố tình không tự resolve được tên**: cần `GPLocaleBase` thì domain phải import thứ nó không được import (§3), và tên là field thì đổi ngôn ngữ sẽ làm **mọi** category compare khác nhau → rebuild cả list. Resolver nằm ở presentation, thêm `CategoryEntity.displayNameIn(l10n)`. 2 `GPValidationCode` mới → 2 getter EN + VI + 2 case trong `failure_message`, và thêm vào `allFailures` để test "không code nào dùng ké message của code khác" phủ luôn. `createCategory` mint `v7` chứ không `v5`: category user tự tạo không có gì để derive, mà mượn scheme của seeder thì hai category trùng tên sẽ đụng id. `CategoryRepository` bind vào DI                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Flex | ADR _Store money as integer minor units_. UI list accounts thô (chưa cần đẹp)                                                                                                                               | ✅ Done — **ADR-0007** (`docs/adr/0007-store-money-as-integer-minor-units.md`; số tuần tự trùng luôn slot Appendix E đặt sẵn). Viết sau khi code đã chạy nên mọi câu đều đối chiếu được với `core/money/`; phần đáng giá nhất là **những gì nó ràng buộc các tuần sau**: W7 chỉ dùng `sum()` — Drift `sum()` trên cột int là `Expression<int>`, còn `total()`/`avg()` là `Expression<double>`; SQLite `SUM()` tràn thì báo `integer overflow`, `TOTAL()` thì âm thầm trả float — W10 cột tiền phải là `bigint` (`integer` 32-bit trần 2,1 tỷ ₫, chưa bằng một căn hộ), DTO P4 đọc amount là `int`, số lẻ là payload hỏng chứ không làm tròn. Grep lại: mọi `double` còn trong `lib/` là kích thước layout / typography → **"Done khi" của W3 đạt**. **UI list accounts thô**: `AccountsPage` là `StreamBuilder` trên `watchAccounts()`, subscribe **một lần trong `State`** chứ không trong `build()` (đổi ngôn ngữ không re-subscribe). **Không BLoC**: `flutter_bloc` chưa là dependency và người dùng đầu tiên là W5 — kéo sớm để bọc đúng một stream là lý do quá nhỏ. Repository vào qua **constructor**, route builder trong `app_router.dart` mới gọi `getIt` → page pump được mà không cần DI. Mỗi dòng: tên + nhãn loại (`AccountTypeLabel`, switch exhaustive y như `DefaultCategoryName`) + **số dư ban đầu** qua `GPMoneyFormatter` (W6 T6 thay bằng balance thật). Đủ loading / empty / error; error không có retry (query y hệt thì lỗi y hệt, stream còn sống nên tự hồi); lỗi không phải `GPFailure` thì **rethrow** — bug không đội lốt câu thông báo (ADR-0006). 10 test mới (suite: 415), widget test chạy trên **repository thật + in-memory Drift** với `closeStreamsSynchronously: true` (không có thì timer của drift làm fail widget test), gồm "tạo account sau khi trang đã mở → tự hiện, không refresh". `localizedHarness` thêm `GPAppTheme.light()`, router test đăng ký `FakeAccountRepository` vào global `getIt`. Chưa chạy được trên simulator (`pod install` lỗi CDN) — layout soát bằng test renderer cỡ iPhone. **Phát hiện, tách task riêng**: stream của cả hai repository chỉ map lỗi mapper sang `GPFailure`, exception từ chính query Drift đi thẳng ra ngoài — trái hợp đồng interface; font Inter bundle là subset Latin 231 codepoint, **thiếu ă/đ/ơ/ư và ₫** → ✅ **ADR-0008**: subset Latin + tiếng Việt, có test chặn tái phát |

**Done khi:** không còn `double` nào liên quan tới tiền trong codebase.

## W4 · 28/09–04/10 🔴 Transaction core

| Ngày | Task                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Trạng thái                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Domain `TransactionEntity` + `TransactionType` (expense/income/transfer) + rule nội bộ entity (ADR-0009): amount > 0; transfer bắt buộc `destination_account_id` khác `account_id`; transfer không mang category, non-transfer không mang destination (chuẩn hoá, không từ chối); note có giới hạn độ dài. `GPValidationCode` mới + EN/VI. **Kèm nợ W1–W3** — bảng _W4 T2_ dưới                                                                                                                              | ✅ Done (27/09, sớm một ngày) — `features/transactions/domain/entities/`: `TransactionType` (storage value viết tay; `'transfer'` là literal mà CHECK của T3 dùng) + `TransactionEntity` (create / update / stampedAt theo khuôn `AccountEntity`). Rule nội bộ: amount > 0; transfer bắt buộc destination khác account; **category của transfer và destination của non-transfer bị bỏ chứ không bị từ chối** — đó là thứ form để lại khi đổi type, nên `update(type: …)` đổi type trong một lần gọi; note trim → rỗng thành null → tối đa 500 code unit. Entity **không** kiểm currency theo account hay category type — việc của repository và use case (ADR-0010), có test ghim ranh giới đó. 4 `GPValidationCode` mới + EN/VI + `failure_message` + `allFailures`; test "copy không chứa số giới hạn" giờ đọc giới hạn từ entity thay vì gõ tay `100`. `syncStatus` chưa lên entity (ADR-0009). 34 test mới, suite 463 pass; format + analyze sạch                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| T3   | Drift table `transactions` + CHECK / FK / 4 index + migration v3→v4 + dump + test (v3→v4, v2→v4, v1→v4) — spec ở _W4 T3_ dưới (ADR-0009)                                                                                                                                                                                                                                                                                                                                                                     | ✅ Done (27/09) — `features/transactions/data/tables/transactions_table.dart`, schema **v4**. `CREATE TABLE` đúng spec: CHECK trên `amount_minor` / `currency_code` + 3 CHECK liên cột, 3 FK, không default, không CHECK bộ giá trị. Ba điểm spec chưa nói, chốt trong lúc làm và ghi vào ADR-0009: **FK kiểm ngay, không `DEFERRABLE`** — deferral chỉ giúp trong một page pull, lại dời lỗi sang COMMIT nơi không biết row nào, mà đổi sau là rebuild; **index tăng dần**, SQLite quét ngược cho `DESC`; **index không partial** (`WHERE deleted_at IS NULL`) — query quên điều kiện là full scan im lặng, còn đổi index chỉ là drop + create nên để W8 đo. `@ReferenceName` cho hai FK cùng trỏ `accounts` (không có thì drift cảnh báo ở mỗi lần build). Migration `if (from < 4)` đứng sau v2/v3 vì FK; dump v4 + generate. 21 test bảng (mỗi CHECK, mỗi FK, parent đã soft-delete vẫn qua FK, không default, bộ giá trị tự do, `EXPLAIN QUERY PLAN` cho 4 index không có `TEMP B-TREE`) + 5 test migration (shape v3→v4, data v3 còn nguyên, 4 index trên đường upgrade, FK sống với row có từ trước v4, v2→v4 và v1→v4); suite 489 pass. **Chạy thật:** cài đè lên DB v3 trên emulator `Pixel_10` → `user_version` 4, 11 category và lựa chọn ngôn ngữ còn nguyên, app không lỗi. **Phát hiện cho T5:** lọc account cả hai phía transfer (`OR`) → `MULTI-INDEX OR` + `TEMP B-TREE FOR ORDER BY`, tức sort cả lịch sử account |
| T4   | `TransactionQuery`: account khớp cả hai phía transfer, category, type, khoảng `[from, to)` bằng instant, `limit` (không offset). Interface `TransactionRepository`: `watchTransactions` trả snapshot = row đọc được + số row query trả về + số row không đọc được (ADR-0011)                                                                                                                                                                                                                                 | ✅ Done (27/09) — `domain/entities/transaction_query.dart`, `transaction_list_snapshot.dart`, `domain/repositories/transaction_repository.dart`. **`TransactionQuery`**: factory chuẩn hoá (set được copy thành unmodifiable, set rỗng → `null` = không lọc, instant → UTC), throw `ArgumentError` khi `limit <= 0` hoặc `from > to` (bug của người gọi, ADR-0006), `withLimit` cho "load more"; equality so set không theo thứ tự bằng `Object.hashAllUnordered` — không thêm `package:collection`. Lọc "đủ mọi type" **không** bằng "không lọc": hôm nay trả cùng row, ngày có type thứ tư thì khác. **`TransactionListSnapshot`**: list unmodifiable + `unreadableCount` + `hasMore` (repository tính trên số row thô); `rowCount` suy ra. **`TransactionRepository`**: 5 method, doc liệt kê failure từng method, kể cả `category_id` không tồn tại → FK → `GPDatabaseFailure` (category còn sống và đúng loại là việc của use case, ADR-0010). Interface chưa có impl nên chưa test — T6 test qua impl thật. ADR-0011 ghi tên snapshot và các chốt của query. 20 test mới, suite 509 pass                                                                                                                                                                                                                                                                                                                                      |
| T5   | `TransactionDao`: insert / update (guard `baseVersion`) / soft-delete / `findById` (kể cả tombstone) / `watchTransaction(id)` / `watchTransactions(...)` nhận tham số primitive (DAO không import domain), order `occurred_at DESC, id DESC`; mọi write set `sync_status = 'pending'` — lọc account hai phía bằng `OR` phải sort cả lịch sử account (plan đo ở T3); cân nhắc `UNION ALL` hai nhánh, mỗi nhánh đọc theo index: CHECK `destination_account_id <> account_id` bảo đảm hai nhánh không trùng row | ✅ Done (27/09) — `data/daos/transaction_dao.dart` (+ `.g.dart`), `@DriftAccessor(tables: [TransactionsTable, AccountsTable])`. Đúng spec, thêm một chỗ: `liveAccountCurrency` nhận cả `ownerId` — ADR-0010 đòi account phải là của owner, FK chỉ chứng minh row tồn tại. `pendingSyncStatus` là hằng duy nhất của `'pending'`; insert / update / softDelete đều đóng dấu đè lên companion. `selectTransactions` (`@visibleForTesting`) là đúng statement mà `watchTransactions` watch, nên test plan chạy trên SQL thật (`constructQuery()`). **Đo lại plan lọc account hai phía trên SQL thật (có owner):** SQLite đi theo index owner rồi lọc — không sort như lần đo ở T3 (không có owner), nhưng account ít giao dịch phải đọc lùi xa. Lựa chọn theo chi phí có thể khác giữa các bản SQLite, nên test chấp nhận cả hai plan đã biết và cấm `SCAN`; ADR-0009 và dartdoc đã sửa theo. 26 test mới, suite 535 pass                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| T6   | `TransactionRepositoryImpl` + mapper + repository test. Account chưa xoá + currency khớp account kiểm **trong** `transaction {}` (ADR-0010); row hỏng vào snapshot, không fail cả list (ADR-0011) — quyết lại chính sách W2 T6 chứ không chép                                                                                                                                                                                                                                                                | ✅ Done (30/09) — `data/mapper/transaction_mapper.dart`, `data/repositories/transaction_repository_impl.dart`, `configureTransactionsDependencies` (gọi trong `bootstrap()`). **Mapper**: sealed `TransactionMapping` + `TransactionMapperReason` (`unknownType` / `malformedCurrencyCode` / `brokenDomainRule`); `toPatch` ghi `Value(null)` cho reference trống, nên đổi transfer ↔ expense xoá được giá trị cũ mà CHECK không chặn. **Repository**: rule của entity chạy trước, chưa đụng DB; hai rule account (còn sống + là của owner, cùng currency) chạy **trong** `transaction {}` và **trước** guard version; update ghi 0 row → `findById` phân biệt conflict / not-found; delete không kiểm account (xoá được cả khi account đã xoá). List: row hỏng vào `unreadableCount`, `hasMore` đếm row thô, log mỗi row hỏng **một lần mỗi stream** (có test: 3 emission, 1 dòng log). Hai code mới `transactionCurrencyMismatch`, `transactionTransferCurrenciesDiffer` + EN/VI. ADR-0010 / ADR-0011 ghi các chốt. 46 test mới (mapper 11, repository 33, DI 2), suite 581 pass                                                                                                                                                                                                                                                                                                                                                  |
| Flex | Use case có việc thật (ADR-0010): `CreateTransactionUseCase` / `UpdateTransactionUseCase` (category type khớp transaction type), `DeleteAccountUseCase` (chặn khi còn transaction, gợi ý archive). **Không** viết `DeleteTransactionUseCase` — BLoC gọi thẳng repository                                                                                                                                                                                                                                     | ✅ Done (30/09) — `transactions/domain/usecases/`: `CreateTransactionUseCase`, `UpdateTransactionUseCase` (dùng chung `refusalFromCategory`); `accounts/domain/usecases/`: `DeleteAccountUseCase`; mỗi cái bind DI ở module của feature sở hữu. **Rule category** (ADR-0010 rule 3): category phải còn sống và đúng loại, không thì `GPNotFoundFailure` / code mới `transactionCategoryTypeMismatch` — category không tồn tại giờ ra not-found thay vì `GPDatabaseFailure` của FK; category thừa của transfer không bị xét vì entity bỏ nó. **Update chỉ xét filing mà edit tạo ra** (đổi category, hoặc đổi type mà giữ category): transaction dưới category đã xoá — trạng thái bình thường, vì ADR-0010 cho xoá — vẫn sửa được; edit lệch version đi thẳng xuống repository để ra conflict. **Xoá account**: `TransactionRepository.hasLiveTransactions` (cả hai phía transfer) → code mới `accountHasTransactions`, message gợi ý lưu trữ. **Đo plan**: viết bằng query builder thì SQLite đi index owner và đọc hết lịch sử của owner khi account rỗng — đúng ca được phép xoá; `+owner_id` (raw SQL, câu duy nhất trong DAO) đưa về `MULTI-INDEX OR` trên hai index account, test ghim plan. 37 test mới (DAO 7, repository 3, use case 8 + 11 + 6, DI 2), suite 618 pass                                                                                                                                                     |

### W4 — quyết định chốt trước tuần (27/09)

> Mười sáu câu hỏi từ lần soát W4, chốt theo đề xuất. Nơi ghi chính thức là ADR-0009 / 0010 / 0011 và phần bổ sung ở ADR-0002, ADR-0006; bảng này để
> tra nhanh.

| Q   | Quyết định                                                                                                                                                 | Ghi ở                              |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| Q1  | `amount_minor` luôn dương, `type` quyết định chiều, `CHECK (amount_minor > 0)` — transfer là 1 row chạm 2 account nên không có dấu nào đúng cho cả hai bên | ADR-0009                           |
| Q2  | Có FK (`account_id`, `destination_account_id` → `accounts`; `category_id` → `categories`), không `ON DELETE`; W14 ghi cha trước con                        | ADR-0009                           |
| Q3  | Index tạo cùng query đầu tiên đọc nó: 4 index của list ở W4 T3; `(sync_status)`, `(updated_at)` đợi P4; W7 T2 thành audit `EXPLAIN QUERY PLAN`             | ADR-0009, CLAUDE.md §6             |
| Q4  | `sync_status` TEXT không CHECK, hai giá trị `pending` / `synced`; W4 chỉ ghi `pending`; chưa đưa lên entity                                                | ADR-0009                           |
| Q5  | Thứ tự tuần theo CLAUDE.md §13: entity (T2) → table (T3) → query + interface (T4) → DAO (T5) → repository impl (T6)                                        | Bảng W4                            |
| Q6  | Row hỏng không fail cả list: stream trả snapshot = row đọc được + số row không đọc được, UI báo nhẹ                                                        | ADR-0011, ADR-0006                 |
| Q7  | Phân trang = một stream, tăng `limit`; không offset; keyset để W26                                                                                         | ADR-0011                           |
| Q8  | Account chưa xoá + currency khớp account → repository, trong `transaction {}`; category type khớp → use case                                               | ADR-0010                           |
| Q9  | `TransactionQuery` nhận instant `[from, to)`; presentation đổi ngày theo giờ máy sang instant                                                              | ADR-0009, ADR-0011                 |
| Q10 | Xoá account còn transaction → chặn, gợi ý archive                                                                                                          | ADR-0010, dartdoc `deleteAccount`  |
| Q11 | `DeleteAccountUseCase` kiểm Q10 qua `TransactionRepository`                                                                                                | ADR-0010                           |
| Q12 | Xoá category còn transaction → cho xoá; transaction giữ `category_id`, đọc thành "Chưa phân loại"                                                          | ADR-0010, dartdoc `deleteCategory` |
| Q13 | Use case chỉ tồn tại khi có rule: Create/Update transaction + DeleteAccount; không có `DeleteTransactionUseCase`                                           | ADR-0010, CLAUDE.md §3             |
| Q14 | Account hiển thị theo thứ tự tạo; sort theo tên hay thứ tự tự chọn là feature sau                                                                          | dartdoc `AccountDao.watchAccounts` |
| Q15 | CI có bước build (debug APK, chưa flavor); flavor làm ở W10 cùng env Supabase                                                                              | `ci.yml`, README, CLAUDE.md §9–§10 |
| Q16 | Id `v5` của category seed ghi vào ADR-0002 (bổ sung) + golden rule 4                                                                                       | ADR-0002, CLAUDE.md §2             |

**Phát sinh khi chốt, còn mở:** currency của account (`AccountEntity.update(initialBalance:)`) và type của category (`CategoryEntity.update(type:)`) đều
sửa được. Sửa một trong hai là làm hỏng mọi transaction đã nằm dưới nó mà không còn write nào để từ chối — chốt trước khi W6 cho sửa account/category
(ADR-0010 _Still open_).

### W4 T2 — nợ từ W1–W3

| Nợ                                                                                     | Nguồn                                                                                                                                                                                           | Trả ở                                | Trạng thái                                                                                                                                                         |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Xoá account/category còn transaction: cascade, block hay orphan                        | `AccountRepository.deleteAccount` (W2 T5) và `CategoryRepository.deleteCategory` (W3 T6) ghi rõ "W4's decision"                                                                                 | Chốt ở T2; code ở flex               | ✅ Chốt 27/09 (Q10–Q12) — ADR-0010, hai dartdoc đã sửa; code xong ở flex 30/09 (`DeleteAccountUseCase`)                                                            |
| Sort account để hiển thị                                                               | `AccountDao.watchAccounts`: "sorting for display is W4's problem"; `AccountsPage` vẫn theo thứ tự tạo                                                                                           | Chốt ở T2                            | ✅ Chốt 27/09 (Q14) — giữ thứ tự tạo, sửa dartdoc `AccountDao` + `AccountRepository`                                                                               |
| `GPMoneyText` + role typography cho tiền (`tnum` — subset ADR-0008 đã giữ feature này) | ADR-0005 _Owed_; `typography.dart` hẹn "arrives in W3"                                                                                                                                          | W5 T4 — list tiền đầu tiên           | Hẹn W5 T4                                                                                                                                                          |
| ADR cho id `v5` của category seed (ngoại lệ golden rule 4)                             | W3 T5 chỉ ghi ở dartdoc + ROADMAP; ADR-0002 chỉ có v7 (entity) + v4 (idempotency key), CLAUDE.md rule 4 vẫn ghi "v4/v7"                                                                         | T2                                   | ✅ 27/09 (Q16) — ADR-0002 bổ sung + golden rule 4                                                                                                                  |
| CI chưa có bước `build`                                                                | `ci.yml` hoãn tới khi có flavor, mà flavor chưa có lịch; lệnh `flutter run --flavor dev --dart-define-from-file=env/dev.json` ở CLAUDE.md §9 hiện không chạy (không có flavor, không có `env/`) | Chốt ở T2                            | ✅ 27/09 (Q15) — bước build + JDK 17, giữ tên job vì đó là required check; `flutter build apk --debug` chạy local 49s; lần chạy CI đầu tiên là ở PR W4             |
| Chưa có ghi nhận app chạy thật từ khi có Drift                                         | W3 flex: iOS `pod install` lỗi CDN; không ghi lần chạy Android nào                                                                                                                              | T2 — máy có sẵn emulator `Pixel_10`  | ✅ 27/09 — debug APK trên emulator `Pixel_10`: Home, Accounts (empty state đọc từ Drift), Settings; tiếng Việt đủ dấu; ngôn ngữ còn nguyên sau force-stop + mở lại |
| Comment trỏ sai tuần                                                                   | Cụm P4: "pull cursor W12 T2" → W14 T2, applier/pull "W13" → W14, "audited at W12 T3" → W15 T3; `TransactionDao (W5 T4)` → W4 T5; `money.dart` "W4's aggregates" → W6 T6/W7                      | T2, một lượt grep                    | ✅ 27/09 — 19 file (11 lib, 8 test). Để nguyên `money.dart` "revisiting at W13": câu đó nói về DTO đầu tiên đọc currency từ wire, có thể đúng là push              |
| Bảng W3 không render trên GitHub                                                       | Dấu `\|` trong `` `ownerId\|nameKey` `` (row T5) tách cell thành 4 cột, lệch với header 3 cột                                                                                                   | T2                                   | ✅ 27/09 — escape thành `\|`, căn lại bảng                                                                                                                         |
| W9 lỗi thời                                                                            | Dump v1 xong từ W2; v1→v2/v2→v3 và `version`/`deleted_at` đã có; migration test đã chạy trong CI                                                                                                | Viết lại trước W9 (W8 flex)          | Hẹn W8 flex                                                                                                                                                        |
| Nút đổi theme (`GPThemeModeStore`)                                                     | ADR-0005 _Owed_, chưa tuần nào nhận                                                                                                                                                             | Issue `later`                        | Chờ tạo issue — cần bạn đồng ý đăng lên GitHub                                                                                                                     |
| Row hỏng chưa có đường chữa (quarantine)                                               | ADR-0006                                                                                                                                                                                        | P4/P7 — W4 T6 chỉ quyết policy đọc   | Hẹn P4/P7                                                                                                                                                          |
| "1 dòng học được gì" của W1–W3                                                         | Luật chơi 5; repo chưa có dòng nào                                                                                                                                                              | Tự viết (bỏ qua nếu đã ghi chỗ khác) | Bạn tự viết                                                                                                                                                        |

**Đến hạn trong tuần:** checkpoint tháng 9 vào 30/09 ("Repository của tôi có đang chỉ pass-through không?"). Tuần này đụng codegen, nên theo §10 mở
draft PR sớm.

### W4 T3 — spec bảng `transactions` (ADR-0009)

> Phần lớn mục dưới là cột và constraint. SQLite không `ALTER` được constraint, đổi về sau là rebuild cả bảng (drift `alterTable`) — nên mọi thứ ở đây
> đã chốt trước khi viết.

- [x] Cột theo blueprint §20, **trừ `receipt_id`**: W9 T3 thêm cột này bằng một migration thật trên bảng đã có data. Tên theo §3: `TransactionsTable`,
      `@DataClassName('TransactionRow')`, `tableName => 'transactions'`.
- [x] CHECK: `amount_minor > 0`; `LENGTH(currency_code) = 3` (ADR-0007); `(type = 'transfer') = (destination_account_id IS NOT NULL)`;
      `destination_account_id <> account_id`; `type <> 'transfer' OR category_id IS NULL`. **Không** CHECK vocabulary (`type IN (...)`,
      `sync_status IN (...)`): thêm giá trị về sau là rebuild bảng; mapper từ chối giá trị lạ, giống `accounts.type`.
- [x] FK `account_id`, `destination_account_id` → `accounts(id)`, `category_id` → `categories(id)`, không `ON DELETE` (không có hard delete).
- [x] `sync_status` TEXT NOT NULL; không SQL default ở cột nào, như `accounts`. `occurred_at` là instant, epoch millis UTC.
- [x] 4 index, mỗi cái là `(<owner_id | account_id | destination_account_id | category_id>, occurred_at, id)`; `EXPLAIN QUERY PLAN` trong test chứng minh
      `ORDER BY occurred_at DESC, id DESC LIMIT n` đọc thẳng từ index, không có bước sort.
- [x] `schemaVersion` 4: bước `if (from < 4)` gồm `createTable` **và từng `createIndex`**; dump `drift_schema_v4.json` + generate test schema; test
      v3→v4, v2→v4, v1→v4 và data cũ còn nguyên.
- [x] Test bảng: mỗi CHECK từ chối đúng row sai của nó; FK từ chối `account_id` không tồn tại.

### W4 T4 — spec `TransactionQuery` + `TransactionRepository` (ADR-0011)

> Toàn bộ nằm ở `domain/`: không Drift, không Flutter. Value object đặt cạnh entity và không có hậu tố (CLAUDE.md §3). Năm chỗ đề xuất đã chốt
> 27/09 và ghi vào ADR-0011.

**`TransactionQuery`** — `domain/entities/transaction_query.dart`

- [x] Bộ lọc, tất cả AND với nhau: `accountIds` (khớp **cả hai phía** transfer), `categoryIds`, `types`, `from` / `to` (instant, `[from, to)`). `null` là
      không lọc. `types` là `Set<TransactionType>` chứ không phải một type, để "ẩn transfer" diễn đạt được.
- [x] Set rỗng chuẩn hoá thành `null`, tức không lọc — "không chọn gì = tất cả", như mọi filter chip.
- [x] `limit` bắt buộc, không default: page size là việc của W5. Không offset; "load more" là `withLimit(n)` trên cùng một query.
- [x] Order cố định, không phải tham số: `occurred_at DESC, id DESC`.
- [x] Không có owner, không có "kể cả đã xoá": repository scope owner, DAO lọc tombstone.
- [x] Người gọi dùng sai thì throw `ArgumentError` (ADR-0006: đó là bug): `limit <= 0`, `from > to`. `from == to` hợp lệ — khoảng rỗng. Mốc thời gian
      chuẩn hoá về UTC.
- [x] Value equality — set so sánh không theo thứ tự, hash bằng `Object.hashAllUnordered`, không cần thêm `package:collection` — để W5 bỏ qua query trùng.
- [x] Không có bộ lọc "chưa phân loại": nó dính ADR-0010 (category đã xoá cũng đọc thành chưa phân loại) — để W26.

**`TransactionListSnapshot`** — `domain/entities/transaction_list_snapshot.dart`

- [x] `transactions` (unmodifiable, đúng thứ tự query), `unreadableCount`, `hasMore` (= số row thô bằng `limit`; repository tính). `rowCount` suy ra từ
      `transactions.length + unreadableCount`, không lưu riêng.
- [x] Value equality theo từng phần tử, để `flutter_bloc` bỏ qua lần emit trùng.

**`TransactionRepository`** — `domain/repositories/transaction_repository.dart`

- [x] `watchTransactions(TransactionQuery)` → `Stream<TransactionListSnapshot>`. Row hỏng vào `unreadableCount`; query hỏng → `GPDatabaseFailure` trên
      error channel. Error luôn là `GPFailure`, như `AccountRepository`.
- [x] `watchTransaction(id)` → `Stream<TransactionEntity?>`, null khi đã xoá (màn edit ở W6 T4). Row hỏng → error channel: một row thì không có
      "một phần".
- [x] `createTransaction({type, accountId, destinationAccountId?, categoryId?, amount, occurredAt, note?})` → `GPResult<TransactionEntity>`. Nhận field chứ
      không nhận entity: id và clock nằm sau interface, như `createAccount`.
- [x] `updateTransaction(TransactionEntity)` → `GPResult<TransactionEntity>`, guard `version`.
- [x] `deleteTransaction(id)` → `GPResult<void>`, soft delete, không guard version.
- [x] Doc ghi rõ failure của từng method: `GPValidationFailure` (rule của entity, và currency lệch account — ADR-0010), `GPNotFoundFailure` (account /
      destination không còn), `GPConflictFailure` (chỉ update), `GPDatabaseFailure`.
- [x] `hasLiveTransactions(accountId)` cho `DeleteAccountUseCase` **không** thêm ở T4 — thêm cùng rule ở flex (§12.11).

**Test + doc**

- [x] `transaction_query_test.dart`, `transaction_list_snapshot_test.dart`. Interface chưa có impl nên chưa có gì để test — T6 test qua impl thật trên
      in-memory DB.
- [x] ADR-0011: ghi tên snapshot đã chốt.

### W4 T5 — spec `TransactionDao` (ADR-0009, ADR-0011)

> DAO chỉ nói SQL và row, không giữ policy (khuôn `AccountDao`, pattern doc §6.2): không clock, không uuid, không import domain. DI tạo đúng một instance
> ở T6, không khai báo trong `@DriftDatabase(daos:)`. Mục ghi là chỗ chờ chốt.

**Đọc**

- [x] `watchTransactions(ownerId, {required limit, accountIds, categoryIds, types, fromMillis, toMillis})` → `Stream<List<TransactionRow>>`. Tham số
      primitive: `types` là storage value (`Set<String>`), mốc thời gian là epoch millis — repository map `TransactionQuery` sang. Luôn lọc `owner_id` và
      `deleted_at IS NULL`; order `occurred_at DESC, id DESC`; `LIMIT`. `null` là không lọc.
- [x] Set rỗng theo đúng nghĩa SQL — `IN ()` không khớp row nào. Domain không bao giờ gửi set rỗng (`TransactionQuery` đã chuẩn hoá), nên DAO
      không cần đoán thay.
- [x] Lọc account **cả hai phía**: `account_id IN (…) OR destination_account_id IN (…)`. Plan đo ở T3 (không có điều kiện owner) là sort cả lịch sử
      account; đo lại trên SQL thật của DAO (có owner) thì SQLite đi theo index owner rồi lọc — không sort, nhưng account ít giao dịch phải đọc lùi xa.
      Giữ `OR`; `UNION ALL` hai nhánh để W8 làm nếu số đo cần — đó cũng là "before" thật cho soundbite của W8.
- [x] `watchTransaction(ownerId, id)` → `Stream<TransactionRow?>`, null khi đã xoá hoặc không có.
- [x] `findById(id)` → `Future<TransactionRow?>`, **kể cả tombstone**: `updateTransaction` ở T6 cần nó để phân biệt conflict với not-found, applier ở
      W14 cần nó để đối chiếu.
- [x] `liveAccountCurrency(ownerId, accountId)` → `Future<String?>`: currency của account còn sống và là của owner (archived vẫn tính), null nếu không có,
      đã xoá, hoặc của owner khác.
      Đây là chỗ duy nhất data layer của transactions đọc `accounts` (ADR-0010); T6 gọi nó trong `transaction {}` cho cả account lẫn destination.

**Ghi** — `now` là tham số bắt buộc, như `AccountDao`

- [x] `insertTransaction(companion)`; `updateTransaction(id, {baseVersion, patch, now})` → số row (0 = version cũ, tombstone hoặc không có);
      `softDelete(id, {now})` → số row. Update không đụng `version` (của server); update lẫn softDelete đều không sửa tombstone.
- [x] **DAO đóng dấu `sync_status = 'pending'` trên mọi write local**, đè lên giá trị trong companion — như `updateAccount` tự đóng `updated_at`
      . Hằng `'pending'` nằm ở DAO; mapper ở T6 truyền đúng hằng đó chỉ vì `.insert` bắt buộc có giá trị. `synced` do sync engine ghi ở W13,
      qua đường khác.

**Test** — in-memory DB, SQL thật, không mock

- [x] Scope theo owner, bỏ tombstone, order (kể cả hai row trùng `occurred_at`), `LIMIT`, từng bộ lọc (transfer vào khớp qua `destination_account_id`,
      `from` gồm, `to` không gồm), các bộ lọc AND với nhau, stream re-emit khi có insert / update / delete.
- [x] `watchTransaction` → null sau soft delete; `findById` vẫn thấy tombstone.
- [x] Mọi write đóng `pending`; update có guard version, không sửa tombstone, không đụng `version`; softDelete lần hai trả 0.
- [x] `liveAccountCurrency`: account sống hoặc archived → code; đã xoá hoặc không có → null.
- [x] Test plan chạy trên **đúng SQL của DAO** — qua `constructQuery()` của `selectTransactions` (`@visibleForTesting`) — chứ không chép tay câu SQL:
      query theo owner và theo khoảng thời gian không có `TEMP B-TREE`; query account hai phía không bao giờ `SCAN`, và chấp nhận một trong hai plan đã
      biết — lựa chọn theo chi phí, có thể khác giữa SQLite local và CI — cho tới W8.

### W4 T6 — spec `TransactionMapper` + `TransactionRepositoryImpl` (ADR-0010, ADR-0011)

> Khuôn `AccountMapper` / `AccountRepositoryImpl`: repository giữ policy (id, clock, owner, mapping, rule), DAO chỉ có SQL. Bốn chỗ đề xuất đã chốt
> 30/09 và ghi vào ADR-0010 / ADR-0011.

**`TransactionMapper`** — `data/mapper/transaction_mapper.dart`

- [x] `toEntity(row)` → sealed `TransactionMapping`: `MappedTransaction` hoặc `UnmappableTransactionRow(reason)`, với `TransactionMapperReason` là
      `unknownType` / `malformedCurrencyCode` / `brokenDomainRule`. User luôn thấy một câu (`GPDatabaseFailure`), log thấy reason — như `AccountMapper`.
- [x] `toInsert(entity, ownerId:)`: `.insert` đủ cột, `syncStatus: TransactionDao.pendingSyncStatus`. `toPatch(entity)`: chỉ những cột user sửa được —
      type, account, destination, category, amount + currency, `occurred_at`, note. Không có id, owner, `created_at`, version, `deleted_at`, `sync_status`.

**`TransactionRepositoryImpl`** — `data/repositories/transaction_repository_impl.dart`

- [x] `watchTransactions(query)`: chuyển `TransactionQuery` sang tham số DAO (`types` → storage value, `from` / `to` → millis). Mỗi emission thành một
      `TransactionListSnapshot`: row map được vào list, row bị từ chối cộng vào `unreadableCount`, `hasMore = rows.length == query.limit` (đếm row thô).
      Query lỗi: `Exception` → log + `GPDatabaseFailure`, `Error` → chuyển nguyên, theo khuôn `_reportQueryError` của accounts.
- [x] Row bị từ chối được log **một lần cho mỗi row trong một subscription**. List live chạy lại sau mọi write; log ở mỗi emission thì một row
      hỏng thành hàng trăm dòng log giống hệt nhau.
- [x] `watchTransaction(id)`: null đi thẳng qua; row hỏng → `GPDatabaseFailure` trên error channel.
- [x] `createTransaction` / `updateTransaction`: đọc clock một lần; rule của entity chạy trước, chưa đụng DB; rồi **trong `transaction {}`**: gọi
      `liveAccountCurrency` cho account (và destination nếu là transfer) — null → `GPNotFoundFailure`, lệch currency → `GPValidationFailure` — rồi mới
      ghi. Update có guard version; ghi được 0 row thì `findById` ngay trong transaction để phân biệt conflict với not-found, như `updateAccount`.
- [x] Hai code currency: `transactionCurrencyMismatch` (số tiền khác currency của account — máy khác đổi account, hoặc form giữ currency cũ)
      và `transactionTransferCurrenciesDiffer` (transfer giữa hai account khác currency — user chọn ra được trực tiếp). Hai câu khác nhau vì user phải
      làm hai việc khác nhau. Kèm EN/VI, `failure_message`, `allFailures`; ADR-0010 ghi lại là hai code thay vì một.
- [x] Update kiểm rule account **trước** guard version: không ghi dữ liệu sai rồi mới biết, và conflict vẫn được báo khi account không có vấn
      đề gì.
- [x] `deleteTransaction`: soft delete, 0 row → `GPNotFoundFailure`. Không kiểm account — xoá được cả khi account đã bị xoá.
- [x] `category_id` không tồn tại → FK chặn → `GPDatabaseFailure`. Category còn sống và đúng loại hay không là việc của use case ở flex (ADR-0010).
- [x] Log chỉ có `{entity: 'transaction', id, reason?}` — không amount, không note (golden rule 9).

**DI**

- [x] `configureTransactionsDependencies()` trong `injector.dart`, gọi ở `bootstrap()` sau accounts và categories: đúng một `TransactionDao`,
      `TransactionRepository` → impl, `ownerId: localOwnerId`. Bind ngay dù tới W5 mới có người dùng — như `CategoryRepository` ở W3 T6.

**Test** — in-memory DB, DAO thật, `FakeClock`, `FakeUuidGenerator`, `RecordingLogger`

- [x] Mapper: từng reason; `toInsert` / `toPatch` đúng cột (patch không có version, owner, `created_at`).
- [x] Create: ok (id, clock, owner, `pending`); rule của entity → không có row nào; account không có / đã xoá / của owner khác → not-found; archived →
      ok; lệch currency; transfer có destination đã xoá → not-found, khác currency → code riêng; category không tồn tại → `GPDatabaseFailure`.
- [x] Update: ok (stamp `updated_at`, không đụng version); conflict mang đúng version đang lưu; đã xoá → not-found; account bị xoá hoặc đổi currency
      sau khi form mở → báo đúng failure.
- [x] Delete: thành tombstone; lần hai → not-found.
- [x] Watch: ra đúng snapshot; filter xuống DAO đúng (types, millis, account hai phía); `hasMore` đúng khi cửa sổ đầy, kể cả khi trong đó có row hỏng;
      row hỏng (chèn raw `type = 'refund'`) được đếm và log **một lần** dù list emit nhiều lần.
- [x] DB từ chối, với `ThrowingTransactionDao` / `FailingStreamTransactionDao` theo khuôn accounts: write → `GPDatabaseFailure` + log không payload;
      `Error` không bị nuốt; query lỗi → `GPDatabaseFailure` trên error channel.
- [x] DI: repository bind theo interface; một `TransactionDao` dùng chung.

**Docs**

- [x] ADR-0010 / ADR-0011 ghi phần đã implement; ROADMAP; CLAUDE.md §14.

### W4 Flex — spec use case (ADR-0010)

> Use case chỉ tồn tại khi có rule (CLAUDE.md §3): ba cái dưới, và không có `DeleteTransactionUseCase` — BLoC gọi thẳng repository. Bốn chỗ spec chưa
> nói, chốt trong lúc làm theo đề xuất và ghi vào ADR-0010 (30/09): update chỉ xét filing mà edit tạo ra; edit lệch version để repository báo
> conflict; đọc category bằng `watchCategory(id).first`; `+owner_id` cho câu hỏi xoá account.

**`CreateTransactionUseCase` / `UpdateTransactionUseCase`** — `transactions/domain/usecases/`

- [x] Rule 3: category phải còn sống, là của owner, và cùng loại với type — không thì `GPNotFoundFailure` /
      `GPValidationCode.transactionCategoryTypeMismatch` (+ EN/VI, `failure_message`, `allFailures`). Không có category thì không có rule; category
      thừa của transfer không bị xét, vì entity bỏ nó chứ không từ chối.
- [x] Hai use case dùng chung `refusalFromCategory` — hàm top-level, không phải class. Category đọc bằng `watchCategory(id).first`, nên
      `CategoryRepository` không mọc thêm method đọc một lần; failure trên error channel (`GPDatabaseFailure`) trả về nguyên, `Error` không bị nuốt.
- [x] Create nhận đúng field của repository, mọi failure của repository đi qua nguyên vẹn. Category được xét trước, nên input vừa sai rule entity vừa
      sai category thì lỗi category ra trước — ghi ở dartdoc, có test. Category không tồn tại giờ là not-found chứ không phải `GPDatabaseFailure` của
      FK.
- [x] Update **chỉ xét filing mà edit tạo ra** — đổi category, hoặc đổi type mà vẫn giữ category. Transaction dưới category đã xoá (bình thường, vì
      ADR-0010 cho xoá category còn transaction) hay category bị đổi type vẫn sửa được. Biết edit đổi gì cần row đang lưu: đọc một lần theo id, chỉ
      khi edit có category; row đã xoá → not-found; version lệch → bỏ qua rule để guard version báo conflict — đúng câu, và mời reload.

**`DeleteAccountUseCase`** — `accounts/domain/usecases/`

- [x] `TransactionRepository.hasLiveTransactions(accountId)` → `GPResult<bool>`: cả hai phía transfer, không tính tombstone, account archived vẫn
      tính. Có transaction → `GPValidationCode.accountHasTransactions`, message gợi ý lưu trữ; không có → `AccountRepository.deleteAccount`. Không trả
      lời được → không xoá gì.
- [x] DAO `hasLiveTransactions(ownerId, accountId)`: `EXISTS` bằng raw SQL, vì một ký tự. Owner là equality thường thì SQLite (không có thống kê) chọn
      index owner và đọc hết lịch sử của owner khi account rỗng — đo 30/09, đúng ca được phép xoá. `+owner_id` loại term đó khỏi việc chọn index →
      `MULTI-INDEX OR` trên hai index account, owner vẫn được kiểm trên row tìm thấy. Test plan chạy trên `hasLiveTransactionsSql`.

**DI + test + doc**

- [x] Mỗi use case bind ở module của feature sở hữu: `DeleteAccountUseCase` ở accounts (resolve `TransactionRepository`), hai use case của transaction
      ở transactions (resolve `CategoryRepository`). Mọi registration đều lazy nên thứ tự gọi module không quan trọng; dartdoc ghi cạnh liên module.
- [x] Test trên repository thật + in-memory DB: create 8, update 11, delete account 6; DAO 7 (kể cả plan), repository 3, DI 2.
- [x] ADR-0010 ghi các chốt (và phần _Still open_ đổi gì sau flex); ADR-0006; ROADMAP; CLAUDE.md §14.

## W5 · 05–11/10 🔴 BLoC + list UI

| Ngày | Task                                                                                     | Trạng thái                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | `TransactionBloc`: events `Started / FilterChanged / LoadMoreRequested`, immutable state | ✅ Done (04/10, sớm một ngày) — `features/transactions/presentation/bloc/`: `TransactionListBloc`, event và state là `part` của cùng library. Mới là **phần tính query**, chưa subscribe gì: handler đồng bộ, đọc state, tính `TransactionQuery` kế tiếp, emit — T3 nối `query` vào `watchTransactions`. Đặt tên lệch ROADMAP: **`TransactionListBloc`**, vì form của W6 là BLoC khác (§12.4). `flutter_bloc` 9.1.1 vào pubspec; **`bloc_test` không cài được** trên Dart 3.9.2 (`test` cần `analyzer <8`, `build_runner` 2.15.1 cần `≥8` — CLAUDE.md §5) nên test đọc `bloc.stream` bằng `flutter_test`, T6 cũng vậy. 23 test mới (suite: 641). Spec và bốn chỗ chốt trong lúc làm ở _W5 T2_ dưới (ADR-0011) |
| T3   | Nối BLoC vào Drift stream (`emit.forEach` / `StreamSubscription`), xử lý cancel đúng     | ✅ Done (06/10) — `core/bloc/restartable.dart`: `switchMap` tự viết, huỷ handler đang chạy **trước** khi chạy handler mới. `TransactionListBloc` nhận `WatchTransactionsUseCase`, không giữ repository (**ADR-0013**); chỉ event private `_TransactionListWatchRequested` subscribe (`emit.forEach` dưới `restartable()`), emission trễ của query cũ bị bỏ. **ADR-0012**. 15 test mới (suite: 656), có một test trên repository thật + Drift in-memory: ghi row là list tự cập nhật. Spec ở _W5 T3_ dưới                                                                                                                                                                                                      |
| T4   | Transaction list UI: group theo ngày, hiển thị `Money` đã format                         |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| T5   | Loading / empty / error state cho list                                                   |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| T6   | Test BLoC cho `TransactionListBloc` — bằng `flutter_test`, không có `bloc_test` (W5 T2)  |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Flex | Widget test list, polish nhẹ                                                             |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |

**Done khi:** thêm 1 row vào DB bằng tay → UI tự update, không gọi refresh.

### W5 T2 — spec `TransactionListBloc` (ADR-0011)

> Phần tính toán, chưa có plumbing: mỗi handler đồng bộ, đọc state, tính `TransactionQuery` kế tiếp rồi emit; event không đổi query thì bị bỏ, không
> emit gì. T3 nối `state.query` vào `watchTransactions`. Bốn chỗ ROADMAP chưa nói, chốt trong lúc làm theo đề xuất và ghi vào ADR-0011 (04/10).

**Dependency**

- [x] `flutter_bloc` 9.1.1 (kéo `bloc` 9.2.1, `provider`, `nested`). Không `bloc_concurrency` — transformer tự viết, ở T3 cùng subscription.
- [x] `bloc_test` **không** thêm được: nó cần `package:test`, mọi `test` chấp nhận `test_api 0.7.6` (do `flutter_test` pin) đều cần `analyzer <8`, còn
      `build_runner` 2.15.1 cần `≥8`. Test đọc `bloc.stream` bằng `flutter_test`; seed state bằng subclass khai báo trong file test gọi `emit` — đúng
      việc `seed` của `bloc_test` làm. Ghi ở pubspec, CLAUDE.md §5 và §8.

**Cấu trúc**

- [x] `presentation/bloc/transaction_list_bloc.dart` + `part` `transaction_list_event.dart`, `transaction_list_state.dart` — layout `flutter_bloc`
      hướng dẫn. Cùng library nên event vẫn `sealed` mà T3 vẫn thêm được event private nếu cần.
- [x] Event: `TransactionListStarted` / `TransactionListFilterChanged` / `TransactionListLoadMoreRequested`. Không có refresh (list là query sống), không
      có create / edit / delete (form của W6, đi qua DB như mọi write khác).
- [x] Chưa nhận repository, chưa bind DI: T3 thêm repository cùng subscription; T4 tạo BLoC trong route builder, như `AccountsPage` nhận repository
      qua constructor.

**State** — một class immutable, không phải family `Initial / Loading / Ready / Failure`: row còn trên màn hình trong lúc load more, và lỗi có thể đến
khi đã có row, nên các trạng thái chồng lên nhau

- [x] Ba field: `query` (cửa sổ đang hoặc sắp watch), `snapshot` (row trên màn hình — của `query`, hoặc của cửa sổ nhỏ hơn trong lúc load more), `failure`
      (lỗi trên error channel, giữ **cạnh** snapshot chứ không thay; hiện thế nào là việc của T5).
- [x] Cờ đều suy ra, không lưu: `isLoading` = chưa có snapshot và không có lỗi; `hasMore` = snapshot đầy; `isLoadingMore` = snapshot đầy nhưng ít row hơn
      `query.limit`, và không có lỗi.
- [x] Value equality, vì `Bloc.emit` bỏ state bằng state đang có. `toString` chỉ có id, instant, số đếm (golden rule 9).

**Event**

- [x] `Started`: cửa sổ đầu là không lọc, một trang. `Started` lần hai bị bỏ — không reset list user đã cuộn.
- [x] `FilterChanged` mang **cả bộ lọc**, không phải phần thay đổi: field null là bỏ lọc đó. Lọc khác → về một trang, bỏ snapshot và failure — không row
      nào của filter cũ được hiện dưới filter mới. Lọc y hệt → bỏ qua, giữ cửa sổ và row; so ở limit hiện tại, nên set khác thứ tự hay set rỗng (= null)
      đều là y hệt nhờ equality của `TransactionQuery`. Trước `Started` → bỏ. `from` sau `to` → `ArgumentError` từ `TransactionQuery`, không bị nuốt
      (ADR-0006). Chưa màn nào gửi event này trước thanh lọc của W26 T4.
- [x] `LoadMoreRequested`: chỉ khi snapshot đầy; giữ snapshot (nó là prefix của cửa sổ mới), bỏ failure.

**Chốt trong lúc làm** (ADR-0011)

- [x] `pageSize = 50`: khoảng bốn màn hình trước lần load more đầu, map 50 entity mỗi emission không đáng kể. Là ước lượng; W8 T3 đo first frame.
- [x] Load more hỏi `snapshot.rowCount + pageSize` — đếm row thô, kể cả row hỏng — chứ không `query.limit + pageSize`. Gửi nhiều lần cho cùng một snapshot
      là hỏi cùng một cửa sổ, nên scroll listener bắn mỗi frame chỉ tốn một query; cửa sổ không bao giờ co. Không cần cờ "đang load more" riêng.
- [x] Failure thuộc về watch đã báo nó: đổi query nào cũng xoá. Cửa sổ lớn bị lỗi thì không nới thêm — watch vẫn sống và tự hồi (T3), như list accounts;
      không có retry bằng cuộn.
- [x] `FilterChanged` trước `Started` bị bỏ chứ không thành filter ban đầu. Khi W26 cần mở list với filter sẵn thì thêm filter vào `Started`.

**Để lại cho T3**

- [x] Nhận `TransactionRepository`, subscribe theo `state.query`; mỗi lần query đổi, watch cũ phải bị huỷ **trước khi** kịp giao thêm row — sau
      `FilterChanged`, một emission trễ của filter cũ là row sai trên màn hình.
- [x] `onData` → snapshot mới, xoá failure; `onError` → giữ snapshot, đặt failure; lỗi không phải `GPFailure` là bug, ném lại (ADR-0006).
- [x] `close()` huỷ watch đang chạy.

**Test** — `test/features/transactions/presentation/bloc/transaction_list_bloc_test.dart`, 23 test

- [x] State: cờ suy ra ở từng ca — trước `Started`, lỗi khi chưa có row, cửa sổ đầy / ngắn, load more đang chờ và kết thúc bằng emission đầy, ngắn hoặc
      lỗi; equality; `toString`.
- [x] `Started` hai lần. `FilterChanged`: trước `Started`, lọc mới, thay cả bộ, lọc y hệt, khoảng ngược → lỗi không bị nuốt. `LoadMoreRequested`: nới và
      giữ row, gửi năm lần hỏi một lần, đếm row hỏng, cửa sổ ngắn, chưa có row, bỏ failure, không nới qua cửa sổ đã lỗi.

### W5 T3 — spec nối BLoC vào Drift stream (ADR-0012)

> Handler public vẫn chỉ tính query; một event private duy nhất subscribe. Ba chỗ chốt trong lúc làm, ghi vào ADR-0012 (06/10).

**Transformer** — `core/bloc/restartable.dart`

- [x] `restartable<E>()` → `EventTransformer<E>`, trên `_switchMap` tự viết: huỷ handler đang chạy **trước** khi gọi mapper — với bloc, gọi mapper là
      khởi động handler mới. `switchMap` của `stream_transform` (nền của `bloc_concurrency`) gọi mapper trước rồi mới huỷ.
- [x] Không forward pause (bloc không bao giờ pause event stream). Kết thúc khi source xong và inner cuối cùng xong; cancel output huỷ cả source lẫn inner.

**BLoC**

- [x] `TransactionListBloc({required WatchTransactionsUseCase watchTransactions})` — BLoC không giữ repository (ADR-0013). `WatchTransactionsUseCase` chỉ
      chuyển tiếp `TransactionRepository.watchTransactions`, đăng ký DI ở module transactions; route builder (T4) resolve nó từ `getIt`.
- [x] Ba handler public đồng bộ như T2, đi qua `_watch`: emit state mới ngay, rồi `add(_TransactionListWatchRequested(query))`.
- [x] Chỉ event private subscribe: `emit.forEach(watchTransactions(query))` dưới `restartable()`. `onData` → snapshot mới, xoá failure; `onError` →
      `GPFailure` giữ row và đặt failure, lỗi khác ném lại (ADR-0006).
- [x] Emission trễ: state mới emit trước event private một microtask, trong khe đó watch cũ vẫn có thể giao — so `event.query` với `state.query`, lệch thì
      bỏ.
- [x] `close()`: bloc huỷ handler đang chạy, kéo theo watch — không thêm code.

**Chốt trong lúc làm** (ADR-0012, ADR-0013)

- [x] BLoC chỉ nói chuyện với use case, kể cả use case chỉ chuyển tiếp (ADR-0013, thay phần "use case chỉ khi có rule" của ADR-0010): giữ repository thì
      BLoC gọi được write vòng qua rule — `deleteAccount` không qua `DeleteAccountUseCase`. `AccountsPage` (W3, chưa có BLoC) là ngoại lệ còn lại.
- [x] Tự viết thay `bloc_concurrency` có thêm lý do thứ hai ngoài bớt một dependency: thứ tự huỷ-trước-chạy-sau.
- [x] Event private + chặn emission trễ, thay vì một handler sống lâu nghe `StreamController` các query — cách đó không có khe, nhưng query đi kênh riêng,
      ngoài `BlocObserver`, và phải tự đóng controller.
- [x] Watch lỗi tự hồi ở lần ghi tiếp theo vào bảng: `emit.forEach` có `onError` không huỷ subscription, Drift giữ query stream sau lần chạy lỗi (đã đọc
      source cả hai).

**Test** — 15 test mới (suite: 656)

- [x] `test/core/bloc/restartable_test.dart` (5): huỷ inner cũ trước khi listen inner mới; chuyển lỗi; kết thúc đúng lúc; cancel dây chuyền; trong một bloc
      thật, handler cũ dừng trước khi handler mới chạy.
- [x] `transaction_list_bloc_test.dart` (+9), với `FakeTransactionRepository` mới ở `test/helpers/` (log `listen #n` / `cancel #n`): `Started` mở một
      watch; đổi filter huỷ watch cũ trước; emission trễ của filter cũ không lên màn hình; load more giữ row tới khi cửa sổ lớn trả về; 5 lần load more mở
      một watch; lỗi giữ row và tự xoá ở emission sau; lỗi không phải `GPFailure` không bị nuốt; `close()` huỷ watch; trên repository thật + Drift
      in-memory, ghi row là list tự cập nhật mà không cần event.
- [x] `watch_transactions_use_case_test.dart` (1): chuyển nguyên query và stream, cả lỗi. `injector_test`: use case đăng ký ở module transactions và
      resolve được.
- [x] Mutation check: bỏ chặn emission trễ → test emission trễ fail; đổi transformer sang gọi-mapper-trước-huỷ-sau → 4 test fail.

## W6 · 12–18/10 🔴 CRUD UI + balances

| Ngày | Task                                                                                                                                                                                               |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Form tạo transaction: amount input theo minor unit, chọn account/category/date                                                                                                                     |
| T3   | Validate form ở domain layer, map `ValidationFailure` → message UI                                                                                                                                 |
| T4   | Edit + soft delete + undo (snackbar)                                                                                                                                                               |
| T5   | Transfer flow: 1 transaction, 2 account, không double-count                                                                                                                                        |
| T6   | `watchAccountBalances()` = initial_balance + aggregate query — 4 vế theo ADR-0009 (transfer vào qua `destination_account_id`); transfer của account đã xoá vẫn tính cho account bên kia (ADR-0010) |
| Flex | Dashboard v0: tổng thu/chi tháng này + balance từng account                                                                                                                                        |

**🏁 Milestone P1:** app dùng được hoàn toàn offline, không có dòng network nào. **Tag `v0.1-local`.**

---

# PHASE 2 — Database quality

## W7 · 19–25/10 🔴 Index + aggregate

| Ngày | Task                                                                                                                                                                                   |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Audit index bằng `EXPLAIN QUERY PLAN` cho aggregate mới; thêm cái còn thiếu (bump schema + migration test). Index của list có từ W4 T3 — ADR-0009 tạo index cùng query đầu tiên đọc nó |
| T3   | Aggregate query: spend theo category / tháng — viết bằng SQL thật, không load hết rồi fold trong Dart                                                                                  |
| T4   | `watchMonthlySummary()`, `watchCategoryBreakdown()`                                                                                                                                    |
| T5   | Rà N+1: list transaction có join category/account trong 1 query — join **không** lọc `deleted_at` của bảng cha; category đã xoá hiện "Chưa phân loại" (ADR-0010)                       |
| T6   | Chuyển DB sang background isolate                                                                                                                                                      |
| Flex | Test aggregate query với dataset nhỏ có kết quả biết trước                                                                                                                             |

## W8 · 26/10–01/11 🟡 Seed + benchmark

| Ngày | Task                                                                             |
| ---- | -------------------------------------------------------------------------------- |
| T2   | Data generator: 1k / 10k / 50k transactions, phân bố ngày thực tế                |
| T3   | Benchmark harness: đo cold start, list first frame, scroll jank, dashboard query |
| T4   | Chạy benchmark 10k → ghi số vào `docs/benchmarks/10k.md`                         |
| T5   | Chạy benchmark 50k → tìm query chậm nhất, `EXPLAIN QUERY PLAN`                   |
| T6   | Fix nút thắt (thường là thiếu index hoặc query trên UI isolate), đo lại          |
| Flex | Viết `docs/benchmarks/README.md`: before/after có số cụ thể                      |

**Soundbite:** _"Dashboard query từ 480ms xuống 12ms trên 50k rows sau khi thêm composite index."_ ← số thật, đo được, đây là thứ tạo khác biệt trong phỏng vấn.

## W9 · 02–08/11 🔴 Migration

| Ngày | Task                                                                                                   |
| ---- | ------------------------------------------------------------------------------------------------------ |
| T2   | Setup `drift_dev schema dump` workflow, export schema v1                                               |
| T3   | Migration v1→v2: thêm `transactions.receipt_id`                                                        |
| T4   | Migration v2→v3: thêm `version` + `deleted_at` (backfill giá trị mặc định)                             |
| T5   | Migration test với fixture DB v1 → assert data cũ còn nguyên                                           |
| T6   | Đưa migration test vào CI                                                                              |
| Flex | ADR _Soft delete for synchronized entities_. Viết checklist "khi đổi schema phải làm gì" vào CLAUDE.md |

**🏁 Milestone P2:** DB đủ chất lượng production. **Tag `v0.2-db`.**

---

# PHASE 3 — Backend + Auth

## W10 · 09–15/11 🔴 Supabase schema + RLS

| Ngày | Task                                                                                                                                                    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Tạo Supabase project (dev), enable Auth email/password + flavor dev/prod + `env/dev.json`; bước build của CI thêm `--flavor dev` (W4 Q15, CLAUDE.md §9) |
| T3   | Postgres schema mirror local: accounts, categories, transactions (+ `version`, `updated_at`, `deleted_at`)                                              |
| T4   | RLS policy: user chỉ đọc/ghi được row có `owner_id = auth.uid()`. **Test bằng cách thử đọc row của user khác — phải fail**                              |
| T5   | Index phía server: `(owner_id, updated_at)` phục vụ delta pull                                                                                          |
| T6   | Trigger tăng `version` + set `updated_at` phía server                                                                                                   |
| Flex | ADR _Use Supabase as initial backend_. Ghi lại SQL vào `supabase/migrations/`                                                                           |

## W11 · 16–22/11 🔴 Auth client

| Ngày | Task                                                                                                                                                  |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | `AuthRepository` interface + Supabase impl (sign up / in / out)                                                                                       |
| T3   | Login + Register UI + validation                                                                                                                      |
| T4   | Session restore khi mở app; `AuthBloc` state machine (unknown → authenticated / unauthenticated)                                                      |
| T5   | `go_router` redirect guard theo auth state                                                                                                            |
| T6   | Logout: **xoá sạch local DB + secure storage + cancel sync**. Đây là chỗ rất hay bị làm ẩu — xoá con trước cha vì FK, hoặc xoá hẳn file DB (ADR-0009) |
| Flex | Token lưu ở `flutter_secure_storage`, không SharedPreferences. Audit log xem có leak token không                                                      |

**🏁 Milestone P3:** **Tag `v0.3-auth`.**

---

# PHASE 4 — Sync V1 (phần quan trọng nhất)

> Nếu chỉ có thời gian làm 1 phase cho tử tế, là phase này.

## W12 · 23–29/11 🔴 Outbox

| Ngày | Task                                                                                                                                                                                                              |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Drift table `sync_mutations` + index `(status, next_attempt_at)`; table `sync_metadata`                                                                                                                           |
| T3   | `SyncMutation` model: entityType, entityId, operation, payload_json, idempotencyKey, attemptCount, status                                                                                                         |
| T4   | `SyncQueueRepository`: enqueue / getReadyMutations / complete / scheduleRetry / markConflict                                                                                                                      |
| T5   | **Nối outbox vào repository write path**: insert entity + insert mutation trong CÙNG `database.transaction()` — kể cả `sync_status = 'pending'`; backfill mutation cho mọi row `pending` tạo trước W12 (ADR-0009) |
| T6   | Test invariant: entity tồn tại & cần sync ⇒ mutation tồn tại. Test crash giữa chừng (throw trong transaction → rollback cả hai)                                                                                   |
| Flex | ADR _Use outbox for local mutations_. `sync_status` badge trên transaction item — lúc này mới đưa `syncStatus` lên entity, và index `(sync_status)` nếu badge cần query (ADR-0009)                                |

## W13 · 30/11–06/12 🔴 Push

| Ngày | Task                                                                                                                                                               |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| T2   | `SyncRemoteDataSource.push(mutation)` qua Supabase RPC hoặc Edge Function                                                                                          |
| T3   | Server-side upsert function nhận `baseVersion`, trả `applied` / `conflict`                                                                                         |
| T4   | `SyncEngine.synchronize()` v0: chỉ push, xử lý result, xoá mutation khi thành công — xoá mutation + set `sync_status = 'synced'` trong cùng transaction (ADR-0009) |
| T5   | Phân loại lỗi: retryable vs non-retryable, map sang `Failure`                                                                                                      |
| T6   | Test push với fake remote: success / network error / 4xx                                                                                                           |
| Flex | Manual test: tắt mạng → tạo 3 transaction → bật mạng → bấm sync → check bảng Supabase                                                                              |

## W14 · 07–13/12 🔴 Pull

| Ngày | Task                                                                                                                            |
| ---- | ------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Server function delta pull theo cursor (`updated_at, id` composite cursor, không dùng wall-clock đơn thuần)                     |
| T3   | `SyncRemoteDataSource.pull(cursor)` + phân trang (`hasMore`, `nextCursor`)                                                      |
| T4   | `RemoteChangeApplier`: apply từng change vào local DB — cha trước con: accounts/categories trước transactions, vì FK (ADR-0009) |
| T5   | Apply toàn bộ page + set cursor trong **cùng 1 DB transaction** (crash giữa chừng không được mất cursor lẫn data)               |
| T6   | Test: pull 3 page, kill giữa page 2 → chạy lại phải resume đúng, không mất/không trùng                                          |
| Flex | Full cycle push→pull chạy được                                                                                                  |

## W15 · 14–20/12 🔴 Soft delete + reconcile

| Ngày | Task                                                                                                                         |
| ---- | ---------------------------------------------------------------------------------------------------------------------------- |
| T2   | Delete → set `deleted_at` + enqueue mutation `operation: delete`                                                             |
| T3   | Mọi query local phải filter `deleted_at IS NULL` — rà toàn bộ DAO                                                            |
| T4   | Pull nhận tombstone → apply soft delete local                                                                                |
| T5   | Xử lý remote change đụng entity đang có pending mutation (local pending thắng hay remote thắng — **quyết định và document**) |
| T6   | Chạy **Final Target scenario** của blueprint end-to-end, ghi lại chỗ nào vỡ                                                  |
| Flex | Fix những chỗ vỡ. Quay video demo thô                                                                                        |

**🏁 Milestone P4:** offline → online sync hoạt động, không duplicate. **Tag `v0.4-sync`.** Đây là điểm project bắt đầu đáng đưa vào CV.

---

# 🎄 W16–W17 — Tuần nhẹ / đệm

## W16 · 21–27/12 🟢

Tải nhẹ, 45–60 phút/ngày là đủ.

| Ngày | Task                                                                                  |
| ---- | ------------------------------------------------------------------------------------- |
| T2   | Sync Diagnostics screen (dev-only): device id, last sync, cursor, pending count       |
| T3   | Diagnostics: nút Run Sync + list pending mutations (**không hiện payload tài chính**) |
| T4   | Backfill ADR còn thiếu                                                                |
| T5   | Dọn TODO, xoá code chết                                                               |
| T6   | Cập nhật `CLAUDE.md` mục Current status + README skeleton                             |
| Flex | Nghỉ                                                                                  |

## W17 · 28/12–03/01 🟢 Đệm

Tuần catch-up. Nếu đang on-track: viết `docs/system-design.md` phiên bản của riêng bạn (sau khi đã code xong sync, bản này sẽ chính xác hơn nhiều bản viết lúc chưa code). Nếu đang trễ: bù phase 4.

---

# PHASE 5 — Sync robustness

## W18 · 04–10/01/2027 🔴 Idempotency + lock

| Ngày | Task                                                                                                             |
| ---- | ---------------------------------------------------------------------------------------------------------------- |
| T2   | Idempotency key sinh 1 lần lúc enqueue, **không đổi khi retry**                                                  |
| T3   | Server lưu bảng `processed_mutations(idempotency_key)`, replay trả về kết quả cũ thay vì apply lại               |
| T4   | Test kịch bản: request tới server thành công nhưng client timeout → retry → server **không** tạo bản ghi thứ hai |
| T5   | Single-flight lock cho `synchronize()`                                                                           |
| T6   | Test: 3 trigger đồng thời (resume + connectivity + manual) chỉ chạy 1 sync                                       |
| Flex | ADR _Version-based conflict detection_                                                                           |

## W19 · 11–17/01 🔴 Retry + recovery

| Ngày | Task                                                                             |
| ---- | -------------------------------------------------------------------------------- |
| T2   | `RetryPolicy`: exponential backoff + jitter, max attempt, dead-letter state      |
| T3   | Inject `Clock` để test backoff không cần `Future.delayed` thật                   |
| T4   | Test bảng phân loại retryable / non-retryable (timeout, 500, 429, 400, 401, 409) |
| T5   | Recovery khi app khởi động: mutation `processing` mồ côi → reset về `pending`    |
| T6   | Test app-kill giữa sync ở 3 điểm khác nhau                                       |
| Flex | UI: pending sync indicator + banner "n thay đổi chưa đồng bộ"                    |

## W20 · 18–24/01 🟡 Conflict

| Ngày | Task                                                                                                                                                                                      |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Server phát hiện conflict: `UPDATE ... WHERE version = ?`, affected = 0 → trả conflict + remote entity                                                                                    |
| T3   | Local: bảng `sync_conflicts` lưu localValue / remoteValue / baseVersion                                                                                                                   |
| T4   | Conflict policy theo entity (transaction: explicit; category name: server-wins; settings: LWW; locale **không** sync, là thuộc tính thiết bị — ADR-0004) — document trong ADR             |
| T5   | Conflict UX: màn hình chọn giữ bản nào. **Không cần đọc lại remote entity**: màn chi tiết đã subscribe `watchAccount(id)` nên bản mới tới trước khi `GPConflictFailure` trả về (ADR-0006) |
| T6   | Test conflict: 2 fake device cùng edit 1 transaction                                                                                                                                      |
| Flex | Test: A edit + B delete cùng lúc                                                                                                                                                          |

## W21 · 25–31/01 🔴 Triggers + integration test

| Ngày | Task                                                                                        |
| ---- | ------------------------------------------------------------------------------------------- |
| T2   | Sync trigger: app start, app resume, connectivity change, manual pull-to-refresh            |
| T3   | `workmanager` background sync + constraint network, tránh chạy quá thường xuyên             |
| T4   | Sync telemetry: duration, pushed, pulled, failed → log có cấu trúc (không log payload)      |
| T5   | Integration test 1: offline CRUD → kill app → restart → online → sync → assert server state |
| T6   | Integration test 2: 2 device (2 local DB instance) push/pull chéo, assert hội tụ            |
| Flex | Đưa integration test vào CI (có thể chỉ chạy nightly)                                       |

**🏁 Milestone P5:** sync engine đủ chắc. **Tag `v0.5-sync-hardened`.**

---

# 🧧 W22 · 01–07/02 — Đệm Tết

Nghỉ hoặc làm nhẹ. Nếu muốn động tay: quay demo video 3 phút cho Final Target scenario, hoặc viết README phần "Key Engineering Challenges".

---

# PHASE 7 — Security

## W23 · 08–14/02 🟡

| Ngày | Task                                                                            |
| ---- | ------------------------------------------------------------------------------- |
| T2   | Audit toàn bộ log: không amount, không note, không email, không token           |
| T3   | Biometric lock (`local_auth`) + app lifecycle: lock khi background > N giây     |
| T4   | Secure session: refresh token flow, xử lý 401 → refresh → retry 1 lần           |
| T5   | Rà lại RLS bằng test thật: user A cố đọc data user B qua REST → phải 403/empty  |
| T6   | 🟢 DB encryption (SQLite3MultipleCiphers) — optional, chỉ làm nếu còn thời gian |
| Flex | Sentry setup + scrub PII trong `beforeSend`                                     |

---

# PHASE 6 — Product features

## W24 · 15–21/02 🟡 Budget

| Ngày | Task                                                                                  |
| ---- | ------------------------------------------------------------------------------------- |
| T2   | Drift table `budgets` + migration + DAO                                               |
| T3   | Domain `Budget` + `BudgetPeriod` + repository                                         |
| T4   | Budget engine: tính spent theo period bằng aggregate query, không loop trong Dart     |
| T5   | `watchBudgetSummary()` reactive + UI progress bar                                     |
| T6   | Budget vào outbox + sync (đừng quên — feature mới nào cũng phải trả lời câu hỏi sync) |
| Flex | Cảnh báo khi vượt `warning_percent`                                                   |

## W25 · 22–28/02 🟡 Analytics

| Ngày | Task                                                                 |
| ---- | -------------------------------------------------------------------- |
| T2   | Query: spend theo tháng (12 tháng), theo category, income vs expense |
| T3   | `fl_chart` bar chart: chi tiêu theo tháng                            |
| T4   | Pie/donut: breakdown theo category                                   |
| T5   | Period selector (tháng / quý / năm) bằng Cubit                       |
| T6   | Kiểm tra performance analytics trên dataset 50k                      |
| Flex | Empty state cho chart, accessibility label                           |

## W26 · 01–07/03 🟡 Search / filter / pagination

| Ngày | Task                                                                                                                           |
| ---- | ------------------------------------------------------------------------------------------------------------------------------ |
| T2   | Keyset pagination thay growing limit của W4 **nếu** benchmark W8 cho thấy cần (ADR-0011) — BLoC giữ nguyên `LoadMoreRequested` |
| T3   | Infinite scroll + `LoadMoreRequested` trong BLoC                                                                               |
| T4   | Filter: date range, account, category, type, amount range                                                                      |
| T5   | Search theo note (cân nhắc FTS5 nếu chậm), debounce input                                                                      |
| T6   | Benchmark lại list + search trên 50k, cập nhật `docs/benchmarks/`                                                              |
| Flex | Lưu filter state qua navigation                                                                                                |

---

# PHASE 10 — Polish & release

## W27 · 08–14/03 🔴 Test + performance

| Ngày | Task                                                                                      |
| ---- | ----------------------------------------------------------------------------------------- |
| T2   | Đo coverage, xác định vùng chưa test; ưu tiên sync + money + migration                    |
| T3   | Bù unit test cho vùng thiếu                                                               |
| T4   | Widget test cho các màn hình chính (loading/error/empty)                                  |
| T5   | `patrol` E2E golden path: login → tạo account → tạo transaction → offline → online → sync |
| T6   | DevTools profiling: jank, rebuild thừa, memory                                            |
| Flex | Fix perf issue tìm được                                                                   |

## W28 · 15–21/03 🔴 Case study + release

| Ngày | Task                                                                                                                                                    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | README theo cấu trúc blueprint §52 (Why I built this → Key Engineering Challenges → Sync Strategy → Conflict Resolution → Trade-offs → Lessons Learned) |
| T3   | Architecture diagram (mermaid) + schema diagram + sync sequence diagram                                                                                 |
| T4   | Quay demo video 3–5 phút chạy đúng Final Target scenario 15 bước                                                                                        |
| T5   | Release build Android + APK trên GitHub Releases, screenshots                                                                                           |
| T6   | Viết 5 CV bullet + chuẩn bị 10 câu interview talking point (blueprint §53–54)                                                                           |
| Flex | Đọc lại toàn bộ ADR, tự hỏi lại các câu ở blueprint §3 — trả lời trôi chảy không?                                                                       |

**🏁 CV-READY.** Đối chiếu checklist blueprint §51. Nếu còn ô chưa tick ở nhóm **Offline** hoặc **DB** → chưa xong.

---

# W29+ — Mở rộng (tùy chọn)

Chỉ làm sau khi §51 đã tick đủ.

| Tuần    | Nội dung                                                                                                                                                                                               |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| W29–W30 | Receipt: image picker, upload Supabase Storage, upload queue riêng                                                                                                                                     |
| W31     | OCR `google_mlkit_text_recognition` + parser merchant/total/date + màn confirm                                                                                                                         |
| W32     | Recurring rules + occurrence generation + idempotency (không sinh trùng khi chạy 2 lần)                                                                                                                |
| W33–W36 | 🔥 Thay Supabase bằng **NestJS + Postgres** backend tự viết. Đây là bước biến project từ "Flutter portfolio" thành "full-stack portfolio", và repository abstraction ở P1 sẽ chứng minh giá trị của nó |
| W37+    | Multi-currency, shared wallet, device management, audit history, import/export                                                                                                                         |

---

# Checkpoint hàng tháng

Cuối mỗi tháng, tự trả lời (viết ra, không nghĩ trong đầu):

| Tháng   | Câu hỏi kiểm tra                                                              |
| ------- | ----------------------------------------------------------------------------- |
| T9/2026 | Repository của tôi có đang chỉ pass-through không?                            |
| T10     | Tôi có số benchmark thật không, hay chỉ "cảm giác nhanh"?                     |
| T11     | Nếu app crash sau khi insert entity, mutation có tồn tại không? Tại sao?      |
| T12     | Nếu request thành công nhưng client timeout, tôi có tạo bản ghi trùng không?  |
| T1/2027 | Tôi giải thích được vì sao chọn push→pull thay vì pull→push→pull chưa?        |
| T2      | Có log nào đang chứa số tiền hoặc token không?                                |
| T3      | Người lạ đọc README có hiểu điểm khó kỹ thuật của project trong 2 phút không? |

---

# Tracker

```
W1  [x]   W8  [ ]   W15 [ ]   W22 [ ]
W2  [x]   W9  [ ]   W16 [ ]   W23 [ ]
W3  [x]   W10 [ ]   W17 [ ]   W24 [ ]
W4  [x]   W11 [ ]   W18 [ ]   W25 [ ]
W5  [ ]   W12 [ ]   W19 [ ]   W26 [ ]
W6  [ ]   W13 [ ]   W20 [ ]   W27 [ ]
W7  [ ]   W14 [ ]   W21 [ ]   W28 [ ]
```
