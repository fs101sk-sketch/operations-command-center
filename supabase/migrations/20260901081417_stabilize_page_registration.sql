-- Migration version 20260901081417.
-- Stabilize built-in page keys, preserve the newest content, and archive only
-- semantic duplicates. Unrelated pages omitted by a client are never touched.
create or replace function public.app_admin_register_pages(
  p_token text,
  p_pages jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not coalesce(private.local_is_admin(p_token), false) then
    raise exception 'forbidden';
  end if;

  -- Serialize page registration so two admin tabs cannot migrate/archive the
  -- same semantic page at the same time.
  perform pg_catalog.pg_advisory_xact_lock(5574892012345);

  if p_pages is null
     or jsonb_typeof(p_pages) <> 'array'
     or jsonb_array_length(p_pages) = 0
     or exists (
       select 1
       from jsonb_array_elements(p_pages) item
       where jsonb_typeof(item) <> 'object'
          or nullif(btrim(item ->> 'page_key'), '') is null
          or nullif(btrim(item ->> 'title'), '') is null
          or item ->> 'page_key' <> btrim(item ->> 'page_key')
          or item ->> 'title' <> btrim(item ->> 'title')
          or jsonb_typeof(item -> 'content') is distinct from 'object'
     )
     or (
       select count(*) <> count(distinct btrim(item ->> 'page_key'))
       from jsonb_array_elements(p_pages) item
     ) then
    raise exception 'invalid_payload';
  end if;

  -- Reject older clients that try to register a built-in page under a random key.
  if exists (
    select 1
    from jsonb_to_recordset(p_pages) incoming(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    join (
      values
        ('ادارة العمليات', 'page-cover'),
        ('نظرة عامة', 'page-overview'),
        ('أعداد وأسماء الموظفين حسب الهيكل التنظيمي', 'page-organization-overview'),
        ('الوضع الراهن للزيارات - لوحة متابعة المناطق', 'page-visits-current'),
        ('متابعة حالة التقارير', 'page-reports-status'),
        ('المهام والمسارات التشغيلية', 'page-tasks-paths'),
        ('إدارة الهيكل التنظيمي', 'page-people-management'),
        ('توزيع الموظفين وأحمال العمل', 'page-workload'),
        ('الاجتماعات والقرارات', 'page-meetings-decisions'),
        ('الداشبورد التنفيذي', 'page-executive-dashboard'),
        ('المتابعة حسب المسار الزمني', 'page-timeline'),
        ('التقويم التشغيلي', 'page-calendar'),
        ('توزيع المسؤوليات حسب الموظفين', 'page-responsibilities'),
        ('المخرجات المستهدفة بنهاية الفترة', 'page-outputs'),
        ('أبرز التحديات المحتملة والحلول المقترحة', 'page-challenges'),
        ('مكتبة القادة', 'page-resource-library')
    ) expected(title, page_key)
      on btrim(incoming.title) = expected.title
    where incoming.page_key <> expected.page_key
  ) or exists (
    select 1
    from jsonb_to_recordset(p_pages) incoming(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    where incoming.content ->> 'html' like '%class="slide closing%'
      and incoming.page_key <> 'page-closing'
  ) or exists (
    select 1
    from jsonb_to_recordset(p_pages) incoming(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    where incoming.page_key = 'page-closing'
      and coalesce(incoming.content ->> 'html', '') not like '%class="slide closing%'
  ) then
    raise exception 'invalid_page_key';
  end if;

  with incoming as (
    select item.*,
           expected.title as expected_title
    from jsonb_to_recordset(p_pages) item(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    left join (
      values
        ('page-cover', 'ادارة العمليات'),
        ('page-overview', 'نظرة عامة'),
        ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
        ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
        ('page-reports-status', 'متابعة حالة التقارير'),
        ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
        ('page-people-management', 'إدارة الهيكل التنظيمي'),
        ('page-workload', 'توزيع الموظفين وأحمال العمل'),
        ('page-meetings-decisions', 'الاجتماعات والقرارات'),
        ('page-executive-dashboard', 'الداشبورد التنفيذي'),
        ('page-timeline', 'المتابعة حسب المسار الزمني'),
        ('page-calendar', 'التقويم التشغيلي'),
        ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
        ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
        ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
        ('page-resource-library', 'مكتبة القادة')
    ) expected(page_key, title)
      on expected.page_key = item.page_key
  )
  insert into public.app_pages as target (
    page_key, title, position, public_visible, active
  )
  select
    incoming.page_key,
    incoming.title,
    greatest(coalesce(incoming.position, 0), 0),
    coalesce(
      (
        select pg_catalog.bool_and(previous.public_visible)
        from public.app_pages previous
        left join public.plan_sections previous_section
          on previous_section.page_key = previous.page_key
        where previous.page_key = incoming.page_key
           or (
             previous.active
             and (
               previous.page_key like 'page-nav-%'
               or previous.page_key ~ '^page-[0-9]+$'
             )
             and (
               (
                 incoming.expected_title is not null
                 and btrim(previous.title) = incoming.expected_title
               )
               or (
                 incoming.page_key = 'page-closing'
                 and previous_section.content ->> 'html' like '%class="slide closing%'
               )
            )
          )
      ),
      incoming.public_visible,
      true
    ),
    true
  from incoming
  on conflict (page_key) do update
  set title = excluded.title,
      position = excluded.position,
      public_visible = target.public_visible and excluded.public_visible,
      active = true,
      updated_at = now()
  where (target.title, target.position, target.public_visible, target.active)
        is distinct from
        (excluded.title, excluded.position,
         target.public_visible and excluded.public_visible, true);

  -- Reuse the newest saved semantic copy. If a stable key exists but is older,
  -- refresh only that key and advance its version; custom pages never merge by title.
  with incoming as (
    select item.page_key,
           item.title,
           item.content as incoming_content,
           case item.page_key
             when 'page-cover' then 'ادارة العمليات'
             when 'page-overview' then 'نظرة عامة'
             when 'page-organization-overview' then 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'
             when 'page-visits-current' then 'الوضع الراهن للزيارات - لوحة متابعة المناطق'
             when 'page-reports-status' then 'متابعة حالة التقارير'
             when 'page-tasks-paths' then 'المهام والمسارات التشغيلية'
             when 'page-people-management' then 'إدارة الهيكل التنظيمي'
             when 'page-workload' then 'توزيع الموظفين وأحمال العمل'
             when 'page-meetings-decisions' then 'الاجتماعات والقرارات'
             when 'page-executive-dashboard' then 'الداشبورد التنفيذي'
             when 'page-timeline' then 'المتابعة حسب المسار الزمني'
             when 'page-calendar' then 'التقويم التشغيلي'
             when 'page-responsibilities' then 'توزيع المسؤوليات حسب الموظفين'
             when 'page-outputs' then 'المخرجات المستهدفة بنهاية الفترة'
             when 'page-challenges' then 'أبرز التحديات المحتملة والحلول المقترحة'
             when 'page-resource-library' then 'مكتبة القادة'
             else null
           end as expected_title
    from jsonb_to_recordset(p_pages) item(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
  ), candidates as (
    select incoming.page_key,
           incoming.incoming_content,
           source.content as source_content,
           source.version as source_version,
           source.updated_at as source_updated_at
    from incoming
    left join lateral (
      select section.content,
             section.version,
             section.updated_at
      from public.app_pages previous
      join public.plan_sections section
        on section.page_key = previous.page_key
      where previous.active
        and (
          previous.page_key = incoming.page_key
          or (
            previous.page_key <> incoming.page_key
            and (
              previous.page_key like 'page-nav-%'
              or previous.page_key ~ '^page-[0-9]+$'
            )
            and (
              (
                incoming.expected_title is not null
                and btrim(previous.title) = incoming.expected_title
              )
              or (
                incoming.page_key = 'page-closing'
                and section.content ->> 'html' like '%class="slide closing%'
              )
            )
          )
        )
      order by section.updated_at desc,
               section.version desc,
               previous.updated_at desc,
               previous.page_key
      limit 1
    ) source on true
  )
  insert into public.plan_sections as target (
    page_key, content, version, updated_at
  )
  select page_key,
         coalesce(source_content, incoming_content),
         coalesce(source_version, 1),
         coalesce(source_updated_at, now())
  from candidates
  on conflict (page_key) do update
  set content = excluded.content,
      version = greatest(target.version, excluded.version) + 1,
      updated_at = now()
  where target.content is distinct from excluded.content
    and (
      excluded.updated_at > target.updated_at
      or (
        excluded.updated_at = target.updated_at
        and excluded.version >= target.version
      )
    );

  -- Duplicates are the same logical page, so preserve the union of their grants.
  with incoming as (
    select item.page_key,
           case item.page_key
             when 'page-cover' then 'ادارة العمليات'
             when 'page-overview' then 'نظرة عامة'
             when 'page-organization-overview' then 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'
             when 'page-visits-current' then 'الوضع الراهن للزيارات - لوحة متابعة المناطق'
             when 'page-reports-status' then 'متابعة حالة التقارير'
             when 'page-tasks-paths' then 'المهام والمسارات التشغيلية'
             when 'page-people-management' then 'إدارة الهيكل التنظيمي'
             when 'page-workload' then 'توزيع الموظفين وأحمال العمل'
             when 'page-meetings-decisions' then 'الاجتماعات والقرارات'
             when 'page-executive-dashboard' then 'الداشبورد التنفيذي'
             when 'page-timeline' then 'المتابعة حسب المسار الزمني'
             when 'page-calendar' then 'التقويم التشغيلي'
             when 'page-responsibilities' then 'توزيع المسؤوليات حسب الموظفين'
             when 'page-outputs' then 'المخرجات المستهدفة بنهاية الفترة'
             when 'page-challenges' then 'أبرز التحديات المحتملة والحلول المقترحة'
             when 'page-resource-library' then 'مكتبة القادة'
             else null
           end as expected_title
    from jsonb_to_recordset(p_pages) item(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    where item.page_key in (
      'page-cover', 'page-overview', 'page-organization-overview',
      'page-visits-current', 'page-reports-status', 'page-tasks-paths',
      'page-people-management', 'page-workload', 'page-meetings-decisions',
      'page-executive-dashboard', 'page-timeline', 'page-calendar',
      'page-responsibilities', 'page-outputs', 'page-challenges',
      'page-closing', 'page-resource-library'
    )
  ), sources as (
    select incoming.page_key as new_page_key,
           previous.page_key as old_page_key
    from incoming
    join public.app_pages previous
      on previous.active
     and previous.page_key <> incoming.page_key
     and (
       previous.page_key like 'page-nav-%'
       or previous.page_key ~ '^page-[0-9]+$'
     )
    left join public.plan_sections previous_section
      on previous_section.page_key = previous.page_key
    where (
         incoming.expected_title is not null
         and btrim(previous.title) = incoming.expected_title
       )
       or (
         incoming.page_key = 'page-closing'
         and previous_section.content ->> 'html' like '%class="slide closing%'
       )
  ), merged as (
    select permission.user_id,
           sources.new_page_key as page_key,
           bool_or(permission.can_view) as can_view,
           bool_or(permission.can_edit) as can_edit,
           bool_or(permission.can_create) as can_create,
           bool_or(permission.can_delete) as can_delete,
           bool_or(permission.can_assign) as can_assign
    from sources
    join public.local_page_permissions permission
      on permission.page_key = sources.old_page_key
    group by permission.user_id, sources.new_page_key
  )
  insert into public.local_page_permissions (
    user_id, page_key, can_view, can_edit, can_create, can_delete, can_assign
  )
  select user_id,
         page_key,
         can_view or can_edit or can_create or can_delete or can_assign,
         can_edit,
         can_create,
         can_delete,
         can_assign
  from merged
  on conflict (user_id, page_key) do update
  set can_view = public.local_page_permissions.can_view or excluded.can_view,
      can_edit = public.local_page_permissions.can_edit or excluded.can_edit,
      can_create = public.local_page_permissions.can_create or excluded.can_create,
      can_delete = public.local_page_permissions.can_delete or excluded.can_delete,
      can_assign = public.local_page_permissions.can_assign or excluded.can_assign;

  -- Archive only older semantic copies of built-in pages present in this payload.
  with incoming as (
    select item.page_key,
           case item.page_key
             when 'page-cover' then 'ادارة العمليات'
             when 'page-overview' then 'نظرة عامة'
             when 'page-organization-overview' then 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'
             when 'page-visits-current' then 'الوضع الراهن للزيارات - لوحة متابعة المناطق'
             when 'page-reports-status' then 'متابعة حالة التقارير'
             when 'page-tasks-paths' then 'المهام والمسارات التشغيلية'
             when 'page-people-management' then 'إدارة الهيكل التنظيمي'
             when 'page-workload' then 'توزيع الموظفين وأحمال العمل'
             when 'page-meetings-decisions' then 'الاجتماعات والقرارات'
             when 'page-executive-dashboard' then 'الداشبورد التنفيذي'
             when 'page-timeline' then 'المتابعة حسب المسار الزمني'
             when 'page-calendar' then 'التقويم التشغيلي'
             when 'page-responsibilities' then 'توزيع المسؤوليات حسب الموظفين'
             when 'page-outputs' then 'المخرجات المستهدفة بنهاية الفترة'
             when 'page-challenges' then 'أبرز التحديات المحتملة والحلول المقترحة'
             when 'page-resource-library' then 'مكتبة القادة'
             else null
           end as expected_title
    from jsonb_to_recordset(p_pages) item(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    where item.page_key in (
      'page-cover', 'page-overview', 'page-organization-overview',
      'page-visits-current', 'page-reports-status', 'page-tasks-paths',
      'page-people-management', 'page-workload', 'page-meetings-decisions',
      'page-executive-dashboard', 'page-timeline', 'page-calendar',
      'page-responsibilities', 'page-outputs', 'page-challenges',
      'page-closing', 'page-resource-library'
    )
  )
  update public.app_pages previous
  set active = false,
      updated_at = now()
  where previous.active
    and exists (
      select 1
      from incoming
      left join public.plan_sections previous_section
        on previous_section.page_key = previous.page_key
      where previous.page_key <> incoming.page_key
        and (
          previous.page_key like 'page-nav-%'
          or previous.page_key ~ '^page-[0-9]+$'
        )
        and (
          (
            incoming.expected_title is not null
            and btrim(previous.title) = incoming.expected_title
          )
          or (
            incoming.page_key = 'page-closing'
            and previous_section.content ->> 'html' like '%class="slide closing%'
          )
        )
    );

  -- Grants have already been copied to the stable key; remove only the archived
  -- semantic copies so a later registration cannot resurrect revoked access.
  with incoming as (
    select item.page_key,
           case item.page_key
             when 'page-cover' then 'ادارة العمليات'
             when 'page-overview' then 'نظرة عامة'
             when 'page-organization-overview' then 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'
             when 'page-visits-current' then 'الوضع الراهن للزيارات - لوحة متابعة المناطق'
             when 'page-reports-status' then 'متابعة حالة التقارير'
             when 'page-tasks-paths' then 'المهام والمسارات التشغيلية'
             when 'page-people-management' then 'إدارة الهيكل التنظيمي'
             when 'page-workload' then 'توزيع الموظفين وأحمال العمل'
             when 'page-meetings-decisions' then 'الاجتماعات والقرارات'
             when 'page-executive-dashboard' then 'الداشبورد التنفيذي'
             when 'page-timeline' then 'المتابعة حسب المسار الزمني'
             when 'page-calendar' then 'التقويم التشغيلي'
             when 'page-responsibilities' then 'توزيع المسؤوليات حسب الموظفين'
             when 'page-outputs' then 'المخرجات المستهدفة بنهاية الفترة'
             when 'page-challenges' then 'أبرز التحديات المحتملة والحلول المقترحة'
             when 'page-resource-library' then 'مكتبة القادة'
             else null
           end as expected_title
    from jsonb_to_recordset(p_pages) item(
      page_key text,
      title text,
      position int,
      public_visible boolean,
      content jsonb
    )
    where item.page_key in (
      'page-cover', 'page-overview', 'page-organization-overview',
      'page-visits-current', 'page-reports-status', 'page-tasks-paths',
      'page-people-management', 'page-workload', 'page-meetings-decisions',
      'page-executive-dashboard', 'page-timeline', 'page-calendar',
      'page-responsibilities', 'page-outputs', 'page-challenges',
      'page-closing', 'page-resource-library'
    )
  )
  delete from public.local_page_permissions permission
  using public.app_pages previous
  left join public.plan_sections previous_section
    on previous_section.page_key = previous.page_key
  where permission.page_key = previous.page_key
    and not previous.active
    and exists (
      select 1
      from incoming
      where previous.page_key <> incoming.page_key
        and (
          previous.page_key like 'page-nav-%'
          or previous.page_key ~ '^page-[0-9]+$'
        )
        and (
          (
            incoming.expected_title is not null
            and btrim(previous.title) = incoming.expected_title
          )
          or (
            incoming.page_key = 'page-closing'
            and previous_section.content ->> 'html' like '%class="slide closing%'
          )
        )
    );

  return true;
end
$$;

select pg_catalog.pg_advisory_xact_lock(5574892012345);
lock table public.app_pages,
           public.plan_sections,
           public.local_page_permissions
  in share row exclusive mode;

-- One-time migration of known built-in pages to stable keys. Only those semantic
-- pages are consolidated; custom pages with matching titles outside this map remain.
with mapping(page_key, title) as (
  values
    ('page-cover', 'ادارة العمليات'),
    ('page-overview', 'نظرة عامة'),
    ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
    ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
    ('page-reports-status', 'متابعة حالة التقارير'),
    ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
    ('page-people-management', 'إدارة الهيكل التنظيمي'),
    ('page-workload', 'توزيع الموظفين وأحمال العمل'),
    ('page-meetings-decisions', 'الاجتماعات والقرارات'),
    ('page-executive-dashboard', 'الداشبورد التنفيذي'),
    ('page-timeline', 'المتابعة حسب المسار الزمني'),
    ('page-calendar', 'التقويم التشغيلي'),
    ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
    ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
    ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
    ('page-resource-library', 'مكتبة القادة')
), ranked as (
  select mapping.page_key,
         mapping.title,
         page.position,
         pg_catalog.bool_and(page.public_visible) over (
           partition by mapping.page_key
         ) as public_visible,
         row_number() over (
           partition by mapping.page_key
           order by section.updated_at desc nulls last,
                    section.version desc nulls last,
                    page.updated_at desc,
                    page.page_key
         ) as rank
  from mapping
  join public.app_pages page
    on page.active
   and btrim(page.title) = mapping.title
   and (
     page.page_key = mapping.page_key
     or page.page_key like 'page-nav-%'
     or page.page_key ~ '^page-[0-9]+$'
   )
  left join public.plan_sections section
    on section.page_key = page.page_key
)
insert into public.app_pages (
  page_key, title, position, public_visible, active
)
select page_key, title, position, public_visible, true
from ranked
where rank = 1
on conflict (page_key) do update
set title = excluded.title,
    position = excluded.position,
    public_visible = public.app_pages.public_visible and excluded.public_visible,
    active = true,
    updated_at = now();

-- Create a stable closing key from the newest closing slide, whatever generated
-- title an older client assigned to it.
with ranked as (
  select page.title,
         page.position,
         pg_catalog.bool_and(page.public_visible) over () as public_visible,
         row_number() over (
           order by section.updated_at desc,
                    section.version desc,
                    page.updated_at desc,
                    page.page_key
         ) as rank
  from public.app_pages page
  join public.plan_sections section
    on section.page_key = page.page_key
  where page.active
    and (
      page.page_key = 'page-closing'
      or page.page_key like 'page-nav-%'
      or page.page_key ~ '^page-[0-9]+$'
    )
    and section.content ->> 'html' like '%class="slide closing%'
)
insert into public.app_pages (
  page_key, title, position, public_visible, active
)
select 'page-closing', title, position, public_visible, true
from ranked
where rank = 1
on conflict (page_key) do update
set title = excluded.title,
    position = excluded.position,
    public_visible = public.app_pages.public_visible and excluded.public_visible,
    active = true,
    updated_at = now();

-- Copy the newest content to each stable built-in key. Existing newer stable
-- content wins; replacing older content advances the optimistic-lock version.
with mapping(page_key, title) as (
  values
    ('page-cover', 'ادارة العمليات'),
    ('page-overview', 'نظرة عامة'),
    ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
    ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
    ('page-reports-status', 'متابعة حالة التقارير'),
    ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
    ('page-people-management', 'إدارة الهيكل التنظيمي'),
    ('page-workload', 'توزيع الموظفين وأحمال العمل'),
    ('page-meetings-decisions', 'الاجتماعات والقرارات'),
    ('page-executive-dashboard', 'الداشبورد التنفيذي'),
    ('page-timeline', 'المتابعة حسب المسار الزمني'),
    ('page-calendar', 'التقويم التشغيلي'),
    ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
    ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
    ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
    ('page-resource-library', 'مكتبة القادة')
), ranked as (
  select mapping.page_key,
         section.content,
         section.version,
         section.updated_at,
         row_number() over (
           partition by mapping.page_key
           order by section.updated_at desc,
                    section.version desc,
                    page.updated_at desc,
                    page.page_key
         ) as rank
  from mapping
  join public.app_pages page
    on page.active
   and btrim(page.title) = mapping.title
   and (
     page.page_key = mapping.page_key
     or page.page_key like 'page-nav-%'
     or page.page_key ~ '^page-[0-9]+$'
   )
  join public.plan_sections section
    on section.page_key = page.page_key
)
insert into public.plan_sections as target (
  page_key, content, version, updated_at
)
select page_key, content, version, updated_at
from ranked
where rank = 1
on conflict (page_key) do update
set content = excluded.content,
    version = greatest(target.version, excluded.version) + 1,
    updated_at = now()
where target.content is distinct from excluded.content
  and (
      excluded.updated_at > target.updated_at
      or (
        excluded.updated_at = target.updated_at
        and excluded.version >= target.version
    )
  );

with ranked as (
  select section.content,
         section.version,
         section.updated_at,
         row_number() over (
           order by section.updated_at desc,
                    section.version desc,
                    page.updated_at desc,
                    page.page_key
         ) as rank
  from public.app_pages page
  join public.plan_sections section
    on section.page_key = page.page_key
  where page.active
    and (
      page.page_key = 'page-closing'
      or page.page_key like 'page-nav-%'
      or page.page_key ~ '^page-[0-9]+$'
    )
    and section.content ->> 'html' like '%class="slide closing%'
)
insert into public.plan_sections as target (
  page_key, content, version, updated_at
)
select 'page-closing', content, version, updated_at
from ranked
where rank = 1
on conflict (page_key) do update
set content = excluded.content,
    version = greatest(target.version, excluded.version) + 1,
    updated_at = now()
where target.content is distinct from excluded.content
  and (
      excluded.updated_at > target.updated_at
      or (
        excluded.updated_at = target.updated_at
        and excluded.version >= target.version
    )
  );

-- Union permissions from all semantic copies into the stable built-in keys.
with mapping(page_key, title) as (
  values
    ('page-cover', 'ادارة العمليات'),
    ('page-overview', 'نظرة عامة'),
    ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
    ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
    ('page-reports-status', 'متابعة حالة التقارير'),
    ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
    ('page-people-management', 'إدارة الهيكل التنظيمي'),
    ('page-workload', 'توزيع الموظفين وأحمال العمل'),
    ('page-meetings-decisions', 'الاجتماعات والقرارات'),
    ('page-executive-dashboard', 'الداشبورد التنفيذي'),
    ('page-timeline', 'المتابعة حسب المسار الزمني'),
    ('page-calendar', 'التقويم التشغيلي'),
    ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
    ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
    ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
    ('page-resource-library', 'مكتبة القادة')
), sources as (
  select mapping.page_key as stable_key,
         page.page_key as source_key
  from mapping
  join public.app_pages stable
    on stable.page_key = mapping.page_key
  join public.app_pages page
    on btrim(page.title) = mapping.title
   and (
     page.page_key = mapping.page_key
     or page.page_key like 'page-nav-%'
     or page.page_key ~ '^page-[0-9]+$'
   )
), merged as (
  select permission.user_id,
         sources.stable_key as page_key,
         bool_or(permission.can_view) as can_view,
         bool_or(permission.can_edit) as can_edit,
         bool_or(permission.can_create) as can_create,
         bool_or(permission.can_delete) as can_delete,
         bool_or(permission.can_assign) as can_assign
  from sources
  join public.local_page_permissions permission
    on permission.page_key = sources.source_key
  group by permission.user_id, sources.stable_key
)
insert into public.local_page_permissions (
  user_id, page_key, can_view, can_edit, can_create, can_delete, can_assign
)
select user_id,
       page_key,
       can_view or can_edit or can_create or can_delete or can_assign,
       can_edit,
       can_create,
       can_delete,
       can_assign
from merged
on conflict (user_id, page_key) do update
set can_view = public.local_page_permissions.can_view or excluded.can_view,
    can_edit = public.local_page_permissions.can_edit or excluded.can_edit,
    can_create = public.local_page_permissions.can_create or excluded.can_create,
    can_delete = public.local_page_permissions.can_delete or excluded.can_delete,
    can_assign = public.local_page_permissions.can_assign or excluded.can_assign;

with closing_sources as (
  select page.page_key
  from public.app_pages page
  join public.plan_sections section
    on section.page_key = page.page_key
  where exists (
      select 1
      from public.app_pages stable
      where stable.page_key = 'page-closing'
    )
    and (
      page.page_key = 'page-closing'
      or page.page_key like 'page-nav-%'
      or page.page_key ~ '^page-[0-9]+$'
    )
    and section.content ->> 'html' like '%class="slide closing%'
), merged as (
  select permission.user_id,
         bool_or(permission.can_view) as can_view,
         bool_or(permission.can_edit) as can_edit,
         bool_or(permission.can_create) as can_create,
         bool_or(permission.can_delete) as can_delete,
         bool_or(permission.can_assign) as can_assign
  from closing_sources
  join public.local_page_permissions permission
    on permission.page_key = closing_sources.page_key
  group by permission.user_id
)
insert into public.local_page_permissions (
  user_id, page_key, can_view, can_edit, can_create, can_delete, can_assign
)
select user_id,
       'page-closing',
       can_view or can_edit or can_create or can_delete or can_assign,
       can_edit,
       can_create,
       can_delete,
       can_assign
from merged
on conflict (user_id, page_key) do update
set can_view = public.local_page_permissions.can_view or excluded.can_view,
    can_edit = public.local_page_permissions.can_edit or excluded.can_edit,
    can_create = public.local_page_permissions.can_create or excluded.can_create,
    can_delete = public.local_page_permissions.can_delete or excluded.can_delete,
    can_assign = public.local_page_permissions.can_assign or excluded.can_assign;

-- Archive only non-stable copies of mapped built-ins and semantic closing slides.
with mapping(page_key, title) as (
  values
    ('page-cover', 'ادارة العمليات'),
    ('page-overview', 'نظرة عامة'),
    ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
    ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
    ('page-reports-status', 'متابعة حالة التقارير'),
    ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
    ('page-people-management', 'إدارة الهيكل التنظيمي'),
    ('page-workload', 'توزيع الموظفين وأحمال العمل'),
    ('page-meetings-decisions', 'الاجتماعات والقرارات'),
    ('page-executive-dashboard', 'الداشبورد التنفيذي'),
    ('page-timeline', 'المتابعة حسب المسار الزمني'),
    ('page-calendar', 'التقويم التشغيلي'),
    ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
    ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
    ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
    ('page-resource-library', 'مكتبة القادة')
)
update public.app_pages page
set active = false,
    updated_at = now()
from mapping
where page.active
  and btrim(page.title) = mapping.title
  and (
    page.page_key = mapping.page_key
    or page.page_key like 'page-nav-%'
    or page.page_key ~ '^page-[0-9]+$'
  )
  and page.page_key <> mapping.page_key;

update public.app_pages page
set active = false,
    updated_at = now()
from public.plan_sections section
where page.active
  and page.page_key = section.page_key
  and (
    page.page_key = 'page-closing'
    or page.page_key like 'page-nav-%'
    or page.page_key ~ '^page-[0-9]+$'
  )
  and page.page_key <> 'page-closing'
  and section.content ->> 'html' like '%class="slide closing%';

with mapping(page_key, title) as (
  values
    ('page-cover', 'ادارة العمليات'),
    ('page-overview', 'نظرة عامة'),
    ('page-organization-overview', 'أعداد وأسماء الموظفين حسب الهيكل التنظيمي'),
    ('page-visits-current', 'الوضع الراهن للزيارات - لوحة متابعة المناطق'),
    ('page-reports-status', 'متابعة حالة التقارير'),
    ('page-tasks-paths', 'المهام والمسارات التشغيلية'),
    ('page-people-management', 'إدارة الهيكل التنظيمي'),
    ('page-workload', 'توزيع الموظفين وأحمال العمل'),
    ('page-meetings-decisions', 'الاجتماعات والقرارات'),
    ('page-executive-dashboard', 'الداشبورد التنفيذي'),
    ('page-timeline', 'المتابعة حسب المسار الزمني'),
    ('page-calendar', 'التقويم التشغيلي'),
    ('page-responsibilities', 'توزيع المسؤوليات حسب الموظفين'),
    ('page-outputs', 'المخرجات المستهدفة بنهاية الفترة'),
    ('page-challenges', 'أبرز التحديات المحتملة والحلول المقترحة'),
    ('page-resource-library', 'مكتبة القادة')
)
delete from public.local_page_permissions permission
using public.app_pages page,
      mapping
where permission.page_key = page.page_key
  and btrim(page.title) = mapping.title
  and (
    page.page_key = mapping.page_key
    or page.page_key like 'page-nav-%'
    or page.page_key ~ '^page-[0-9]+$'
  )
  and page.page_key <> mapping.page_key;

delete from public.local_page_permissions permission
using public.app_pages page,
      public.plan_sections section
where permission.page_key = page.page_key
  and section.page_key = page.page_key
  and (
    page.page_key = 'page-closing'
    or page.page_key like 'page-nav-%'
    or page.page_key ~ '^page-[0-9]+$'
  )
  and page.page_key <> 'page-closing'
  and section.content ->> 'html' like '%class="slide closing%';

with ranked as (
  select page_key,
         row_number() over (order by position, updated_at, page_key) - 1 as next_position
  from public.app_pages
  where active
)
update public.app_pages page
set position = ranked.next_position,
    updated_at = now()
from ranked
where page.page_key = ranked.page_key
  and page.position is distinct from ranked.next_position;

revoke all on function public.app_admin_register_pages(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.app_admin_register_pages(text, jsonb) to anon, authenticated;
