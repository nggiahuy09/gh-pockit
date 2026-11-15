-- Each owner reads and writes only their own rows (ADR-0034).

-- An id is unique per owner, not across owners. With a global key, one user could insert another's id first and block that owner's write,
-- or learn from the 23505 that the id exists; a seeded category's v5 id can be computed from its owner's uid (ADR-0002). The new keys
-- replace T3's `unique (id, owner_id)` as the targets of the owner-scoped foreign keys, under the same names.
alter table public.transactions
  drop constraint transactions_account_id_owner_id_fkey,
  drop constraint transactions_destination_account_id_owner_id_fkey,
  drop constraint transactions_category_id_owner_id_fkey;

alter table public.accounts drop constraint accounts_pkey, drop constraint accounts_id_owner_id_key, add primary key (owner_id, id);
alter table public.categories drop constraint categories_pkey, drop constraint categories_id_owner_id_key, add primary key (owner_id, id);
alter table public.transactions drop constraint transactions_pkey, add primary key (owner_id, id);

alter table public.transactions
  add constraint transactions_account_id_owner_id_fkey foreign key (account_id, owner_id) references public.accounts (id, owner_id),
  add constraint transactions_destination_account_id_owner_id_fkey foreign key (destination_account_id, owner_id) references public.accounts (id, owner_id),
  add constraint transactions_category_id_owner_id_fkey foreign key (category_id, owner_id) references public.categories (id, owner_id);

-- Supabase grants every privilege on a new `public` table to anon and authenticated, TRUNCATE included, which RLS does not cover. Anon gets
-- nothing; a signed-in user gets no DELETE either: a synced row is only ever soft-deleted (ADR-0031), and purging a tombstone is a server
-- job under the service role (P4).
revoke all on table public.accounts, public.categories, public.transactions from anon, authenticated;
grant select, insert, update on table public.accounts, public.categories, public.transactions to authenticated;

-- `(select auth.uid())` runs once per statement instead of once per row. The update policy puts no condition on `deleted_at`: an undo
-- clears it on a tombstone (ADR-0017).
create policy accounts_select_own on public.accounts for select to authenticated using (owner_id = (select auth.uid()));
create policy accounts_insert_own on public.accounts for insert to authenticated with check (owner_id = (select auth.uid()));
create policy accounts_update_own on public.accounts for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create policy categories_select_own on public.categories for select to authenticated using (owner_id = (select auth.uid()));
create policy categories_insert_own on public.categories for insert to authenticated with check (owner_id = (select auth.uid()));
create policy categories_update_own on public.categories for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create policy transactions_select_own on public.transactions for select to authenticated using (owner_id = (select auth.uid()));
create policy transactions_insert_own on public.transactions for insert to authenticated with check (owner_id = (select auth.uid()));
create policy transactions_update_own on public.transactions for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
