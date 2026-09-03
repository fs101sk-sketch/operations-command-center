-- Private, permission-gated storage for the 2026 participant balance.
-- Source names and file bytes are loaded separately and are never committed to Git.

create table if not exists public.balance_2026_state (
  id text primary key check (id = 'main'),
  payload jsonb not null default '{}'::jsonb,
  payload_gzip bytea,
  payload_encoding text not null default 'gzip+json',
  payload_sha256 text,
  workbook bytea,
  workbook_name text not null default 'رصيد 2026.xlsx',
  workbook_sha256 text,
  workbook_url text,
  chart_image bytea,
  chart_name text not null default 'معاينة الرسم البياني 2026.webp',
  chart_mime text not null default 'image/webp',
  chart_sha256 text,
  chart_source_url text,
  chart_source_name text,
  chart_source_sha256 text,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.local_users(id) on delete set null
);

alter table public.balance_2026_state add column if not exists payload_gzip bytea;
alter table public.balance_2026_state add column if not exists payload_encoding text not null default 'gzip+json';
alter table public.balance_2026_state add column if not exists payload_sha256 text;
alter table public.balance_2026_state add column if not exists workbook bytea;
alter table public.balance_2026_state add column if not exists workbook_name text not null default 'رصيد 2026.xlsx';
alter table public.balance_2026_state add column if not exists workbook_sha256 text;
alter table public.balance_2026_state add column if not exists workbook_url text;
alter table public.balance_2026_state add column if not exists chart_image bytea;
alter table public.balance_2026_state add column if not exists chart_name text not null default 'معاينة الرسم البياني 2026.webp';
alter table public.balance_2026_state add column if not exists chart_mime text not null default 'image/webp';
alter table public.balance_2026_state add column if not exists chart_sha256 text;
alter table public.balance_2026_state add column if not exists chart_source_url text;
alter table public.balance_2026_state add column if not exists chart_source_name text;
alter table public.balance_2026_state add column if not exists chart_source_sha256 text;
alter table public.balance_2026_state add column if not exists version bigint not null default 1;
alter table public.balance_2026_state add column if not exists updated_at timestamptz not null default now();
alter table public.balance_2026_state add column if not exists updated_by uuid references public.local_users(id) on delete set null;

alter table public.balance_2026_state enable row level security;
revoke all on table public.balance_2026_state from anon, authenticated;

insert into public.app_pages (page_key, title, position, public_visible, active)
values (
  'page-balance-2026',
  'رصيد المشاركين 2026',
  (select coalesce(max(position), 0) + 1 from public.app_pages),
  false,
  true
)
on conflict (page_key) do update
set title = excluded.title,
    public_visible = false,
    active = true,
    updated_at = now();

create or replace function public.app_get_balance_2026(
  p_token text,
  p_include_workbook boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := private.local_user_for_token(p_token);
  is_admin boolean := coalesce(private.local_is_admin(p_token), false);
  allowed boolean := false;
  state_row public.balance_2026_state%rowtype;
begin
  if uid is null then
    raise exception 'invalid_session';
  end if;

  select is_admin or exists (
    select 1
    from public.local_page_permissions as permission
    join public.app_pages as page
      on page.page_key = permission.page_key
    where permission.user_id = uid
      and permission.page_key = 'page-balance-2026'
      and permission.can_view
      and page.active
  ) into allowed;

  if not coalesce(allowed, false) then
    raise exception 'forbidden';
  end if;

  select *
  into state_row
  from public.balance_2026_state
  where id = 'main';

  if not found
     or state_row.payload_gzip is null
     or state_row.payload_sha256 is null
     or state_row.chart_image is null
     or state_row.chart_sha256 is null
     or jsonb_typeof(state_row.payload) <> 'object'
     or jsonb_typeof(state_row.payload -> 'typeOverlay') <> 'object' then
    raise exception 'balance_data_unavailable';
  end if;

  if encode(extensions.digest(state_row.chart_image, 'sha256'), 'hex') <> lower(state_row.chart_sha256) then
    raise exception 'asset_integrity_failed';
  end if;

  if state_row.workbook is not null
     and state_row.workbook_sha256 is not null
     and encode(extensions.digest(state_row.workbook, 'sha256'), 'hex') <> lower(state_row.workbook_sha256) then
    raise exception 'asset_integrity_failed';
  end if;

  return jsonb_build_object(
    'payload', state_row.payload,
    'payload_encoding', state_row.payload_encoding,
    'payload_sha256', state_row.payload_sha256,
    'payload_gzip_base64', encode(state_row.payload_gzip, 'base64'),
    'version', state_row.version,
    'updated_at', state_row.updated_at,
    'workbook_name', state_row.workbook_name,
    'workbook_sha256', state_row.workbook_sha256,
    'workbook_url', state_row.workbook_url,
    'workbook_base64', case
      when coalesce(p_include_workbook, false) and state_row.workbook is not null
        then encode(state_row.workbook, 'base64')
      else null
    end,
    'image_name', state_row.chart_name,
    'image_mime', state_row.chart_mime,
    'image_sha256', state_row.chart_sha256,
    'image_base64', encode(state_row.chart_image, 'base64'),
    'image_source_url', state_row.chart_source_url,
    'image_source_name', state_row.chart_source_name,
    'image_source_sha256', state_row.chart_source_sha256
  );
end
$$;

revoke all on function public.app_get_balance_2026(text, boolean) from public;
grant execute on function public.app_get_balance_2026(text, boolean) to anon, authenticated;
