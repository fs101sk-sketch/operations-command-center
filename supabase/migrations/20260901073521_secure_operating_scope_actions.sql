-- Derives protected actions from the actual JSON delta before saving.
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
  current_version bigint;
  normalized_payload jsonb;
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

  -- Kept for backwards-compatible clients. Authorization is derived from the
  -- actual server-side delta below and never trusts this hint.
  if p_action not in ('edit', 'create', 'delete', 'assign') then
    raise exception 'invalid_action';
  end if;

  if p_payload is null
    or jsonb_typeof(p_payload) <> 'object'
    or jsonb_typeof(p_payload -> 'records') <> 'array' then
    raise exception 'invalid_payload';
  end if;

  normalized_payload := jsonb_set(p_payload, '{initialized}', 'true'::jsonb, true);

  select payload, version
  into current_payload, current_version
  from public.operating_scope_state
  where scope = p_scope;

  if current_payload is null then
    raise exception 'invalid_scope';
  end if;

  if p_version is null or p_version <> current_version then
    raise exception 'version_conflict';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(normalized_payload -> 'records') as record(item)
    where jsonb_typeof(record.item) <> 'object'
       or nullif(btrim(record.item ->> 'id'), '') is null
  ) or (
    select count(*) <> count(distinct record.item ->> 'id')
    from jsonb_array_elements(normalized_payload -> 'records') as record(item)
  ) then
    raise exception 'invalid_payload';
  end if;

  if p_scope = 'calendar' then
    if jsonb_array_length(normalized_payload -> 'records') <> 1
      or normalized_payload #>> '{records,0,id}' <> 'main'
      or jsonb_typeof(normalized_payload #> '{records,0,events}') <> 'array'
      or jsonb_typeof(normalized_payload #> '{records,0,topics}') <> 'array' then
      raise exception 'invalid_payload';
    end if;

    if exists (
      select 1
      from jsonb_array_elements(normalized_payload #> '{records,0,events}') as event(item)
      where jsonb_typeof(event.item) <> 'object'
         or nullif(btrim(event.item ->> 'id'), '') is null
    ) or exists (
      select 1
      from jsonb_array_elements(normalized_payload #> '{records,0,topics}') as topic(item)
      where jsonb_typeof(topic.item) <> 'object'
         or nullif(btrim(topic.item ->> 'id'), '') is null
    ) or (
      select count(*) <> count(distinct event.item ->> 'id')
      from jsonb_array_elements(normalized_payload #> '{records,0,events}') as event(item)
    ) or (
      select count(*) <> count(distinct topic.item ->> 'id')
      from jsonb_array_elements(normalized_payload #> '{records,0,topics}') as topic(item)
    ) then
      raise exception 'invalid_payload';
    end if;
  end if;

  if coalesce((current_payload ->> 'initialized')::boolean, false) then
    with incoming(kind, id, item) as (
      select 'record', record.item ->> 'id', record.item
      from jsonb_array_elements(normalized_payload -> 'records') as record(item)
      where p_scope <> 'calendar'

      union all

      select 'event', event.item ->> 'id', event.item
      from jsonb_array_elements(coalesce(normalized_payload #> '{records,0,events}', '[]'::jsonb)) as event(item)
      where p_scope = 'calendar'

      union all

      select 'topic', topic.item ->> 'id', topic.item
      from jsonb_array_elements(coalesce(normalized_payload #> '{records,0,topics}', '[]'::jsonb)) as topic(item)
      where p_scope = 'calendar'
    ), existing(kind, id, item) as (
      select 'record', record.item ->> 'id', record.item
      from jsonb_array_elements(coalesce(current_payload -> 'records', '[]'::jsonb)) as record(item)
      where p_scope <> 'calendar'

      union all

      select 'event', event.item ->> 'id', event.item
      from jsonb_array_elements(coalesce(current_payload #> '{records,0,events}', '[]'::jsonb)) as event(item)
      where p_scope = 'calendar'

      union all

      select 'topic', topic.item ->> 'id', topic.item
      from jsonb_array_elements(coalesce(current_payload #> '{records,0,topics}', '[]'::jsonb)) as topic(item)
      where p_scope = 'calendar'
    ), delta as (
      select incoming.item as new_item, existing.item as old_item
      from incoming
      full join existing using (kind, id)
    )
    select
      coalesce(bool_or(old_item is null), false),
      coalesce(bool_or(new_item is null), false),
      coalesce(bool_or(
        new_item is not null and (
          (
            old_item is not null and
            jsonb_build_array(
              coalesce(new_item -> 'ownerIds', '[]'::jsonb),
              coalesce(new_item -> 'evaluatorIds', '[]'::jsonb),
              coalesce(new_item -> 'participantIds', '[]'::jsonb),
              coalesce(new_item ->> 'leaderId', ''),
              coalesce(new_item ->> 'ownerId', '')
            ) is distinct from
            jsonb_build_array(
              coalesce(old_item -> 'ownerIds', '[]'::jsonb),
              coalesce(old_item -> 'evaluatorIds', '[]'::jsonb),
              coalesce(old_item -> 'participantIds', '[]'::jsonb),
              coalesce(old_item ->> 'leaderId', ''),
              coalesce(old_item ->> 'ownerId', '')
            )
          ) or (
            old_item is null and
            jsonb_build_array(
              coalesce(new_item -> 'ownerIds', '[]'::jsonb),
              coalesce(new_item -> 'evaluatorIds', '[]'::jsonb),
              coalesce(new_item -> 'participantIds', '[]'::jsonb),
              coalesce(new_item ->> 'leaderId', ''),
              coalesce(new_item ->> 'ownerId', '')
            ) <> jsonb_build_array('[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '', '')
          )
        )
      ), false)
    into needs_create, needs_delete, needs_assign
    from delta;
  elsif not is_admin then
    raise exception 'forbidden_bootstrap';
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
  set payload = normalized_payload,
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

revoke all on function public.app_save_operating_scope(text, text, jsonb, bigint, text) from public, anon, authenticated;
grant execute on function public.app_save_operating_scope(text, text, jsonb, bigint, text) to anon, authenticated;
