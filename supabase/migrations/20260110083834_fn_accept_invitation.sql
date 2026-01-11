-- 1. ACCEPT INVITATION FUNCTION
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