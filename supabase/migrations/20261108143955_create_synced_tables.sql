-- The server copy of the three synced tables (ADR-0033). Every SQLite INTEGER is a bigint: money (ADR-0007), epoch-millisecond timestamps
-- and version. No column defaults, as locally: a value nobody wrote would pass for one somebody did. `sync_status` is local-only.

create table public.accounts (
  id uuid primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  -- Vocabulary checks exist here and not locally: one ALTER changes them, and the server is the last guard before a bad value reaches
  -- every other device's mapper.
  type text not null check (type in ('cash', 'bank', 'e_wallet', 'credit_card', 'other')),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  initial_balance bigint not null,
  is_archived boolean not null,
  created_at bigint not null,
  updated_at bigint not null,
  version bigint not null,
  deleted_at bigint,
  -- Target of the children's owner-scoped foreign keys.
  unique (id, owner_id)
);

create table public.categories (
  id uuid primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  name_key text,
  name text,
  type text not null check (type in ('expense', 'income')),
  icon_key text,
  color_key text,
  is_system boolean not null,
  created_at bigint not null,
  updated_at bigint not null,
  version bigint not null,
  deleted_at bigint,
  constraint categories_name_or_name_key check (name_key is not null or name is not null),
  unique (id, owner_id),
  -- NULLs are distinct, as in SQLite, so user-made rows never collide.
  unique (owner_id, name_key)
);

create table public.transactions (
  id uuid primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('expense', 'income', 'transfer')),
  account_id uuid not null,
  destination_account_id uuid,
  category_id uuid,
  amount_minor bigint not null check (amount_minor > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  occurred_at bigint not null,
  note text,
  created_at bigint not null,
  updated_at bigint not null,
  version bigint not null,
  deleted_at bigint,
  -- A foreign key check bypasses RLS, so a plain `references accounts (id)` would accept another user's account. Checked immediately,
  -- no ON DELETE, as locally (ADR-0009). A NULL destination or category skips its check (MATCH SIMPLE).
  foreign key (account_id, owner_id) references public.accounts (id, owner_id),
  foreign key (destination_account_id, owner_id) references public.accounts (id, owner_id),
  foreign key (category_id, owner_id) references public.categories (id, owner_id),
  constraint transactions_destination_iff_transfer check ((type = 'transfer') = (destination_account_id is not null)),
  constraint transactions_destination_not_source check (destination_account_id <> account_id),
  constraint transactions_transfer_without_category check (type <> 'transfer' or category_id is null)
);

-- On before any policy exists: the Data API serves `public` to anyone holding the publishable key, so until T4 adds the owner policies
-- nobody but the service role reads or writes a row.
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
