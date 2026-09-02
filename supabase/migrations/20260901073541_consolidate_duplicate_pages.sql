-- Migration version matches the applied Supabase history.
-- Preserve the newest section for every repeated title, migrate permissions,
-- and keep older rows as inactive history instead of deleting content.
with ranked as (
  select p.page_key,
         first_value(p.page_key) over (
           partition by p.title
           order by s.updated_at desc nulls last, s.version desc nulls last, p.updated_at desc, p.page_key
         ) as canonical_key
  from public.app_pages p
  left join public.plan_sections s on s.page_key = p.page_key
  where p.active
), merged as (
  select permission.user_id,
         ranked.canonical_key as page_key,
         bool_or(permission.can_view) as can_view,
         bool_or(permission.can_edit) as can_edit,
         bool_or(permission.can_create) as can_create,
         bool_or(permission.can_delete) as can_delete,
         bool_or(permission.can_assign) as can_assign
  from public.local_page_permissions permission
  join ranked on ranked.page_key = permission.page_key
  group by permission.user_id, ranked.canonical_key
)
insert into public.local_page_permissions (
  user_id, page_key, can_view, can_edit, can_create, can_delete, can_assign
)
select user_id, page_key,
       can_view or can_edit or can_create or can_delete or can_assign,
       can_edit, can_create, can_delete, can_assign
from merged
on conflict (user_id, page_key) do update
set can_view = public.local_page_permissions.can_view or excluded.can_view,
    can_edit = public.local_page_permissions.can_edit or excluded.can_edit,
    can_create = public.local_page_permissions.can_create or excluded.can_create,
    can_delete = public.local_page_permissions.can_delete or excluded.can_delete,
    can_assign = public.local_page_permissions.can_assign or excluded.can_assign;

with ranked as (
  select p.page_key, p.position, p.public_visible,
         first_value(p.page_key) over (
           partition by p.title
           order by s.updated_at desc nulls last, s.version desc nulls last, p.updated_at desc, p.page_key
         ) as canonical_key
  from public.app_pages p
  left join public.plan_sections s on s.page_key = p.page_key
  where p.active
), consolidated as (
  select canonical_key, position, public_visible
  from ranked
  where page_key = canonical_key
)
update public.app_pages page
set position = consolidated.position,
    public_visible = consolidated.public_visible,
    updated_at = now()
from consolidated
where page.page_key = consolidated.canonical_key;

with ranked as (
  select p.page_key,
         first_value(p.page_key) over (
           partition by p.title
           order by s.updated_at desc nulls last, s.version desc nulls last, p.updated_at desc, p.page_key
         ) as canonical_key
  from public.app_pages p
  left join public.plan_sections s on s.page_key = p.page_key
  where p.active
)
update public.app_pages page
set active = false,
    updated_at = now()
from ranked
where page.page_key = ranked.page_key
  and ranked.page_key <> ranked.canonical_key;

update public.local_page_permissions
set can_view = true
where can_edit or can_create or can_delete or can_assign;
