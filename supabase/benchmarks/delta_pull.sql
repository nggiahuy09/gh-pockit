-- The delta pull at 50k transactions per owner, ten owners in one table (ADR-0035). One transaction, rolled back: nothing stays.
--   docker exec -i supabase_db_gh-pockit psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f - < supabase/benchmarks/delta_pull.sql
-- Each query runs three times; read the last, warm, run.
\set owner '''be000000-0000-4000-8000-000000000001'''
begin;

insert into auth.users (id, email)
select ('be000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'bench' || g || '@pockit.test' from generate_series(1, 10) g;

insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
select ('bf000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, ('be000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'Wallet', 'cash', 'VND',
  0, false, 1700000000000, 1700000000000, 1, null
from generate_series(1, 10) g;

-- 24 months of history per owner; a row is last changed within a day of its date.
insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note,
  created_at, updated_at, version, deleted_at)
select gen_random_uuid(), ('be000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'expense',
  ('bf000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, null, null, 1 + (random() * 1000000)::bigint, 'VND', t, null, t,
  t + (random() * 86400000)::bigint, 1, null
from generate_series(1, 10) g, lateral (select 1700000000000 + (random() * 63072000000)::bigint as t from generate_series(1, 50000)) s;

analyze public.accounts;
analyze public.transactions;

-- The cursor an up-to-date device holds: ten changes behind the newest.
select updated_at as cursor_at, id as cursor_id from public.transactions where owner_id = :owner order by updated_at desc, id desc offset 10 limit 1 \gset

select set_config('request.jwt.claims', '{"sub": "be000000-0000-4000-8000-000000000001", "role": "authenticated"}', true) \g /dev/null

\echo '== with the index =='
set local role authenticated;
\echo '-- first page, from an empty cursor'
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200;
\echo '-- incremental, ten changes since the cursor'
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200;

\echo '== without it =='
set local role postgres;
drop index public.transactions_owner_id_updated_at_id;
set local role authenticated;
\echo '-- first page, from an empty cursor'
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200;
\echo '-- incremental, ten changes since the cursor'
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200 \g /dev/null
explain (analyze, buffers, costs off) select * from public.transactions where (updated_at, id) > (:cursor_at, :'cursor_id') order by updated_at, id limit 200;

rollback;
