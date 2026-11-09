-- What the server stamps on a synced write (W11 T6, ADR-0036). Two sessions racing: supabase/tests/concurrency/commit_order.sh.
begin;
-- See synced_tables.test.sql: the CLI's temporary login role on a hosted project inherits nothing from postgres.
set local role postgres;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000000', 'a@pockit.test'),
  ('b0000000-0000-4000-8000-000000000000', 'b@pockit.test'),
  ('c0000000-0000-4000-8000-000000000000', 'c@pockit.test');

create function pg_temp.now_ms() returns bigint language sql as $$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $$;

create function pg_temp.holds_lock_of(p_owner uuid) returns boolean language sql as $$
  select exists (
    select 1 from pg_locks
    where locktype = 'advisory' and pid = pg_backend_pid() and granted
      and ((classid::bigint << 32) | objid::bigint) = hashtextextended('pockit.owner_writes:' || p_owner::text, 0)
  )
$$;

-- The client sends version 7 and updated_at 5; the server keeps neither.
insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at) values
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 5, 7, null);

select is((select version from public.accounts where id = 'a1000000-0000-4000-8000-000000000001'), 1::bigint,
  'an insert starts at version 1, whatever the client sent');
select ok((select updated_at between pg_temp.now_ms() - 60000 and pg_temp.now_ms() from public.accounts where id = 'a1000000-0000-4000-8000-000000000001'),
  'an insert is stamped with the server''s clock, not the client''s');
select is((select created_at from public.accounts where id = 'a1000000-0000-4000-8000-000000000001'), 1762560000000::bigint,
  'the client''s created_at is kept: an offline row was created when the user made it');

with before as (select updated_at, version from public.accounts where id = 'a1000000-0000-4000-8000-000000000001'),
  after as (update public.accounts set name = 'Pocket', version = 99, updated_at = 1 where id = 'a1000000-0000-4000-8000-000000000001' returning updated_at, version)
select ok(after.version = before.version + 1 and after.updated_at > before.updated_at,
  'an update moves version by one and updated_at forward, whatever the client sent') from before, after;

insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at) values
  ('a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'food', null, 'expense', null, null, true, 1762560000000, 1, 1, null);
insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note, created_at,
  updated_at, version, deleted_at) values
  ('a3000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'expense', 'a1000000-0000-4000-8000-000000000001', null,
   'a2000000-0000-4000-8000-000000000001', 50000, 'VND', 1762560000000, null, 1762560000000, 1, 1, null);

select ok(
  (select a.updated_at < c.updated_at and c.updated_at < t.updated_at
   from public.accounts a, public.categories c, public.transactions t
   where a.id = 'a1000000-0000-4000-8000-000000000001' and c.id = 'a2000000-0000-4000-8000-000000000001' and t.id = 'a3000000-0000-4000-8000-000000000001'),
  'one owner''s stamps rise strictly across all three tables, in write order, even within one millisecond'
);

-- A stamp in 2100 stands for a clock that has stepped back: the next one still lands after it.
alter table public.categories disable trigger categories_stamp_write;
update public.categories set updated_at = 4102444800000 where id = 'a2000000-0000-4000-8000-000000000001';
alter table public.categories enable trigger categories_stamp_write;

insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note, created_at,
  updated_at, version, deleted_at) values
  ('a3000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000000', 'income', 'a1000000-0000-4000-8000-000000000001', null, null, 1000, 'VND',
   1762560000000, null, 1762560000000, 1, 1, null);
select is((select updated_at from public.transactions where id = 'a3000000-0000-4000-8000-000000000002'), 4102444800001::bigint,
  'a stamp is never behind the owner''s newest, in any table, even with the clock behind it');

insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at) values
  ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1, 1, null);
select ok((select updated_at < 4102444800000 from public.accounts where id = 'b1000000-0000-4000-8000-000000000001'),
  'another owner''s newest does not move this one''s stamps');

update public.transactions set deleted_at = 1762560000001 where id = 'a3000000-0000-4000-8000-000000000001';
update public.transactions set deleted_at = null where id = 'a3000000-0000-4000-8000-000000000001';
select is((select version from public.transactions where id = 'a3000000-0000-4000-8000-000000000001'), 3::bigint,
  'a soft delete and its undo are writes like any other: version 3');
select ok(
  (select t1.updated_at > t2.updated_at from public.transactions t1, public.transactions t2
   where t1.id = 'a3000000-0000-4000-8000-000000000001' and t2.id = 'a3000000-0000-4000-8000-000000000002'),
  'the undo is stamped after the newest write, so a pull sees the row come back'
);

-- Columns the local domain never writes after insert.

select throws_ok($$update public.accounts set currency_code = 'USD' where id = 'a1000000-0000-4000-8000-000000000001'$$,
  '23514', 'accounts.currency_code never changes after insert', 'an account''s currency is fixed (ADR-0010)');
select throws_ok($$update public.accounts set created_at = 1 where id = 'a1000000-0000-4000-8000-000000000001'$$,
  '23514', 'accounts.created_at never changes after insert', 'created_at is fixed');
select throws_ok($$update public.accounts set id = gen_random_uuid() where id = 'a1000000-0000-4000-8000-000000000001'$$,
  '23514', 'accounts.id never changes after insert', 'id is fixed');
select throws_ok($$update public.accounts set owner_id = 'b0000000-0000-4000-8000-000000000000' where id = 'a1000000-0000-4000-8000-000000000001'$$,
  '23514', 'accounts.owner_id never changes after insert', 'owner_id is fixed, for the service role too, which RLS does not stop');
select throws_ok($$update public.categories set type = 'income' where id = 'a2000000-0000-4000-8000-000000000001'$$,
  '23514', 'categories.type never changes after insert', 'a category''s type is fixed (ADR-0010)');
select throws_ok($$update public.categories set name_key = 'drinks' where id = 'a2000000-0000-4000-8000-000000000001'$$,
  '23514', 'categories.name_key never changes after insert', 'a seeded category''s key is fixed: its id is derived from it (ADR-0002)');
select throws_ok($$update public.categories set is_system = false where id = 'a2000000-0000-4000-8000-000000000001'$$,
  '23514', 'categories.is_system never changes after insert', 'whether a category was seeded is fixed');
select throws_ok($$update public.transactions set created_at = 1 where id = 'a3000000-0000-4000-8000-000000000001'$$,
  '23514', 'transactions.created_at never changes after insert', 'a transaction''s created_at is fixed');

-- What the domain does edit stays editable, and a fixed column may be sent back unchanged.

select lives_ok(
  $$update public.accounts set name = 'Main', type = 'bank', initial_balance = 25000, is_archived = true where id = 'a1000000-0000-4000-8000-000000000001'$$,
  'an account''s name, type, opening balance and archive flag change');
select lives_ok(
  $$update public.categories set name = 'Eating out', icon_key = 'fork', color_key = 'red' where id = 'a2000000-0000-4000-8000-000000000001'$$,
  'a category''s name, icon and colour change');
select lives_ok(
  $$update public.transactions set amount_minor = 60000, occurred_at = 1762470000000, note = 'lunch', category_id = null
    where id = 'a3000000-0000-4000-8000-000000000001'$$,
  'a transaction''s amount, date, note and category change');
select lives_ok(
  $$update public.accounts set currency_code = 'VND', created_at = 1762560000000, owner_id = 'a0000000-0000-4000-8000-000000000000'
    where id = 'a1000000-0000-4000-8000-000000000001'$$,
  'a whole row sent back with its fixed columns unchanged passes'
);

-- The locks. The statement trigger takes the caller's before any row is touched; the row trigger takes the owner's for the service role.

select ok(pg_temp.holds_lock_of('b0000000-0000-4000-8000-000000000000'), 'a service-role write holds its owner''s lock until commit');
do $$ begin perform set_config('request.jwt.claims', '{"sub": "c0000000-0000-4000-8000-000000000000", "role": "authenticated"}', true); end $$;
set local role authenticated;
update public.accounts set name = 'none' where false;
set local role postgres;
select ok(pg_temp.holds_lock_of('c0000000-0000-4000-8000-000000000000'),
  'a signed-in caller''s statement takes their lock before any row: even one that matches no row holds it');

select ok(
  not has_schema_privilege('anon', 'private', 'usage') and not has_schema_privilege('authenticated', 'private', 'usage'),
  'the trigger functions are out of the Data API roles'' reach'
);

select * from finish();
rollback;
