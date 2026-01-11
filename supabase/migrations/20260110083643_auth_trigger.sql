-- Function to handle new user registration
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
  default_product_id uuid;
  default_plan_id uuid;
  owner_role_id uuid;
  user_role text;
begin
  -- 1. Determine Global Role (Check Whitelist)
  if exists (select 1 from public.super_admins where lower(email) = lower(new.email)) then
    user_role := 'super_admin';
    raise log 'HandleNewUser: Assigned super_admin to %', new.email;
  else
    user_role := 'user';
  end if;

  -- 2. Create Profile
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', user_role);

  -- 3. Get SaaS Config (Seed Data)
  select id into default_product_id from public.products where client_id = 'prod_core_system' limit 1;
  
  if default_product_id is null then
    raise warning 'HandleNewUser: Product config missing. User % created without Org.', new.id;
    return new;
  end if;

  select id into default_plan_id from public.product_plans 
  where product_id = default_product_id and name = 'Free Tier' limit 1;

  select id into owner_role_id from public.product_role_definitions 
  where product_id = default_product_id and role_name = 'Owner' limit 1;

  -- 4. Create Personal Organization
  insert into public.organizations (name, billing_email)
  values (coalesce(new.raw_user_meta_data->>'full_name', new.email) || '''s Org', new.email)
  returning id into new_org_id;

  -- 5. Setup Subscription & Membership
  insert into public.org_product_subscriptions (org_id, product_id, plan_id, status, quantity)
  values (new_org_id, default_product_id, default_plan_id, 'active', 1);

  insert into public.org_members (org_id, user_id, status)
  values (new_org_id, new.id, 'active');

  insert into public.member_product_roles (member_id, product_id, role_definition_id)
  select id, default_product_id, owner_role_id
  from public.org_members
  where org_id = new_org_id and user_id = new.id;

  return new;
end;
$$;

-- Connect the Trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();