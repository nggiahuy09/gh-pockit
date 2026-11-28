-- The push function (W14 T3, ADR-0046): one answer per mutation, a version check, one savepoint each, the owner from the token.
begin;
-- See synced_tables.test.sql: the CLI's temporary login role on a hosted project inherits nothing from postgres.
set local role postgres;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-000000000000', 'a@pockit.test'),
  ('b0000000-0000-4000-8000-000000000000', 'b@pockit.test');

-- B already has an account and a seeded category; A's device pushes the same seed id later.
insert into public.accounts (id, owner_id, name, type, currency_code, initial_balance, is_archived, created_at, updated_at, version, deleted_at) values
  ('b1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000000', 'Wallet', 'cash', 'VND', 0, false, 1762560000000, 1, 1, null);
insert into public.categories (id, owner_id, name_key, name, type, icon_key, color_key, is_system, created_at, updated_at, version, deleted_at) values
  ('a2000000-0000-4000-8000-0000000000f0', 'a0000000-0000-4000-8000-000000000000', 'category.food', null, 'expense', null, null, true, 1762560000000, 1, 1, null);

create function pg_temp.now_ms() returns bigint language sql as $$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $$;

create function pg_temp.envelope(p_mutation_id text, p_entity_type text, p_operation text, p_payload jsonb) returns jsonb language sql as $$
  select jsonb_build_object('mutation_id', p_mutation_id, 'entity_type', p_entity_type, 'entity_id', p_payload ->> 'id', 'operation', p_operation,
    'idempotency_key', 'key-' || p_mutation_id, 'payload', p_payload)
$$;

-- Whole rows, as the client's `toSyncPayload` sends them; `changes` overrides any column.
create function pg_temp.account(p_id text, changes jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'owner_id', 'a0000000-0000-4000-8000-000000000000', 'name', 'Wallet', 'type', 'cash', 'currency_code', 'VND',
    'initial_balance', 0, 'is_archived', false, 'created_at', 1762560000000, 'updated_at', 1762560000000, 'version', 1, 'deleted_at', null) || changes
$$;

create function pg_temp.category(p_id text, changes jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'owner_id', 'a0000000-0000-4000-8000-000000000000', 'name_key', null, 'name', 'Gym', 'type', 'expense',
    'icon_key', null, 'color_key', null, 'is_system', false, 'created_at', 1762560000000, 'updated_at', 1762560000000, 'version', 1, 'deleted_at', null)
    || changes
$$;

create function pg_temp.transaction(p_id text, p_account text, changes jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('id', p_id, 'owner_id', 'a0000000-0000-4000-8000-000000000000', 'type', 'expense', 'account_id', p_account,
    'destination_account_id', null, 'category_id', null, 'amount_minor', 125000, 'currency_code', 'VND', 'occurred_at', 1762560000000, 'note', 'rent',
    'created_at', 1762560000000, 'updated_at', 1762560000000, 'version', 1, 'deleted_at', null, 'sync_status', 'pending') || changes
$$;

create function pg_temp.holds_lock_of(p_owner uuid) returns boolean language sql as $$
  select exists (
    select 1 from pg_locks
    where locktype = 'advisory' and pid = pg_backend_pid() and granted
      and ((classid::bigint << 32) | objid::bigint) = hashtextextended('pockit.owner_writes:' || p_owner::text, 0)
  )
$$;

-- Each call's answer, written by the signed-in caller and read back as postgres.
create temp table pushed (call text primary key, answer jsonb);
grant insert, select on pushed to authenticated;

-- Who may call it.

select ok(has_function_privilege('authenticated', 'public.push_mutations(jsonb)', 'execute'), 'a signed-in user may push');
select ok(not has_function_privilege('anon', 'public.push_mutations(jsonb)', 'execute'), 'anon may not push');
select is((select prosecdef from pg_proc where oid = 'public.push_mutations(jsonb)'::regprocedure), false,
  'SECURITY INVOKER: RLS and the stamping triggers apply to every write');

set local role authenticated;
select throws_ok($$select public.push_mutations('[]')$$, '42501', null, 'a caller with no token is refused before anything is read');

select set_config('request.jwt.claims', '{"sub": "a0000000-0000-4000-8000-000000000000", "role": "authenticated"}', true);

select throws_ok($$select public.push_mutations('{}')$$, '22023', null, 'a batch that is not an array fails the whole call');
select throws_ok($$select public.push_mutations(jsonb_build_array(jsonb_build_object('entity_type', 'account')))$$, '22023', null,
  'a mutation with no id to answer by fails the whole call');
select throws_ok(
  $$select public.push_mutations((select jsonb_agg(pg_temp.envelope('m' || n, 'account', 'create', pg_temp.account(gen_random_uuid()::text))) from generate_series(1, 65) n))$$,
  '54000', null, 'a batch past 64 mutations fails the whole call, writing nothing');
select is(public.push_mutations('[]'), '[]'::jsonb, 'an empty batch answers an empty array');

-- Creates, parents first, in one batch.

insert into pushed select 'creates', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-acc', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000001', '{"version": 7, "updated_at": 5}')),
  pg_temp.envelope('m-cat', 'category', 'create', pg_temp.category('a2000000-0000-4000-8000-000000000001')),
  pg_temp.envelope('m-tx', 'transaction', 'create',
    pg_temp.transaction('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', '{"category_id": "a2000000-0000-4000-8000-000000000001"}'))
));
set local role postgres;

select is((select jsonb_agg(element -> 'status') from pushed, jsonb_array_elements(answer) element where call = 'creates'), '["applied", "applied", "applied"]'::jsonb,
  'a parent and its children in one batch are all applied, the parents first');
select is((select jsonb_agg(element ->> 'mutation_id') from pushed, jsonb_array_elements(answer) element where call = 'creates'), '["m-acc", "m-cat", "m-tx"]'::jsonb,
  'the answers come back in the batch''s order');
select ok(
  (select (answer -> 0 ->> 'server_version')::bigint = a.version and (answer -> 0 ->> 'server_updated_at')::bigint = a.updated_at
   from pushed, public.accounts a where call = 'creates' and a.id = 'a1000000-0000-4000-8000-000000000001'),
  'applied carries the stamps the row now holds'
);
select ok(
  (select version = 1 and updated_at between pg_temp.now_ms() - 60000 and pg_temp.now_ms() from public.accounts where id = 'a1000000-0000-4000-8000-000000000001'),
  'a create is stamped by the server: version 1 and its clock, not the 7 and 5 sent'
);
select ok(pg_temp.holds_lock_of('a0000000-0000-4000-8000-000000000000'), 'the push holds the caller''s write lock until commit');

-- Updates and the version check.

set local role authenticated;
insert into pushed select 'update', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-up', 'account', 'update', pg_temp.account('a1000000-0000-4000-8000-000000000001', '{"name": "Pocket", "version": 1}'))
));
insert into pushed select 'stale', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-stale', 'account', 'update', pg_temp.account('a1000000-0000-4000-8000-000000000001', '{"name": "Purse", "version": 1}'))
));
insert into pushed select 'fixed', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-fixed', 'account', 'update',
    pg_temp.account('a1000000-0000-4000-8000-000000000001', '{"version": 2, "currency_code": "USD", "created_at": 1, "is_archived": true}'))
));
insert into pushed select 'missing', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-missing', 'account', 'update', pg_temp.account('a1000000-0000-4000-8000-00000000dead'))
));
insert into pushed select 'theirs', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-theirs', 'account', 'update', pg_temp.account('b1000000-0000-4000-8000-000000000001', '{"name": "Mine now"}'))
));
set local role postgres;

select is((select answer -> 0 ->> 'status' || ' ' || (answer -> 0 ->> 'server_version') from pushed where call = 'update'), 'applied 2',
  'an update at the server''s version is applied and moves it by one');
select is((select answer -> 0 ->> 'status' from pushed where call = 'stale'), 'conflict', 'an update at an older version conflicts');
select ok(
  (select answer -> 0 -> 'remote' ->> 'name' = 'Pocket' and (answer -> 0 -> 'remote' ->> 'version')::int = 2
     and answer -> 0 -> 'remote' ->> 'owner_id' = 'a0000000-0000-4000-8000-000000000000'
   from pushed where call = 'stale'),
  'a conflict carries the server''s whole row, so both sides can be shown'
);
select ok(
  (select a.currency_code = 'VND' and a.created_at = 1762560000000 and a.is_archived and p.answer -> 0 ->> 'status' = 'applied'
   from public.accounts a, pushed p where a.id = 'a1000000-0000-4000-8000-000000000001' and p.call = 'fixed'),
  'an update writes only what toPatch writes: the fixed columns keep the server''s value'
);
select is((select answer -> 0 ->> 'code' from pushed where call = 'missing'), 'not_found', 'an update of a row the server lacks is rejected as not_found');
select ok(
  (select p.answer -> 0 ->> 'code' = 'not_found' and a.name = 'Wallet'
   from pushed p, public.accounts a where p.call = 'theirs' and a.id = 'b1000000-0000-4000-8000-000000000001'),
  'another owner''s id is not found under the caller, and their row is untouched'
);

-- A create whose row is already there.

set local role authenticated;
insert into pushed select 'seed', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-seed', 'category', 'create',
    pg_temp.category('a2000000-0000-4000-8000-0000000000f0', '{"name_key": "category.food", "name": null, "is_system": true, "created_at": 1764000000000}'))
));
insert into pushed select 'retry', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-cat', 'category', 'create', pg_temp.category('a2000000-0000-4000-8000-000000000001'))
));
insert into pushed select 'late-create', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-late', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000001'))
));
set local role postgres;

select ok(
  (select p.answer -> 0 ->> 'status' = 'applied' and c.created_at = 1762560000000 and c.version = 2
   from pushed p, public.categories c where p.call = 'seed' and c.id = 'a2000000-0000-4000-8000-0000000000f0'),
  'a seed another device pushed first is applied, not duplicated, and keeps the first created_at'
);
select is((select answer -> 0 ->> 'status' || ' ' || (answer -> 0 ->> 'server_version') from pushed where call = 'retry'), 'applied 2',
  'a create resent after a lost answer is applied again, not refused on its key');
select is((select answer -> 0 ->> 'status' from pushed where call = 'late-create'), 'conflict',
  'a create whose row has moved on since conflicts instead of overwriting it');

-- One mutation refused, the rest of the batch kept.

set local role authenticated;
insert into pushed select 'mixed', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-orphan', 'transaction', 'create', pg_temp.transaction('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-00000000beef')),
  pg_temp.envelope('m-ok', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000002')),
  pg_temp.envelope('m-transfer', 'transaction', 'create', pg_temp.transaction('a3000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000002',
    '{"type": "transfer"}')),
  pg_temp.envelope('m-noname', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000003', '{"name": null}')),
  pg_temp.envelope('m-badtype', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000004', '{"type": "piggy"}')),
  pg_temp.envelope('m-text', 'transaction', 'create', pg_temp.transaction('a3000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000002',
    '{"amount_minor": "lots"}'))
));
set local role postgres;

select is((select answer -> 0 ->> 'code' from pushed where call = 'mixed'), 'transactions_account_id_owner_id_fkey',
  'a child whose parent the server lacks is rejected with the foreign key''s name');
select ok(
  (select answer -> 1 ->> 'status' = 'applied' from pushed where call = 'mixed')
    and exists (select 1 from public.accounts where id = 'a1000000-0000-4000-8000-000000000002'),
  'a refused mutation rolls back only itself: the next one in the batch is written'
);
select is((select answer -> 2 ->> 'code' from pushed where call = 'mixed'), 'transactions_destination_iff_transfer', 'a check is rejected by its name');
select is((select answer -> 3 ->> 'code' from pushed where call = 'mixed'), 'accounts_name_not_null', 'a missing column is rejected as table_column_not_null');
select is((select answer -> 4 ->> 'code' from pushed where call = 'mixed'), 'accounts_type_check', 'an unknown vocabulary value is rejected by its check');
select is((select answer -> 5 ->> 'code' from pushed where call = 'mixed'), 'invalid_payload', 'a value of the wrong type is rejected as invalid_payload');
select ok(not exists (select 1 from public.transactions where id in ('a3000000-0000-4000-8000-000000000002', 'a3000000-0000-4000-8000-000000000003',
  'a3000000-0000-4000-8000-000000000004')), 'no refused mutation left a row behind');

-- The envelope.

set local role authenticated;
insert into pushed select 'envelope', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-type', 'budget', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000005')),
  pg_temp.envelope('m-op', 'account', 'upsert', pg_temp.account('a1000000-0000-4000-8000-000000000005')),
  pg_temp.envelope('m-id', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000005')) || '{"entity_id": "a1000000-0000-4000-8000-000000000006"}',
  pg_temp.envelope('m-owner', 'account', 'create', pg_temp.account('a1000000-0000-4000-8000-000000000005', '{"owner_id": "b0000000-0000-4000-8000-000000000000"}')),
  pg_temp.envelope('m-del', 'account', 'delete', pg_temp.account('a1000000-0000-4000-8000-000000000002')),
  pg_temp.envelope('m-ver', 'account', 'update', pg_temp.account('a1000000-0000-4000-8000-000000000002', '{"version": 1.5}'))
));
set local role postgres;

select is(
  (select jsonb_agg(element -> 'code') from pushed, jsonb_array_elements(answer) element where call = 'envelope'),
  '["unknown_entity_type", "unknown_operation", "invalid_payload", "owner_mismatch", "invalid_payload", "invalid_payload"]'::jsonb,
  'an unknown type or operation, an entity id that is not the payload''s, another owner, a delete with no tombstone, a fractional version'
);
select ok(not exists (select 1 from public.accounts where id = 'a1000000-0000-4000-8000-000000000005'), 'nothing in a refused envelope is written, under any owner');

-- A delete is an update carrying the tombstone.

set local role authenticated;
insert into pushed select 'delete', public.push_mutations(jsonb_build_array(
  pg_temp.envelope('m-delete', 'account', 'delete', pg_temp.account('a1000000-0000-4000-8000-000000000002', '{"deleted_at": 1764300000000}'))
));
set local role postgres;

select ok(
  (select p.answer -> 0 ->> 'status' = 'applied' and a.deleted_at = 1764300000000 and a.version = 2
   from pushed p, public.accounts a where p.call = 'delete' and a.id = 'a1000000-0000-4000-8000-000000000002'),
  'a delete soft-deletes the row and is stamped like any update'
);
select is((select count(*) from public.accounts where id = 'a1000000-0000-4000-8000-000000000002'), 1::bigint, 'the tombstone stays: nothing is hard-deleted');

select ok(
  (select bool_and(jsonb_typeof(value) in ('string', 'number', 'boolean', 'null')) from pushed, jsonb_each(answer -> 0 -> 'remote') where call = 'stale'),
  'the remote row is flat, as the client''s decoder requires'
);

select * from finish();
rollback;
