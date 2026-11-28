-- The push (ADR-0046): one call per batch, one answer per mutation, in the batch's order. SECURITY INVOKER, so RLS (ADR-0034) and the
-- stamping triggers (ADR-0036) apply to every write, and the owner is the token's, never the payload's. One function body: the caller has
-- no usage on `private`, so a helper there could not be called from here.
create function public.push_mutations(mutations jsonb) returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  item jsonb;
  mutation_id text;
  entity_type text;
  operation text;
  payload jsonb;
  base bigint;
  applied_version bigint;
  applied_at bigint;
  remote jsonb;
  failed_constraint text;
  failed_table text;
  failed_column text;
  failed_state text;
  results jsonb := '[]'::jsonb;
begin
  if caller is null then
    raise exception using errcode = 'insufficient_privilege', message = 'push_mutations needs a signed-in caller';
  end if;
  if jsonb_typeof(mutations) is distinct from 'array' then
    raise exception using errcode = 'invalid_parameter_value', message = 'mutations must be a JSON array';
  end if;
  -- One savepoint per mutation; past 64 in one transaction Postgres overflows its subtransaction cache, which slows every snapshot.
  if jsonb_array_length(mutations) > 64 then
    raise exception using errcode = 'program_limit_exceeded', message = 'a push carries at most 64 mutations';
  end if;

  -- The statement triggers take it anyway; taking it first means the whole batch commits as one step of the owner's order (ADR-0036).
  perform pg_advisory_xact_lock(hashtextextended('pockit.owner_writes:' || caller::text, 0));

  for item in select element from jsonb_array_elements(mutations) with ordinality as batch(element, position) order by position loop
    -- An answer needs an id to carry: without one the batch is malformed, not this mutation.
    if jsonb_typeof(item -> 'mutation_id') is distinct from 'string' or item ->> 'mutation_id' = '' then
      raise exception using errcode = 'invalid_parameter_value', message = 'every mutation needs a mutation_id';
    end if;
    mutation_id := item ->> 'mutation_id';
    entity_type := item ->> 'entity_type';
    operation := item ->> 'operation';
    payload := item -> 'payload';

    if entity_type is null or entity_type not in ('account', 'category', 'transaction') then
      results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'unknown_entity_type'));
      continue;
    end if;
    if operation is null or operation not in ('create', 'update', 'delete') then
      results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'unknown_operation'));
      continue;
    end if;
    if jsonb_typeof(payload) is distinct from 'object'
      or payload ->> 'id' is distinct from item ->> 'entity_id'
      or jsonb_typeof(payload -> 'version') is distinct from 'number'
      or (operation = 'delete' and jsonb_typeof(payload -> 'deleted_at') is distinct from 'number') then
      results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'invalid_payload'));
      continue;
    end if;
    -- Refused rather than rewritten: a payload naming someone else is a client bug, and no write may land under a guessed owner.
    if payload ->> 'owner_id' is distinct from caller::text then
      results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'owner_mismatch'));
      continue;
    end if;

    applied_version := null;
    applied_at := null;
    remote := null;
    begin
      -- The base is the payload's version (ADR-0044, Amended — T3).
      base := (payload ->> 'version')::bigint;

      -- A create inserts if absent. When the row is there already it is a seed another device pushed (one v5 id, ADR-0002) or this
      -- create's own earlier attempt whose answer was lost; either way it goes on as an update at the payload's base, so an untouched
      -- copy is applied and a changed one conflicts. Each update writes only the columns `toPatch` writes: the rest are fixed (ADR-0036).
      case entity_type
        when 'account' then
          if operation = 'create' then
            insert into public.accounts select * from jsonb_populate_record(null::public.accounts, payload)
              on conflict (owner_id, id) do nothing
              returning version, updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            update public.accounts stored set name = sent.name, type = sent.type, initial_balance = sent.initial_balance, is_archived = sent.is_archived,
                deleted_at = sent.deleted_at
              from jsonb_populate_record(null::public.accounts, payload) sent
              where stored.owner_id = caller and stored.id = sent.id and stored.version = base
              returning stored.version, stored.updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            select to_jsonb(stored) into remote from public.accounts stored where stored.owner_id = caller and stored.id = (payload ->> 'id')::uuid;
          end if;
        when 'category' then
          if operation = 'create' then
            insert into public.categories select * from jsonb_populate_record(null::public.categories, payload)
              on conflict (owner_id, id) do nothing
              returning version, updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            update public.categories stored set name = sent.name, icon_key = sent.icon_key, color_key = sent.color_key, deleted_at = sent.deleted_at
              from jsonb_populate_record(null::public.categories, payload) sent
              where stored.owner_id = caller and stored.id = sent.id and stored.version = base
              returning stored.version, stored.updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            select to_jsonb(stored) into remote from public.categories stored where stored.owner_id = caller and stored.id = (payload ->> 'id')::uuid;
          end if;
        when 'transaction' then
          if operation = 'create' then
            insert into public.transactions select * from jsonb_populate_record(null::public.transactions, payload)
              on conflict (owner_id, id) do nothing
              returning version, updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            update public.transactions stored set type = sent.type, account_id = sent.account_id, destination_account_id = sent.destination_account_id,
                category_id = sent.category_id, amount_minor = sent.amount_minor, currency_code = sent.currency_code, occurred_at = sent.occurred_at,
                note = sent.note, deleted_at = sent.deleted_at
              from jsonb_populate_record(null::public.transactions, payload) sent
              where stored.owner_id = caller and stored.id = sent.id and stored.version = base
              returning stored.version, stored.updated_at into applied_version, applied_at;
          end if;
          if applied_version is null then
            select to_jsonb(stored) into remote from public.transactions stored where stored.owner_id = caller and stored.id = (payload ->> 'id')::uuid;
          end if;
      end case;

      results := results || jsonb_build_array(case
        when applied_version is not null then
          jsonb_build_object('mutation_id', mutation_id, 'status', 'applied', 'server_version', applied_version, 'server_updated_at', applied_at)
        when remote is not null then jsonb_build_object('mutation_id', mutation_id, 'status', 'conflict', 'remote', remote)
        else jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'not_found')
      end);
    -- Only what sending again cannot fix is caught, and only this mutation is rolled back. Anything else (a deadlock, a cancelled
    -- statement) fails the whole call, and the client retries the batch.
    exception
      when integrity_constraint_violation then
        get stacked diagnostics failed_constraint = constraint_name, failed_table = table_name, failed_column = column_name, failed_state = returned_sqlstate;
        results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', case
          when failed_constraint <> '' then failed_constraint
          when failed_state = '23502' then failed_table || '_' || failed_column || '_not_null'
          else failed_state
        end));
      when data_exception then
        results := results || jsonb_build_array(jsonb_build_object('mutation_id', mutation_id, 'status', 'rejected', 'code', 'invalid_payload'));
    end;
  end loop;

  return results;
end
$$;

-- Supabase grants EXECUTE on every new `public` function to anon and authenticated; the push is for a signed-in caller only.
revoke execute on function public.push_mutations(jsonb) from public, anon;
grant execute on function public.push_mutations(jsonb) to authenticated;
