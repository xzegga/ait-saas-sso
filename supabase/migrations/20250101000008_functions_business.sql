-- ==============================================================================
-- BUSINESS FUNCTIONS
-- ==============================================================================
-- Core business logic functions
-- ==============================================================================

-- ====================== ACCEPT INVITATION FUNCTION ======================
-- Function to accept organization invitations
create or replace function public.accept_invitation(lookup_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite_record record;
  user_id uuid;
  user_email text;
  default_product_id uuid;
  target_role_id uuid;
begin
  user_id := auth.uid();
  user_email := auth.jwt() ->> 'email';

  -- Validation
  if user_id is null then return jsonb_build_object('error', 'Not authenticated'); end if;

  select * into invite_record from public.org_invitations where token = lookup_token and status = 'pending';
  if invite_record.id is null then return jsonb_build_object('error', 'Invalid token'); end if;

  if lower(invite_record.email) != lower(user_email) then
     return jsonb_build_object('error', 'Email mismatch');
  end if;

  if invite_record.expires_at < now() then
    update public.org_invitations set status = 'expired' where id = invite_record.id;
    return jsonb_build_object('error', 'Expired token');
  end if;

  -- Execution
  insert into public.org_members (org_id, user_id, status)
  values (invite_record.org_id, user_id, 'active')
  on conflict (org_id, user_id) do update set status = 'active';

  -- Assign Role (Simplified logic for Core Product)
  select id into default_product_id from public.products where client_id = 'prod_core_system' limit 1;
  
  -- Find role definition matching invite role, or default to Member
  select id into target_role_id from public.product_role_definitions 
  where product_id = default_product_id and lower(role_name) = lower(invite_record.role) limit 1;

  if target_role_id is null then
    select id into target_role_id from public.product_role_definitions where product_id = default_product_id and role_name = 'Member' limit 1;
  end if;

  insert into public.member_product_roles (member_id, product_id, role_definition_id)
  select id, default_product_id, target_role_id
  from public.org_members
  where org_id = invite_record.org_id and user_id = user_id
  on conflict (member_id, product_id) do update set role_definition_id = target_role_id;

  update public.org_invitations set status = 'accepted' where id = invite_record.id;
  return jsonb_build_object('success', true, 'org_id', invite_record.org_id);
end;
$$;

grant execute on function public.accept_invitation(uuid) to authenticated;

comment on function public.accept_invitation is 'Function to accept organization invitations';

-- ====================== JWT CUSTOM CLAIMS HOOK FUNCTION ======================
-- Function to inject custom claims into JWT tokens during authentication
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
    -- Only include subscriptions that are active or valid (non-expired) trials
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
      and (
        ops.status = 'active' 
        or (
          ops.status = 'trial' 
          and (ops.trial_ends_at IS NULL OR ops.trial_ends_at > now())
        )
      )
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

-- Permissions needed for Auth system to execute this
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

comment on function public.custom_access_token_hook is 'Function to inject custom claims into JWT tokens during authentication';

-- ====================== GET ENTITY DISPLAY NAME FUNCTION ======================
-- Helper function to get a human-readable display name for an entity
-- Used by recycle bin functions
create or replace function public.fn_get_entity_display_name(
  p_table_name text,
  p_entity_id uuid
) returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  case p_table_name
    when 'products' then
      select name into v_display_name from public.products where id = p_entity_id;
    when 'plans' then
      select name into v_display_name from public.plans where id = p_entity_id;
    when 'entitlements' then
      select key into v_display_name from public.entitlements where id = p_entity_id;
    when 'product_plans' then
      -- For product_plans, show product name + plan name
      select p.name || ' - ' || pl.name into v_display_name
      from public.product_plans pp
      join public.products p on pp.product_id = p.id
      join public.plans pl on pp.plan_id = pl.id
      where pp.id = p_entity_id;
    when 'organizations' then
      select name into v_display_name from public.organizations where id = p_entity_id;
    when 'profiles' then
      select coalesce(full_name, email, 'User') into v_display_name from public.profiles where id = p_entity_id;
    when 'product_role_definitions' then
      select role_name into v_display_name from public.product_role_definitions where id = p_entity_id;
    else
      v_display_name := p_entity_id::text;
  end case;
  
  return coalesce(v_display_name, 'Unknown');
end;
$$;

grant execute on function public.fn_get_entity_display_name(text, uuid) to authenticated;

comment on function public.fn_get_entity_display_name is 'Helper function to get a human-readable display name for an entity. Used by recycle bin functions.';
