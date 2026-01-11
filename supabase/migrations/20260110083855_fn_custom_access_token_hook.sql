-- 2. JWT CUSTOM CLAIMS HOOK
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  claims jsonb;
  _user_id uuid;
  _active_org_id uuid;
  _active_role text;
  _system_role text;
begin
  _user_id := (event->>'user_id')::uuid;

  -- Get Data
  select role into _system_role from public.profiles where id = _user_id;

  select org_id into _active_org_id from public.org_members 
  where user_id = _user_id and status = 'active' limit 1;

  if _active_org_id is not null then
    select prd.role_name into _active_role
    from public.member_product_roles mpr
    join public.product_role_definitions prd on mpr.role_definition_id = prd.id
    join public.org_members om on mpr.member_id = om.id
    where om.user_id = _user_id and om.org_id = _active_org_id limit 1;
  end if;

  -- Build Token
  claims := coalesce(event->'claims', '{}'::jsonb);
  if jsonb_typeof(claims->'app_metadata') is null then claims := jsonb_set(claims, '{app_metadata}', '{}'::jsonb); end if;

  claims := jsonb_set(claims, '{app_metadata, system_role}', to_jsonb(coalesce(_system_role, 'user')));

  if _active_org_id is not null then
    claims := jsonb_set(claims, '{app_metadata, org_id}', to_jsonb(_active_org_id));
    claims := jsonb_set(claims, '{app_metadata, role}', to_jsonb(coalesce(_active_role, 'Member')));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;