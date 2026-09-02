-- Applied migration version: 20260901074251.
-- Keep active presentation pages in a deterministic, gap-free order.
with ranked as (
  select
    page_key,
    row_number() over (
      order by position, updated_at, page_key
    ) - 1 as normalized_position
  from public.app_pages
  where active
)
update public.app_pages as page
set
  position = ranked.normalized_position,
  updated_at = now()
from ranked
where page.page_key = ranked.page_key
  and page.position is distinct from ranked.normalized_position;

-- Cover foreign-key lookups used by sessions, page permissions and audit data.
create index if not exists local_sessions_user_id_idx
  on private.local_sessions (user_id);

create index if not exists local_page_permissions_page_key_idx
  on public.local_page_permissions (page_key);

create index if not exists operating_scope_state_updated_by_idx
  on public.operating_scope_state (updated_by);
