-- Who may read and write the synced tables (W11 T4, ADR-0034): an owner, their own rows, through the Data API roles.
begin;
-- See synced_tables.test.sql: the CLI's temporary login role on a hosted project inherits nothing from postgres.
set local role postgres;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(29);

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000000', 'a@pockit.test'),
  ('b0000000-0000-4000-8000-000000000000', 'b@pockit.test');

insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at) values
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1762560000000, 1, null),
  ('a1000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000000', 'Savings', 'bank', 'VND', 0, false, 1762560000000, 1762560000000, 1, null),
  ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1762560000000, 1, null);

insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at) values
  ('a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'food', null, 'expense', null, null, true, 1762560000000, 1762560000000, 1, null),
  ('b2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', null, 'Gym', 'expense', null, null, false, 1762560000000, 1762560000000, 1, null);

insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note, created_at,
  updated_at, version, deleted_at) values
  ('a3000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'expense', 'a1000000-0000-4000-8000-000000000001', null,
   'a2000000-0000-4000-8000-000000000001', 50000, 'VND', 1762560000000, null, 1762560000000, 1762560000000, 1, null),
  ('a3000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000000', 'expense', 'a1000000-0000-4000-8000-000000000001', null, null, 20000,
   'VND', 1762560000000, null, 1762560000000, 1762560000001, 2, 1762560000001),
  ('b3000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', 'expense', 'b1000000-0000-4000-8000-000000000001', null, null, 70000,
   'VND', 1762560000000, null, 1762560000000, 1762560000000, 1, null);

-- What each role holds. Checked over every table in `public`, so a later table that keeps Supabase's default grants fails here.

select is_empty(
  $$select table_name, privilege_type from information_schema.role_table_grants where table_schema = 'public' and grantee = 'anon'$$,
  'anon holds no privilege on any table'
);
select is_empty(
  $$select table_name, privilege_type from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated' and privilege_type not in ('SELECT', 'INSERT', 'UPDATE')$$,
  'authenticated holds no DELETE, TRUNCATE, REFERENCES or TRIGGER on any table'
);
select results_eq(
  $$select table_name::text collate "default", privilege_type::text collate "default" from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated' order by 1, 2$$,
  $$values ('accounts', 'INSERT'), ('accounts', 'SELECT'), ('accounts', 'UPDATE'), ('categories', 'INSERT'), ('categories', 'SELECT'), ('categories', 'UPDATE'),
           ('transactions', 'INSERT'), ('transactions', 'SELECT'), ('transactions', 'UPDATE')$$,
  'authenticated may select, insert and update the three synced tables'
);
select results_eq(
  $$select tablename::text collate "default", cmd::text collate "default", roles::text collate "default" from pg_policies where schemaname = 'public' order by 1, 2$$,
  $$values ('accounts', 'INSERT', '{authenticated}'), ('accounts', 'SELECT', '{authenticated}'), ('accounts', 'UPDATE', '{authenticated}'),
           ('categories', 'INSERT', '{authenticated}'), ('categories', 'SELECT', '{authenticated}'), ('categories', 'UPDATE', '{authenticated}'),
           ('transactions', 'INSERT', '{authenticated}'), ('transactions', 'SELECT', '{authenticated}'), ('transactions', 'UPDATE', '{authenticated}')$$,
  'one select, insert and update policy per table, for authenticated only; no delete policy'
);
select results_eq(
  $$select conrelid::regclass::text, pg_get_constraintdef(oid) from pg_constraint
    where contype = 'p' and conrelid in ('public.accounts'::regclass, 'public.categories'::regclass, 'public.transactions'::regclass) order by 1$$,
  $$values ('accounts', 'PRIMARY KEY (owner_id, id)'), ('categories', 'PRIMARY KEY (owner_id, id)'), ('transactions', 'PRIMARY KEY (owner_id, id)')$$,
  'an id is unique per owner'
);

-- Signed in as A.

do $$ begin perform set_config('request.jwt.claims', '{"sub": "a0000000-0000-4000-8000-000000000000", "role": "authenticated"}', true); end $$;
set local role authenticated;

select results_eq($$select id from public.accounts order by id$$,
  $$values ('a1000000-0000-4000-8000-000000000001'::uuid), ('a1000000-0000-4000-8000-000000000002'::uuid)$$, 'A reads their own accounts and only those');
select results_eq($$select id from public.categories order by id$$,
  $$values ('a2000000-0000-4000-8000-000000000001'::uuid)$$, 'A reads their own categories and only those');
select results_eq($$select id from public.transactions order by id$$,
  $$values ('a3000000-0000-4000-8000-000000000001'::uuid), ('a3000000-0000-4000-8000-000000000002'::uuid)$$,
  'A reads their own transactions, the tombstone included, and only those');
select is_empty($$select * from public.accounts where id = 'b1000000-0000-4000-8000-000000000001'$$, 'A asking for B''s account by id gets nothing');
select is_empty($$select * from public.categories where id = 'b2000000-0000-4000-8000-000000000001'$$, 'A asking for B''s category by id gets nothing');
select is_empty($$select * from public.transactions where id = 'b3000000-0000-4000-8000-000000000001'$$, 'A asking for B''s transaction by id gets nothing');

select lives_ok(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values ('a1000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000000', 'Card', 'credit_card', 'VND', 0, false, 1, 1, 1, null)$$,
  'A inserts an account of their own'
);
select throws_ok(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000000', 'Planted', 'cash', 'VND', 0, false, 1, 1, 1, null)$$,
  '42501', 'new row violates row-level security policy for table "accounts"', 'A cannot insert an account in B''s name'
);
select throws_ok(
  $$insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note,
      created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000000', 'expense', 'b1000000-0000-4000-8000-000000000001', null, null, 1000, 'VND', 1, null,
      1, 1, 1, null)$$,
  '42501', 'new row violates row-level security policy for table "transactions"', 'A cannot insert a transaction in B''s name, on B''s account'
);
with updated as (update public.accounts set name = 'Pocket', updated_at = 2 where id = 'a1000000-0000-4000-8000-000000000001' returning 1)
select is(count(*), 1::bigint, 'A updates their own account') from updated;
with updated as (update public.accounts set name = 'Hijacked', updated_at = 2 where id = 'b1000000-0000-4000-8000-000000000001' returning 1)
select is(count(*), 0::bigint, 'A updating B''s account touches no row') from updated;
select throws_ok(
  $$update public.accounts set owner_id = 'b0000000-0000-4000-8000-000000000000' where id = 'a1000000-0000-4000-8000-000000000002'$$,
  '23514', 'accounts.owner_id never changes after insert', 'A cannot hand their account to B: the fixed-column trigger refuses it before RLS'
);
with restored as (update public.transactions set deleted_at = null, updated_at = 3 where id = 'a3000000-0000-4000-8000-000000000002' returning 1)
select is(count(*), 1::bigint, 'A restores their own tombstone: an undo (ADR-0017)') from restored;
select throws_ok($$delete from public.transactions where id = 'a3000000-0000-4000-8000-000000000001'$$,
  '42501', 'permission denied for table transactions', 'A cannot hard-delete even their own transaction (ADR-0031)');
select throws_ok($$truncate public.transactions$$, '42501', 'permission denied for table transactions', 'A cannot truncate, which RLS would not stop');
select lives_ok(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values ('b2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', null, 'Squat', 'expense', null, null, false, 1, 1, 1, null)$$,
  'A using B''s category id gets a row of their own: no 23505 tells A that the id exists'
);
select throws_ok(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'Twin', 'cash', 'VND', 0, false, 1, 1, 1, null)$$,
  '23505', null, 'an id is still unique within one owner'
);

-- A token with no subject, and no token at all.

do $$ begin perform set_config('request.jwt.claims', '{"role": "authenticated"}', true); end $$;
select is((select count(*) from public.accounts), 0::bigint, 'a token with no subject reads nothing');
set local role postgres;
set local role anon;
select throws_ok($$select * from public.accounts$$, '42501', 'permission denied for table accounts', 'anon cannot even query');
set local role postgres;

-- Signed in as B, after everything A tried.

do $$ begin perform set_config('request.jwt.claims', '{"sub": "b0000000-0000-4000-8000-000000000000", "role": "authenticated"}', true); end $$;
set local role authenticated;

select results_eq($$select id, name from public.accounts order by id$$,
  $$values ('b1000000-0000-4000-8000-000000000001'::uuid, 'Wallet')$$, 'B reads only their own account, unchanged, and none of A''s');
select results_eq($$select owner_id, name from public.categories where id = 'b2000000-0000-4000-8000-000000000001'$$,
  $$values ('b0000000-0000-4000-8000-000000000000'::uuid, 'Gym')$$, 'B sees one row under their category id, their own, not A''s');
with updated as (update public.categories set name = 'Gym & Pool', updated_at = 2 where id = 'b2000000-0000-4000-8000-000000000001' returning 1)
select is(count(*), 1::bigint, 'B still writes their category after A took the same id') from updated;
set local role postgres;

-- What actually landed.

select results_eq(
  $$select id, name from public.accounts where id in ('a1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001') order by id$$,
  $$values ('a1000000-0000-4000-8000-000000000001'::uuid, 'Pocket'), ('b1000000-0000-4000-8000-000000000001'::uuid, 'Wallet')$$,
  'A''s own update landed; the one on B''s account did not'
);
select results_eq(
  $$select id, deleted_at from public.transactions where owner_id = 'a0000000-0000-4000-8000-000000000000' order by id$$,
  $$values ('a3000000-0000-4000-8000-000000000001'::uuid, null::bigint), ('a3000000-0000-4000-8000-000000000002'::uuid, null::bigint)$$,
  'the refused delete left the row, and the restore cleared the tombstone'
);

select * from finish();
rollback;
