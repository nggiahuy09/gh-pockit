-- The server stamps every synced write (ADR-0036). `version` and `updated_at` are the server's, some columns never change, and one
-- owner's writes are stamped in commit order, so the `(updated_at, id)` pull cursor never passes a row that commits later.

-- Not exposed by the Data API, which serves `public` only.
create schema private;

-- Statement level, so it runs before any row is locked. A signed-in caller writes only their own rows (ADR-0034), so taking their lock
-- here, first, means two of one owner's transactions never each hold a row the other waits for.
create function private.lock_caller_writes() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    perform pg_advisory_xact_lock(hashtextextended('pockit.owner_writes:' || auth.uid()::text, 0));
  end if;
  return null;
end
$$;

create function private.stamp_synced_write() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  newest bigint;
begin
  -- Already held for a signed-in caller; this covers the service role. Held until commit, so one owner's writes commit one at a time.
  perform pg_advisory_xact_lock(hashtextextended('pockit.owner_writes:' || new.owner_id::text, 0));
  -- Read after the lock: under READ COMMITTED this statement sees the owner's previous write, committed. Across all three tables, so
  -- the order holds for one cursor over all of them too. Index-only on each delta-pull index (ADR-0035).
  select greatest(
    (select max(updated_at) from public.accounts where owner_id = new.owner_id),
    (select max(updated_at) from public.categories where owner_id = new.owner_id),
    (select max(updated_at) from public.transactions where owner_id = new.owner_id)
  ) into newest;
  -- Never behind the owner's newest stamp, even if the clock steps back or a burst lands within one millisecond.
  new.updated_at := greatest((extract(epoch from clock_timestamp()) * 1000)::bigint, coalesce(newest, 0) + 1);
  new.version := case tg_op when 'INSERT' then 1 else old.version + 1 end;
  return new;
end
$$;

-- TG_ARGV lists the columns the local domain never writes after insert (each mapper's `toPatch`); a second client must not either.
create function private.refuse_fixed_columns() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  fixed text;
begin
  foreach fixed in array tg_argv loop
    if (to_jsonb(new) -> fixed) is distinct from (to_jsonb(old) -> fixed) then
      raise exception using
        errcode = 'check_violation',
        constraint = tg_table_name || '_' || fixed || '_fixed',
        message = format('%s.%s never changes after insert', tg_table_name, fixed);
    end if;
  end loop;
  return new;
end
$$;

-- Row triggers of one timing fire in name order: `fixed_columns` refuses before `stamp_write` takes the lock.
create trigger accounts_lock_caller before insert or update on public.accounts for each statement execute function private.lock_caller_writes();
create trigger accounts_fixed_columns before update on public.accounts
  for each row execute function private.refuse_fixed_columns('id', 'owner_id', 'created_at', 'currency_code');
create trigger accounts_stamp_write before insert or update on public.accounts for each row execute function private.stamp_synced_write();

-- `name_key` and `is_system` are a seeded row's identity: its id is a v5 of the owner and the key (ADR-0002).
create trigger categories_lock_caller before insert or update on public.categories for each statement execute function private.lock_caller_writes();
create trigger categories_fixed_columns before update on public.categories
  for each row execute function private.refuse_fixed_columns('id', 'owner_id', 'created_at', 'type', 'name_key', 'is_system');
create trigger categories_stamp_write before insert or update on public.categories for each row execute function private.stamp_synced_write();

create trigger transactions_lock_caller before insert or update on public.transactions for each statement execute function private.lock_caller_writes();
create trigger transactions_fixed_columns before update on public.transactions
  for each row execute function private.refuse_fixed_columns('id', 'owner_id', 'created_at');
create trigger transactions_stamp_write before insert or update on public.transactions for each row execute function private.stamp_synced_write();
