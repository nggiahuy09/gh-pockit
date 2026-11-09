#!/usr/bin/env bash
# Two pushes from one owner race a pull (W11 T6, ADR-0036). The first push stamps its row and holds the transaction open; the second
# must wait for it, so no pull taken in between can move its cursor past a row that commits later. Real sessions, so pgTAP cannot run
# it: it needs the local stack (`supabase db start`), commits for real, and deletes its user on the way out.
set -euo pipefail

container=supabase_db_gh-pockit
owner=d0000000-0000-4000-8000-000000000000
account=d1000000-0000-4000-8000-000000000001
first=d3000000-0000-4000-8000-000000000001
second=d3000000-0000-4000-8000-000000000002
signed_in="set local role authenticated; select set_config('request.jwt.claims', '{\"sub\": \"$owner\", \"role\": \"authenticated\"}', true);"

psql_as() { docker exec -i -e PGAPPNAME="$1" "$container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -qtA; }
query() { psql_as pockit_test <<<"$1" | tail -n 1; }
insert_transaction() {
  echo "insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at,
    note, created_at, updated_at, version, deleted_at) values ('$1', '$owner', 'expense', '$account', null, null, 1000, 'VND', 1762560000000, null,
    1762560000000, 1, 1, null);"
}

cleanup() { query "delete from auth.users where id = '$owner';" >/dev/null; }
trap cleanup EXIT
cleanup
query "insert into auth.users (id, email) values ('$owner', 'race@pockit.test');
  insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
  values ('$account', '$owner', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1, 1, null);" >/dev/null

failures=0
check() {
  if [[ "$2" == "$3" ]]; then echo "ok - $1"; else echo "not ok - $1 (have: $2, want: $3)"; failures=$((failures + 1)); fi
}

# Push 1 stamps its row, then stays open for five seconds: longer than the checks below take, at about 0.2 s per `docker exec`.
psql_as pockit_push_1 >/dev/null <<<"begin; $signed_in $(insert_transaction "$first") select pg_sleep(5); commit;" &
push_1=$!
sleep 0.5
psql_as pockit_push_2 >/dev/null <<<"begin; $signed_in $(insert_transaction "$second") commit;" &
push_2=$!

waiting=""
for _ in $(seq 10); do
  waiting=$(query "select wait_event_type || ':' || wait_event from pg_stat_activity where application_name = 'pockit_push_2' and state = 'active';")
  [[ "$waiting" == "Lock:advisory" ]] && break
  sleep 0.1
done
check "push 2 waits on push 1's owner lock" "$waiting" "Lock:advisory"

# The pull a device takes meanwhile, and the cursor it would keep: its last row, or the start.
cursor=$(query "begin; $signed_in select coalesce(max(updated_at), 0) || ',' || coalesce(max(id::text), '00000000-0000-0000-0000-000000000000')
  from (select updated_at, id from public.transactions order by updated_at desc, id desc limit 1) last; commit;")
seen=$(query "begin; $signed_in select count(*) from public.transactions; commit;")
check "a pull taken while both are in flight sees neither row" "$seen" "0"

wait "$push_1" "$push_2"

cursor_at=${cursor%%,*}
cursor_id=${cursor#*,}
pulled=$(query "begin; $signed_in select string_agg(id::text, ',' order by updated_at, id) from public.transactions
  where (updated_at, id) > ($cursor_at, '$cursor_id'); commit;")
check "the next pull from that cursor returns both rows, push 1's first" "$pulled" "$first,$second"
later=$(query "select (select updated_at from public.transactions where id = '$second') > (select updated_at from public.transactions where id = '$first');")
check "push 2 is stamped after push 1" "$later" "t"

exit $((failures > 0))
