-- Legacy snapshot table retained only for migration compatibility.
-- The active application uses page-scoped tables and RLS permissions.
create table if not exists public.plan_state (
  id text primary key,
  payload jsonb not null default '{}'::jsonb,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint plan_state_singleton check (id = 'main')
);
alter table public.plan_state enable row level security;
revoke all on table public.plan_state from anon, authenticated;
