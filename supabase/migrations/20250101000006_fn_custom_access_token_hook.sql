-- ==============================================================================
-- JWT CUSTOM CLAIMS HOOK FUNCTION
-- ==============================================================================
-- Function to inject custom claims into JWT tokens during authentication
-- ==============================================================================

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
  _active_plan text;
  _features jsonb;
  _system_role text;
begin
  _user_id := (event->>'user_id')::uuid;

  -- Get system role from profile
  select role into _system_role from public.profiles where id = _user_id;

  -- Get active org
  select org_id into _active_org_id from public.org_members 
  where user_id = _user_id and status = 'active' limit 1;

  -- If has org, get role, plan and features
  if _active_org_id is not null then
    -- Get product role
    select prd.role_name into _active_role
    from public.member_product_roles mpr
    join public.product_role_definitions prd on mpr.role_definition_id = prd.id
    join public.org_members om on mpr.member_id = om.id
    where om.user_id = _user_id and om.org_id = _active_org_id limit 1;

    -- Get plan and features (using new entitlements structure)
    select 
      pl.name, 
      coalesce(
        ops.custom_entitlements, 
        coalesce(
          (
            select jsonb_object_agg(e.key, pe.value_text)
            from public.plan_entitlements pe
            join public.entitlements e on pe.entitlement_id = e.id
            where pe.plan_id = ops.plan_id
          ),
          '{}'::jsonb
        )
      )
    into _active_plan, _features
    from public.org_product_subscriptions ops
    join public.plans pl on ops.plan_id = pl.id
    where ops.org_id = _active_org_id
      and ops.status = 'active'
    limit 1;
  end if;

  -- Build Token
  claims := coalesce(event->'claims', '{}'::jsonb);
  if jsonb_typeof(claims->'app_metadata') is null then 
    claims := jsonb_set(claims, '{app_metadata}', '{}'::jsonb); 
  end if;

  -- Always inject system_role
  claims := jsonb_set(claims, '{app_metadata, system_role}', to_jsonb(coalesce(_system_role, 'user')));

  -- Inject org-related claims if org exists
  if _active_org_id is not null then
    claims := jsonb_set(claims, '{app_metadata, org_id}', to_jsonb(_active_org_id));
    claims := jsonb_set(claims, '{app_metadata, role}', to_jsonb(coalesce(_active_role, 'Member')));
    
    if _active_plan is not null then
      claims := jsonb_set(claims, '{app_metadata, plan}', to_jsonb(_active_plan));
    end if;
    
    if _features is not null and _features != '{}'::jsonb then
      claims := jsonb_set(claims, '{app_metadata, features}', _features);
    end if;
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

-- Permisos necesarios para que el sistema de Auth ejecute esto
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;
