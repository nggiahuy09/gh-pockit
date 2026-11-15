-- The delta pull's indexes (W11 T5, ADR-0035): the query W15 will run, as the Data API runs it, is one index scan per table.
begin;
-- See synced_tables.test.sql: the CLI's temporary login role on a hosted project inherits nothing from postgres.
set local role postgres;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- With seq scans, bitmap scans and sorts priced out, the planner shows whether the index can carry the whole query: the owner, the
-- cursor and the order. Returns the plan itself when it cannot, so a failure prints it.
create function pg_temp.pull_plan_verdict(p_table text) returns text language plpgsql as $f$
declare
  line text;
  plan text := '';
begin
  perform set_config('enable_seqscan', 'off', true);
  perform set_config('enable_bitmapscan', 'off', true);
  perform set_config('enable_sort', 'off', true);
  for line in execute format(
    $q$explain (costs off) select * from public.%I where (updated_at, id) > (0, '00000000-0000-0000-0000-000000000000') order by updated_at, id limit 200$q$,
    p_table)
  loop
    plan := plan || line || E'\n';
  end loop;
  if plan like format('%%Index Scan using %s_owner_id_updated_at_id %%', p_table)
    and plan like '%Index Cond: ((owner_id = %'
    and plan like '%ROW(updated_at, id) > ROW(%'
    and plan not like '%Sort%'
  then
    return 'one index scan, no sort';
  end if;
  return plan;
end
$f$;

select results_eq(
  $$select indexname::text collate "default", indexdef from pg_indexes where schemaname = 'public' and indexname like '%\_owner\_id\_updated\_at\_id' order by 1$$,
  $$values ('accounts_owner_id_updated_at_id', 'CREATE INDEX accounts_owner_id_updated_at_id ON public.accounts USING btree (owner_id, updated_at, id)'),
           ('categories_owner_id_updated_at_id', 'CREATE INDEX categories_owner_id_updated_at_id ON public.categories USING btree (owner_id, updated_at, id)'),
           ('transactions_owner_id_updated_at_id', 'CREATE INDEX transactions_owner_id_updated_at_id ON public.transactions USING btree (owner_id, updated_at, id)')$$,
  'each synced table has its delta-pull index, ending in id'
);

-- As the Data API runs it: RLS supplies `owner_id = (select auth.uid())`, which must land in the index condition.
do $$ begin perform set_config('request.jwt.claims', '{"sub": "a0000000-0000-4000-8000-000000000000", "role": "authenticated"}', true); end $$;
set local role authenticated;

select is(pg_temp.pull_plan_verdict('transactions'), 'one index scan, no sort', 'transactions: owner, cursor and order from the index alone');
select is(pg_temp.pull_plan_verdict('accounts'), 'one index scan, no sort', 'accounts: owner, cursor and order from the index alone');
select is(pg_temp.pull_plan_verdict('categories'), 'one index scan, no sort', 'categories: owner, cursor and order from the index alone');

set local role postgres;

select * from finish();
rollback;
