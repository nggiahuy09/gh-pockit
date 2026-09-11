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

| Ngày           | Task (1–2h)                                                                                                                                                                                                                                                                            | Trạng thái                                                                                                                                                                                          |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2             | `flutter create`, pin Flutter/Dart SDK vào `.fvmrc`, set package name, tạo repo GitHub, push commit đầu                                                                                                                                                                                | ✅ Done                                                                                                                                                                                             |
| T3             | `analysis_options.yaml` strict (very_good_analysis hoặc custom), `dart format` hook, tạo `docs/` + copy blueprint vào `docs/blueprint.md`, copy `CLAUDE.md`                                                                                                                            | ✅ Done — `very_good_analysis` 10.0.0 + override, `.githooks/pre-commit` (format + analyze)                                                                                                         |
| T4             | GitHub Actions: format → analyze → test. Bật branch protection cho `main`                                                                                                                                                                                                              | ✅ CI xong — `.github/workflows/ci.yml`; branch protection phải bật tay (checklist ở README §CI)                                                                                                    |
| T5             | `get_it` setup: `configureCoreDependencies()`, đăng ký `Clock`, `UuidGenerator`, `Logger` (3 abstraction này sẽ cứu bạn ở phần test sync)                                                                                                                                              | ✅ Done — `lib/app/di/injector.dart` + `bootstrap.dart`; v7 monotonic counter (ADR-0002), redaction bắt buộc trong `GPAppLogger.log`; prefix `GP` cho core type (CLAUDE.md §3)                      |
| T6             | `go_router` shell + 5 route rỗng (`/home`, `/accounts`, `/transactions`, `/budgets`, `/settings`), bottom nav                                                                                                                                                                          | ✅ Done — `StatefulShellRoute.indexedStack` (ADR-0003), `lib/app/router/`; `go_router` **17.2.3** chứ không phải 18.0.1 (18.x cần Dart ≥3.12, ta pin 3.9.2); `/home` nằm ở feature mới `dashboard/` |
| Cuối tuần flex | `sealed class Failure` (Appendix B của blueprint), theme + design tokens, ADR-0001 draft, **bật branch protection cho `dev`** (nợ T4 — `main` đã bật; `dev` là staging cut build AB-test nên phải require PR + check `format → analyze → test`, chặn force-push, theo `CLAUDE.md` §10) | ⬜                                                                                                                                                                                                  |
| Ngoài kế hoạch | Chốt app name **Pockit** + cài app icon (android adaptive/themed + ios), lưu SVG master & spec vào `docs/design/app-icon/`                                                                                                                                                             | ✅ Done                                                                                                                                                                                             |
| Ngoài kế hoạch | **Localization EN/VI** — `core/localization/` viết tay (ADR-0004), `flutter_localizations`, language picker trong Settings. Làm sớm vì `Failure` (W1 flex), seed category (W3 T5) và `Money` (W3) đều bake sẵn câu trả lời nếu không chốt trước                                        | ✅ Done                                                                                                                                                                                             |

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

| Ngày | Task                                                                                                                                                            |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Cài `drift` + `drift_flutter`, tạo `AppDatabase`, chạy được query đầu tiên. **Lưu ý:** không thêm `sqlite3_flutter_libs` theo tutorial cũ                       |
| T3   | Drift table `accounts` đủ cột sync-ready (`id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at`) |
| T4   | `AccountDao`: insert / update / `watchAccounts()` / `archive()`                                                                                                 |
| T5   | Domain: `Account` entity, `AccountType` enum, `AccountRepository` interface                                                                                     |
| T6   | `AccountRepositoryImpl` + `AccountMapper` (row ↔ entity). Test mapper                                                                                           |
| Flex | ADR-0001 _Use Drift as local source of truth_. Repository test với in-memory DB                                                                                 |

**Done khi:** test `create → watchAccounts emit` pass.

## W3 · 21–27/09 🔴 Money + Category

| Ngày | Task                                                                                  |
| ---- | ------------------------------------------------------------------------------------- |
| T2   | `Money` value object: `minorUnits` + `currencyCode`, `add/subtract/compare`           |
| T3   | Test `Money` kỹ: cộng khác currency phải throw, format VND vs USD, số âm, số lớn      |
| T4   | `MoneyFormatter` dùng `intl`; `CurrencyCode` catalog (VND exponent 0, USD exponent 2) |
| T5   | Drift table `categories` + `CategoryDao` + seed default categories (is_system = true) |
| T6   | Domain `Category` + repository + mapper + test                                        |
| Flex | ADR-0007 _Store money as integer minor units_. UI list accounts thô (chưa cần đẹp)    |

**Done khi:** không còn `double` nào liên quan tới tiền trong codebase.

## W4 · 28/09–04/10 🔴 Transaction core

| Ngày | Task                                                                                                                                                        |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Drift table `transactions` đủ cột (bao gồm `version`, `deleted_at`, `sync_status`)                                                                          |
| T3   | Domain `Transaction` entity + `TransactionType` (expense/income/transfer) + validation rule (transfer bắt buộc `destination_account_id`, khác `account_id`) |
| T4   | `TransactionDao`: insert/update/soft-delete/`watchTransactions(query)`                                                                                      |
| T5   | `TransactionQuery` value object: date range, accountIds, categoryIds, type, limit/offset                                                                    |
| T6   | `TransactionRepositoryImpl` + mapper + repository test                                                                                                      |
| Flex | Use cases: `CreateTransaction`, `UpdateTransaction`, `DeleteTransaction` với domain validation                                                              |

## W5 · 05–11/10 🔴 BLoC + list UI

| Ngày | Task                                                                                     |
| ---- | ---------------------------------------------------------------------------------------- |
| T2   | `TransactionBloc`: events `Started / FilterChanged / LoadMoreRequested`, immutable state |
| T3   | Nối BLoC vào Drift stream (`emit.forEach` / `StreamSubscription`), xử lý cancel đúng     |
| T4   | Transaction list UI: group theo ngày, hiển thị `Money` đã format                         |
| T5   | Loading / empty / error state cho list                                                   |
| T6   | `bloc_test` cho `TransactionBloc`                                                        |
| Flex | Widget test list, polish nhẹ                                                             |

**Done khi:** thêm 1 row vào DB bằng tay → UI tự update, không gọi refresh.

## W6 · 12–18/10 🔴 CRUD UI + balances

| Ngày | Task                                                                           |
| ---- | ------------------------------------------------------------------------------ |
| T2   | Form tạo transaction: amount input theo minor unit, chọn account/category/date |
| T3   | Validate form ở domain layer, map `ValidationFailure` → message UI             |
| T4   | Edit + soft delete + undo (snackbar)                                           |
| T5   | Transfer flow: 1 transaction, 2 account, không double-count                    |
| T6   | `watchAccountBalances()` = initial_balance + aggregate query                   |
| Flex | Dashboard v0: tổng thu/chi tháng này + balance từng account                    |

**🏁 Milestone P1:** app dùng được hoàn toàn offline, không có dòng network nào. **Tag `v0.1-local`.**

---

# PHASE 2 — Database quality

## W7 · 19–25/10 🔴 Index + aggregate

| Ngày | Task                                                                                                  |
| ---- | ----------------------------------------------------------------------------------------------------- |
| T2   | Thêm toàn bộ index theo blueprint (`owner_id, occurred_at DESC` v.v.)                                 |
| T3   | Aggregate query: spend theo category / tháng — viết bằng SQL thật, không load hết rồi fold trong Dart |
| T4   | `watchMonthlySummary()`, `watchCategoryBreakdown()`                                                   |
| T5   | Rà N+1: list transaction có join category/account trong 1 query                                       |
| T6   | Chuyển DB sang background isolate                                                                     |
| Flex | Test aggregate query với dataset nhỏ có kết quả biết trước                                            |

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

| Ngày | Task                                                                                                        |
| ---- | ----------------------------------------------------------------------------------------------------------- |
| T2   | Setup `drift_dev schema dump` workflow, export schema v1                                                    |
| T3   | Migration v1→v2: thêm `transactions.receipt_id`                                                             |
| T4   | Migration v2→v3: thêm `version` + `deleted_at` (backfill giá trị mặc định)                                  |
| T5   | Migration test với fixture DB v1 → assert data cũ còn nguyên                                                |
| T6   | Đưa migration test vào CI                                                                                   |
| Flex | ADR-0004 _Soft delete for synchronized entities_. Viết checklist "khi đổi schema phải làm gì" vào CLAUDE.md |

**🏁 Milestone P2:** DB đủ chất lượng production. **Tag `v0.2-db`.**

---

# PHASE 3 — Backend + Auth

## W10 · 09–15/11 🔴 Supabase schema + RLS

| Ngày | Task                                                                                                                       |
| ---- | -------------------------------------------------------------------------------------------------------------------------- |
| T2   | Tạo Supabase project (dev), enable Auth email/password                                                                     |
| T3   | Postgres schema mirror local: accounts, categories, transactions (+ `version`, `updated_at`, `deleted_at`)                 |
| T4   | RLS policy: user chỉ đọc/ghi được row có `owner_id = auth.uid()`. **Test bằng cách thử đọc row của user khác — phải fail** |
| T5   | Index phía server: `(owner_id, updated_at)` phục vụ delta pull                                                             |
| T6   | Trigger tăng `version` + set `updated_at` phía server                                                                      |
| Flex | ADR-0005 _Use Supabase as initial backend_. Ghi lại SQL vào `supabase/migrations/`                                         |

## W11 · 16–22/11 🔴 Auth client

| Ngày | Task                                                                                             |
| ---- | ------------------------------------------------------------------------------------------------ |
| T2   | `AuthRepository` interface + Supabase impl (sign up / in / out)                                  |
| T3   | Login + Register UI + validation                                                                 |
| T4   | Session restore khi mở app; `AuthBloc` state machine (unknown → authenticated / unauthenticated) |
| T5   | `go_router` redirect guard theo auth state                                                       |
| T6   | Logout: **xoá sạch local DB + secure storage + cancel sync**. Đây là chỗ rất hay bị làm ẩu       |
| Flex | Token lưu ở `flutter_secure_storage`, không SharedPreferences. Audit log xem có leak token không |

**🏁 Milestone P3:** **Tag `v0.3-auth`.**

---

# PHASE 4 — Sync V1 (phần quan trọng nhất)

> Nếu chỉ có thời gian làm 1 phase cho tử tế, là phase này.

## W12 · 23–29/11 🔴 Outbox

| Ngày | Task                                                                                                                            |
| ---- | ------------------------------------------------------------------------------------------------------------------------------- |
| T2   | Drift table `sync_mutations` + index `(status, next_attempt_at)`; table `sync_metadata`                                         |
| T3   | `SyncMutation` model: entityType, entityId, operation, payload_json, idempotencyKey, attemptCount, status                       |
| T4   | `SyncQueueRepository`: enqueue / getReadyMutations / complete / scheduleRetry / markConflict                                    |
| T5   | **Nối outbox vào repository write path**: insert entity + insert mutation trong CÙNG `database.transaction()`                   |
| T6   | Test invariant: entity tồn tại & cần sync ⇒ mutation tồn tại. Test crash giữa chừng (throw trong transaction → rollback cả hai) |
| Flex | ADR-0003 _Use outbox for local mutations_. `sync_status` badge trên transaction item                                            |

## W13 · 30/11–06/12 🔴 Push

| Ngày | Task                                                                                  |
| ---- | ------------------------------------------------------------------------------------- |
| T2   | `SyncRemoteDataSource.push(mutation)` qua Supabase RPC hoặc Edge Function             |
| T3   | Server-side upsert function nhận `baseVersion`, trả `applied` / `conflict`            |
| T4   | `SyncEngine.synchronize()` v0: chỉ push, xử lý result, xoá mutation khi thành công    |
| T5   | Phân loại lỗi: retryable vs non-retryable, map sang `Failure`                         |
| T6   | Test push với fake remote: success / network error / 4xx                              |
| Flex | Manual test: tắt mạng → tạo 3 transaction → bật mạng → bấm sync → check bảng Supabase |

## W14 · 07–13/12 🔴 Pull

| Ngày | Task                                                                                                              |
| ---- | ----------------------------------------------------------------------------------------------------------------- |
| T2   | Server function delta pull theo cursor (`updated_at, id` composite cursor, không dùng wall-clock đơn thuần)       |
| T3   | `SyncRemoteDataSource.pull(cursor)` + phân trang (`hasMore`, `nextCursor`)                                        |
| T4   | `RemoteChangeApplier`: apply từng change vào local DB                                                             |
| T5   | Apply toàn bộ page + set cursor trong **cùng 1 DB transaction** (crash giữa chừng không được mất cursor lẫn data) |
| T6   | Test: pull 3 page, kill giữa page 2 → chạy lại phải resume đúng, không mất/không trùng                            |
| Flex | ADR-0002 _Client-generated UUID_. Full cycle push→pull chạy được                                                  |

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
| Flex | ADR-0006 _Version-based conflict detection_                                                                      |

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

| Ngày | Task                                                                                                                |
| ---- | ------------------------------------------------------------------------------------------------------------------- |
| T2   | Server phát hiện conflict: `UPDATE ... WHERE version = ?`, affected = 0 → trả conflict + remote entity              |
| T3   | Local: bảng `sync_conflicts` lưu localValue / remoteValue / baseVersion                                             |
| T4   | Conflict policy theo entity (transaction: explicit; category name: server-wins; settings: LWW) — document trong ADR |
| T5   | Conflict UX: màn hình chọn giữ bản nào                                                                              |
| T6   | Test conflict: 2 fake device cùng edit 1 transaction                                                                |
| Flex | Test: A edit + B delete cùng lúc                                                                                    |

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

| Ngày | Task                                                                   |
| ---- | ---------------------------------------------------------------------- |
| T2   | Cursor pagination cho transaction list (không offset trên dataset lớn) |
| T3   | Infinite scroll + `LoadMoreRequested` trong BLoC                       |
| T4   | Filter: date range, account, category, type, amount range              |
| T5   | Search theo note (cân nhắc FTS5 nếu chậm), debounce input              |
| T6   | Benchmark lại list + search trên 50k, cập nhật `docs/benchmarks/`      |
| Flex | Lưu filter state qua navigation                                        |

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
W1  [ ]   W8  [ ]   W15 [ ]   W22 [ ]
W2  [ ]   W9  [ ]   W16 [ ]   W23 [ ]
W3  [ ]   W10 [ ]   W17 [ ]   W24 [ ]
W4  [ ]   W11 [ ]   W18 [ ]   W25 [ ]
W5  [ ]   W12 [ ]   W19 [ ]   W26 [ ]
W6  [ ]   W13 [ ]   W20 [ ]   W27 [ ]
W7  [ ]   W14 [ ]   W21 [ ]   W28 [ ]
```
