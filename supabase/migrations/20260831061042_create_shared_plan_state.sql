create table if not exists public.plan_state (
  id text primary key,
  payload jsonb not null default '{}'::jsonb,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint plan_state_singleton check (id = 'main')
);

create index if not exists plan_state_updated_by_idx on public.plan_state(updated_by);
alter table public.plan_state enable row level security;

revoke all on table public.plan_state from anon, authenticated;
grant select on table public.plan_state to anon, authenticated;
grant insert, update, delete on table public.plan_state to authenticated;

create policy "public_can_read_plan" on public.plan_state for select to anon, authenticated using (true);
create policy "owner_can_insert_plan" on public.plan_state for insert to authenticated
with check (lower(coalesce(((select auth.jwt())->>'email'), '')) = 'fs101sk@gmail.com' and updated_by = (select auth.uid()));
create policy "owner_can_update_plan" on public.plan_state for update to authenticated
using (lower(coalesce(((select auth.jwt())->>'email'), '')) = 'fs101sk@gmail.com')
with check (lower(coalesce(((select auth.jwt())->>'email'), '')) = 'fs101sk@gmail.com' and updated_by = (select auth.uid()));
create policy "owner_can_delete_plan" on public.plan_state for delete to authenticated
using (lower(coalesce(((select auth.jwt())->>'email'), '')) = 'fs101sk@gmail.com');

insert into public.plan_state (id, payload, version) values ('main', '{}'::jsonb, 1) on conflict (id) do nothing;
alter publication supabase_realtime add table public.plan_state;
