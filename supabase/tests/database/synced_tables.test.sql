-- The server copy of the synced tables (W11 T3, ADR-0033): its shape and its constraints. Who may read and write them: owner_access.test.sql.
begin;
-- On a hosted project the CLI logs in as a temporary role that inherits nothing from postgres, and SET ROLE loads no role's
-- search_path: both are set here, and `reset role` would go back to the temporary role.
set local role postgres;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(31);

-- Fixed ids keep a failure readable: a… is user A's, b… user B's.
insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000000', 'a@pockit.test'),
  ('b0000000-0000-4000-8000-000000000000', 'b@pockit.test');

insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at) values
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1762560000000, 1, null),
  ('a1000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000000', 'Bank', 'bank', 'VND', -5000000, false, 1762560000000, 1762560000000, 1, null),
  ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1762560000000, 1, null);

insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at) values
  ('a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000000', 'food', null, 'expense', null, null, true, 1762560000000, 1762560000000, 1, null),
  ('a2000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000000', null, 'Cafe', 'expense', 'coffee', 'amber', false, 1762560000000, 1762560000000, 1, null),
  ('a2000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000000', null, 'Old', 'expense', null, null, false, 1762560000000, 1762560000000, 2, 1762560000001),
  ('b2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', null, 'Gym', 'expense', null, null, false, 1762560000000, 1762560000000, 1, null);

create function pg_temp.add_transaction(
  p_type text,
  p_account_id uuid,
  p_destination_account_id uuid default null,
  p_category_id uuid default null,
  p_amount_minor bigint default 1000,
  p_owner_id uuid default 'a0000000-0000-4000-8000-000000000000'
) returns void language sql as $sql$
  insert into public.transactions (id, owner_id, type, account_id, destination_account_id, category_id, amount_minor, currency_code, occurred_at, note,
    created_at, updated_at, version, deleted_at)
  values (gen_random_uuid(), p_owner_id, p_type, p_account_id, p_destination_account_id, p_category_id, p_amount_minor, 'VND', 1762560000000, null,
    1762560000000, 1762560000000, 1, null);
$sql$;

-- Shape: every column, its type and nullability, in order. The server's counterpart of `migrateAndValidate`.

select results_eq(
  $$select column_name::text collate "default", data_type::text collate "default", is_nullable::text collate "default" from information_schema.columns
    where table_schema = 'public' and table_name = 'accounts' order by ordinal_position$$,
  $$values ('id', 'uuid', 'NO'), ('owner_id', 'uuid', 'NO'), ('name', 'text', 'NO'), ('type', 'text', 'NO'), ('currency_code', 'text', 'NO'),
           ('initial_balance', 'bigint', 'NO'), ('is_archived', 'boolean', 'NO'), ('created_at', 'bigint', 'NO'), ('updated_at', 'bigint', 'NO'),
           ('version', 'bigint', 'NO'), ('deleted_at', 'bigint', 'YES')$$,
  'accounts: columns, types and nullability mirror the local table'
);

select results_eq(
  $$select column_name::text collate "default", data_type::text collate "default", is_nullable::text collate "default" from information_schema.columns
    where table_schema = 'public' and table_name = 'categories' order by ordinal_position$$,
  $$values ('id', 'uuid', 'NO'), ('owner_id', 'uuid', 'NO'), ('name_key', 'text', 'YES'), ('name', 'text', 'YES'), ('type', 'text', 'NO'),
           ('icon_key', 'text', 'YES'), ('color_key', 'text', 'YES'), ('is_system', 'boolean', 'NO'), ('created_at', 'bigint', 'NO'),
           ('updated_at', 'bigint', 'NO'), ('version', 'bigint', 'NO'), ('deleted_at', 'bigint', 'YES')$$,
  'categories: columns, types and nullability mirror the local table'
);

select results_eq(
  $$select column_name::text collate "default", data_type::text collate "default", is_nullable::text collate "default" from information_schema.columns
    where table_schema = 'public' and table_name = 'transactions' order by ordinal_position$$,
  $$values ('id', 'uuid', 'NO'), ('owner_id', 'uuid', 'NO'), ('type', 'text', 'NO'), ('account_id', 'uuid', 'NO'), ('destination_account_id', 'uuid', 'YES'),
           ('category_id', 'uuid', 'YES'), ('amount_minor', 'bigint', 'NO'), ('currency_code', 'text', 'NO'), ('occurred_at', 'bigint', 'NO'),
           ('note', 'text', 'YES'), ('created_at', 'bigint', 'NO'), ('updated_at', 'bigint', 'NO'), ('version', 'bigint', 'NO'), ('deleted_at', 'bigint', 'YES')$$,
  'transactions: columns, types and nullability mirror the local table, without sync_status'
);

select is_empty(
  $$select table_name, column_name from information_schema.columns
    where table_schema = 'public' and table_name in ('accounts', 'categories', 'transactions') and column_default is not null$$,
  'no column has a default'
);

select results_eq(
  $$select relname::text collate "default", relrowsecurity from pg_class
    where oid in ('public.accounts'::regclass, 'public.categories'::regclass, 'public.transactions'::regclass) order by relname$$,
  $$values ('accounts', true), ('categories', true), ('transactions', true)$$,
  'row level security is on for all three tables'
);

-- Rows the local schema accepts.

select lives_ok($$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_category_id => 'a2000000-0000-4000-8000-000000000001')$$,
  'an expense with a category of its owner');
select lives_ok($$select pg_temp.add_transaction('income', 'a1000000-0000-4000-8000-000000000002', p_amount_minor => 1000000000000000)$$,
  'an income past 32 bits, with no category');
select lives_ok($$select pg_temp.add_transaction('transfer', 'a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000002')$$,
  'a transfer between two accounts of its owner');
select lives_ok($$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_category_id => 'a2000000-0000-4000-8000-000000000003')$$,
  'an expense in a soft-deleted category (ADR-0010)');
select lives_ok(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values ('a2000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000000', null, 'Books', 'expense', null, null, false, 1762560000000, 1762560000000, 1, null)$$,
  'a second user-made category of one owner: NULL name_keys never collide'
);
select lives_ok(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values ('b2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000000', 'food', null, 'expense', null, null, true, 1762560000000, 1762560000000, 1, null)$$,
  'another owner seeds the same name_key'
);

-- Owners.

select throws_ok(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'local', 'Wallet', 'cash', 'VND', 0, false, 1, 1, 1, null)$$,
  '22P02', null, 'the local sentinel owner never reaches the server'
);
select throws_like(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'c0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1, 1, 1, null)$$,
  '%"accounts_owner_id_fkey"%', 'an owner must be a user'
);

-- Vocabulary and value checks.

select throws_like(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', 'Jar', 'savings', 'VND', 0, false, 1, 1, 1, null)$$,
  '%"accounts_type_check"%', 'an account type outside the vocabulary'
);
select throws_like(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'vnd', 0, false, 1, 1, 1, null)$$,
  '%"accounts_currency_code_check"%', 'a lowercase currency code'
);
select throws_like(
  $$insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VN', 0, false, 1, 1, 1, null)$$,
  '%"accounts_currency_code_check"%', 'a two-letter currency code'
);
select throws_like(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', null, 'Moves', 'transfer', null, null, false, 1, 1, 1, null)$$,
  '%"categories_type_check"%', 'a category of type transfer'
);
select throws_like(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', null, null, 'expense', null, null, false, 1, 1, 1, null)$$,
  '%"categories_name_or_name_key"%', 'a category with neither name nor name_key'
);
select throws_like(
  $$insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at)
    values (gen_random_uuid(), 'a0000000-0000-4000-8000-000000000000', 'food', null, 'expense', null, null, true, 1, 1, 1, null)$$,
  '%"categories_owner_id_name_key_key"%', 'one owner seeding a name_key twice'
);
select throws_like($$select pg_temp.add_transaction('refund', 'a1000000-0000-4000-8000-000000000001')$$,
  '%"transactions_type_check"%', 'a transaction type outside the vocabulary');
select throws_like($$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_amount_minor => 0)$$,
  '%"transactions_amount_minor_check"%', 'a zero amount');
select throws_like($$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_amount_minor => -1000)$$,
  '%"transactions_amount_minor_check"%', 'a negative amount: the type carries the direction');

-- Transfer rules (ADR-0009).

select throws_like($$select pg_temp.add_transaction('transfer', 'a1000000-0000-4000-8000-000000000001')$$,
  '%"transactions_destination_iff_transfer"%', 'a transfer without a destination');
select throws_like($$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000002')$$,
  '%"transactions_destination_iff_transfer"%', 'an expense with a destination');
select throws_like($$select pg_temp.add_transaction('transfer', 'a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001')$$,
  '%"transactions_destination_not_source"%', 'a transfer into its own account');
select throws_like(
  $$select pg_temp.add_transaction('transfer', 'a1000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001')$$,
  '%"transactions_transfer_without_category"%', 'a transfer with a category'
);

-- Another owner's parent: a plain foreign key would take these, since its check bypasses RLS.

select throws_like($$select pg_temp.add_transaction('expense', 'b1000000-0000-4000-8000-000000000001')$$,
  '%"transactions_account_id_owner_id_fkey"%', 'a transaction on another owner''s account');
select throws_like($$select pg_temp.add_transaction('transfer', 'a1000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001')$$,
  '%"transactions_destination_account_id_owner_id_fkey"%', 'a transfer into another owner''s account');
select throws_like(
  $$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_category_id => 'b2000000-0000-4000-8000-000000000001')$$,
  '%"transactions_category_id_owner_id_fkey"%', 'an expense in another owner''s category'
);
select throws_like(
  $$select pg_temp.add_transaction('expense', 'a1000000-0000-4000-8000-000000000001', p_owner_id => 'b0000000-0000-4000-8000-000000000000')$$,
  '%"transactions_account_id_owner_id_fkey"%', 'a row claiming another owner while pointing at the first owner''s account'
);

-- Deleting a user takes their rows along, children and parents in one statement, and nobody else's.

delete from auth.users where id = 'a0000000-0000-4000-8000-000000000000';
select results_eq(
  $$select (select count(*) from public.accounts where owner_id = 'a0000000-0000-4000-8000-000000000000'),
           (select count(*) from public.categories where owner_id = 'a0000000-0000-4000-8000-000000000000'),
           (select count(*) from public.transactions where owner_id = 'a0000000-0000-4000-8000-000000000000'),
           (select count(*) from public.accounts where owner_id = 'b0000000-0000-4000-8000-000000000000'),
           (select count(*) from public.categories where owner_id = 'b0000000-0000-4000-8000-000000000000')$$,
  $$values (0::bigint, 0::bigint, 0::bigint, 1::bigint, 2::bigint)$$,
  'a deleted user''s accounts, categories and transactions go with them; another user''s stay'
);

select * from finish();
rollback;
