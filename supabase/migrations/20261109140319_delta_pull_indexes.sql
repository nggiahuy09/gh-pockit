-- The delta pull reads each table as `owner_id = auth.uid() and (updated_at, id) > cursor order by updated_at, id limit n` (ADR-0035).
-- `id` closes each index so the row comparison is one index condition and the ORDER BY needs no sort, as locally (ADR-0009).
-- Plain CREATE INDEX: the tables are empty. Once they hold data, an index is built CONCURRENTLY, outside a migration's transaction.
create index transactions_owner_id_updated_at_id on public.transactions (owner_id, updated_at, id);
create index accounts_owner_id_updated_at_id on public.accounts (owner_id, updated_at, id);
create index categories_owner_id_updated_at_id on public.categories (owner_id, updated_at, id);
