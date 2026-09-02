-- Creates the scoped operating state used by the interactive dashboard.
create table if not exists public.operating_scope_state (
  scope text primary key check (scope in ('people', 'visits', 'reports', 'tasks', 'assignments', 'meetings', 'decisions', 'calendar')),
  payload jsonb not null default '{"version":2,"initialized":false,"records":[]}'::jsonb,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.local_users(id) on delete set null
);

alter table public.operating_scope_state enable row level security;
revoke all on table public.operating_scope_state from anon, authenticated;

insert into public.operating_scope_state (scope)
select value
from unnest(array['people', 'visits', 'reports', 'tasks', 'assignments', 'meetings', 'decisions', 'calendar']) as value
on conflict (scope) do nothing;

create or replace function public.app_get_operating_state(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := private.local_user_for_token(p_token);
  is_admin boolean := coalesce(private.local_is_admin(p_token), false);
  state_row record;
  can_view boolean;
  can_edit boolean;
  scopes jsonb := '{}'::jsonb;
begin
  if uid is null then
    raise exception 'invalid_session';
  end if;

  for state_row in select * from public.operating_scope_state order by scope loop
    select is_admin or exists (
      select 1
      from public.local_page_permissions as permission
      join public.app_pages as page on page.page_key = permission.page_key
      where permission.user_id = uid
        and permission.can_view
        and page.active
        and (
          (state_row.scope = 'people')
          or (state_row.scope = 'visits' and page.title = 'الوضع الراهن للزيارات - لوحة متابعة المناطق')
          or (state_row.scope = 'reports' and page.title = 'متابعة حالة التقارير')
          or (state_row.scope = 'tasks' and page.title in ('المهام والمسارات التشغيلية', 'المتابعة حسب المسار الزمني'))
          or (state_row.scope = 'assignments' and page.title = 'توزيع الموظفين وأحمال العمل')
          or (state_row.scope in ('meetings', 'decisions') and page.title = 'الاجتماعات والقرارات')
          or (state_row.scope = 'calendar' and page.title = 'التقويم التشغيلي')
        )
    ) into can_view;

    select is_admin or exists (
      select 1
      from public.local_page_permissions as permission
      join public.app_pages as page on page.page_key = permission.page_key
      where permission.user_id = uid
        and permission.can_edit
        and page.active
        and (
          (state_row.scope = 'people' and page.title in ('إدارة الهيكل التنظيمي', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'))
          or (state_row.scope = 'visits' and page.title = 'الوضع الراهن للزيارات - لوحة متابعة المناطق')
          or (state_row.scope = 'reports' and page.title = 'متابعة حالة التقارير')
          or (state_row.scope = 'tasks' and page.title in ('المهام والمسارات التشغيلية', 'المتابعة حسب المسار الزمني'))
          or (state_row.scope = 'assignments' and page.title = 'توزيع الموظفين وأحمال العمل')
          or (state_row.scope in ('meetings', 'decisions') and page.title = 'الاجتماعات والقرارات')
          or (state_row.scope = 'calendar' and page.title = 'التقويم التشغيلي')
        )
    ) into can_edit;

    if can_view then
      scopes := scopes || jsonb_build_object(
        state_row.scope,
        jsonb_build_object(
          'payload', state_row.payload,
          'version', state_row.version,
          'can_edit', can_edit,
          'updated_at', state_row.updated_at
        )
      );
    end if;
  end loop;

  return jsonb_build_object('scopes', scopes);
end
$$;

drop function if exists public.app_save_operating_scope(text, text, jsonb, bigint);

create or replace function public.app_save_operating_scope(
  p_token text,
  p_scope text,
  p_payload jsonb,
  p_version bigint,
  p_action text default 'edit'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := private.local_user_for_token(p_token);
  is_admin boolean := coalesce(private.local_is_admin(p_token), false);
  allowed boolean := false;
  current_payload jsonb;
  needs_create boolean := false;
  needs_delete boolean := false;
  needs_assign boolean := false;
  next_version bigint;
begin
  if uid is null then
    raise exception 'invalid_session';
  end if;

  if p_scope not in ('people', 'visits', 'reports', 'tasks', 'assignments', 'meetings', 'decisions', 'calendar') then
    raise exception 'invalid_scope';
  end if;

  if p_action not in ('edit', 'create', 'delete', 'assign') then
    raise exception 'invalid_action';
  end if;

  if p_payload is null
    or jsonb_typeof(p_payload) <> 'object'
    or jsonb_typeof(p_payload -> 'records') <> 'array' then
    raise exception 'invalid_payload';
  end if;

  select payload
  into current_payload
  from public.operating_scope_state
  where scope = p_scope;

  if current_payload is null then
    raise exception 'invalid_scope';
  end if;

  if not coalesce((current_payload ->> 'initialized')::boolean, false) then
    if not is_admin then
      raise exception 'forbidden_bootstrap';
    end if;
  else
    select exists (
      select 1
      from jsonb_array_elements(p_payload -> 'records') as incoming(value)
      where not exists (
        select 1
        from jsonb_array_elements(current_payload -> 'records') as existing(value)
        where existing.value ->> 'id' = incoming.value ->> 'id'
      )
    ) into needs_create;

    select exists (
      select 1
      from jsonb_array_elements(current_payload -> 'records') as existing(value)
      where not exists (
        select 1
        from jsonb_array_elements(p_payload -> 'records') as incoming(value)
        where incoming.value ->> 'id' = existing.value ->> 'id'
      )
    ) into needs_delete;

    select exists (
      select 1
      from jsonb_array_elements(p_payload -> 'records') as incoming(value)
      join jsonb_array_elements(current_payload -> 'records') as existing(value)
        on existing.value ->> 'id' = incoming.value ->> 'id'
      where coalesce(incoming.value -> 'ownerIds', '[]'::jsonb) is distinct from coalesce(existing.value -> 'ownerIds', '[]'::jsonb)
         or coalesce(incoming.value -> 'evaluatorIds', '[]'::jsonb) is distinct from coalesce(existing.value -> 'evaluatorIds', '[]'::jsonb)
         or coalesce(incoming.value -> 'participantIds', '[]'::jsonb) is distinct from coalesce(existing.value -> 'participantIds', '[]'::jsonb)
         or coalesce(incoming.value ->> 'leaderId', '') is distinct from coalesce(existing.value ->> 'leaderId', '')
         or coalesce(incoming.value ->> 'ownerId', '') is distinct from coalesce(existing.value ->> 'ownerId', '')
    ) into needs_assign;
  end if;

  select is_admin or exists (
    select 1
    from public.local_page_permissions as permission
    join public.app_pages as page on page.page_key = permission.page_key
    where permission.user_id = uid
      and permission.can_edit
      and (not needs_create or permission.can_create)
      and (not needs_delete or permission.can_delete)
      and (not needs_assign or permission.can_assign)
      and (
        p_action = 'edit'
        or (p_action = 'create' and permission.can_create)
        or (p_action = 'delete' and permission.can_delete)
        or (p_action = 'assign' and permission.can_assign)
      )
      and page.active
      and (
        (p_scope = 'people' and page.title in ('إدارة الهيكل التنظيمي', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'))
        or (p_scope = 'visits' and page.title = 'الوضع الراهن للزيارات - لوحة متابعة المناطق')
        or (p_scope = 'reports' and page.title = 'متابعة حالة التقارير')
        or (p_scope = 'tasks' and page.title in ('المهام والمسارات التشغيلية', 'المتابعة حسب المسار الزمني'))
        or (p_scope = 'assignments' and page.title = 'توزيع الموظفين وأحمال العمل')
        or (p_scope in ('meetings', 'decisions') and page.title = 'الاجتماعات والقرارات')
        or (p_scope = 'calendar' and page.title = 'التقويم التشغيلي')
      )
  ) into allowed;

  if not coalesce(allowed, false) then
    raise exception 'forbidden';
  end if;

  update public.operating_scope_state
  set payload = p_payload,
      version = version + 1,
      updated_at = now(),
      updated_by = uid
  where scope = p_scope
    and version = p_version
  returning version into next_version;

  if next_version is null then
    raise exception 'version_conflict';
  end if;

  return jsonb_build_object('scope', p_scope, 'version', next_version);
end
$$;

revoke all on function public.app_get_operating_state(text) from public;
revoke all on function public.app_save_operating_scope(text, text, jsonb, bigint, text) from public;
grant execute on function public.app_get_operating_state(text) to anon, authenticated;
grant execute on function public.app_save_operating_scope(text, text, jsonb, bigint, text) to anon, authenticated;
