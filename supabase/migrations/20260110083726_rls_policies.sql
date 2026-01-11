-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.org_members enable row level security;
alter table public.org_product_subscriptions enable row level security;
alter table public.products enable row level security;
alter table public.product_plans enable row level security;
alter table public.product_role_definitions enable row level security;
alter table public.product_features enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.member_product_roles enable row level security;
alter table public.org_invitations enable row level security;
alter table public.super_admins enable row level security;

-- ====================== ORGANIZATIONS ======================
create policy "Select Orgs" on public.organizations for select to authenticated
  using (public.is_super_admin() or id = public.get_my_org_id());

create policy "Update Orgs" on public.organizations for update to authenticated
  using (public.is_super_admin() or (id = public.get_my_org_id() and public.get_my_role() = 'Owner'));

create policy "Insert Orgs" on public.organizations for insert to authenticated
  with check (public.is_super_admin()); -- Regular users create orgs via Trigger only

create policy "Delete Orgs" on public.organizations for delete to authenticated
  using (public.is_super_admin());

-- ====================== MEMBERS ======================
create policy "View Members" on public.org_members for select to authenticated
  using (public.is_super_admin() or org_id = public.get_my_org_id());

create policy "Manage Members" on public.org_members for all to authenticated
  using (public.is_super_admin() or (org_id = public.get_my_org_id() and public.get_my_role() = 'Owner'));

-- ====================== PROFILES ======================
-- Profiles: Users can read/update their own, Super Admin can do everything
-- Note: Profiles are normally created automatically by handle_new_user trigger,
-- but Super Admin can create manually if needed. DELETE is not allowed here
-- (profiles are deleted via CASCADE when auth.users are deleted).
create policy "Read Profiles" on public.profiles for select to authenticated
  using (auth.uid() = id or public.is_super_admin());

create policy "Insert Profiles" on public.profiles for insert to authenticated
  with check (public.is_super_admin()); -- Normally created by trigger, but Super Admin can create manually

create policy "Update Profiles" on public.profiles for update to authenticated
  using (auth.uid() = id or public.is_super_admin())
  with check (auth.uid() = id or public.is_super_admin());

-- ====================== INVITATIONS ======================
create policy "View Invites" on public.org_invitations for select to authenticated
  using (public.is_super_admin() or (org_id = public.get_my_org_id() and public.get_my_role() = 'Owner'));

create policy "Manage Invites" on public.org_invitations for all to authenticated
  using (public.is_super_admin() or (org_id = public.get_my_org_id() and public.get_my_role() = 'Owner'));

-- ====================== PRODUCTS (Configuration Tables - Super Admin Only) ======================
-- Products: Public read, Super Admin full CRUD
create policy "Public Read Products" on public.products for select to authenticated using (true);
create policy "Manage Products" on public.products for all to authenticated 
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Product Plans: Public read, Super Admin full CRUD
create policy "Public Read Plans" on public.product_plans for select to authenticated using (true);
create policy "Insert Product Plans" on public.product_plans for insert to authenticated
  with check (public.is_super_admin());
create policy "Update Product Plans" on public.product_plans for update to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());
create policy "Delete Product Plans" on public.product_plans for delete to authenticated
  using (public.is_super_admin());

-- Product Role Definitions: Public read, Super Admin full CRUD
create policy "Public Read Role Definitions" on public.product_role_definitions for select to authenticated using (true);
create policy "Manage Role Definitions" on public.product_role_definitions for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Product Features: Public read, Super Admin full CRUD
create policy "Public Read Features" on public.product_features for select to authenticated using (true);
create policy "Manage Features" on public.product_features for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Plan Entitlements: Public read, Super Admin full CRUD
create policy "Public Read Entitlements" on public.plan_entitlements for select to authenticated using (true);
create policy "Manage Entitlements" on public.plan_entitlements for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Member Product Roles: Super Admin full access, Owner can manage roles in their org
create policy "View Member Roles" on public.member_product_roles for select to authenticated
  using (
    public.is_super_admin() or 
    exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = public.get_my_org_id())
  );

create policy "Manage Member Roles" on public.member_product_roles for all to authenticated
  using (
    public.is_super_admin() or 
    (exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = public.get_my_org_id()) and public.get_my_role() = 'Owner')
  )
  with check (
    public.is_super_admin() or 
    (exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = public.get_my_org_id()) and public.get_my_role() = 'Owner')
  );

-- ====================== PRODUCT SUBSCRIPTIONS ======================
-- Org Product Subscriptions: Super Admin full access, Owner can view their org's subscriptions
create policy "View Subscriptions" on public.org_product_subscriptions for select to authenticated
  using (public.is_super_admin() or org_id = public.get_my_org_id());

create policy "Manage Subscriptions" on public.org_product_subscriptions for all to authenticated
  using (public.is_super_admin() or (org_id = public.get_my_org_id() and public.get_my_role() = 'Owner'))
  with check (public.is_super_admin() or (org_id = public.get_my_org_id() and public.get_my_role() = 'Owner'));

-- ====================== SUPER ADMINS (Meta Table - Super Admin Only) ======================
-- Super Admins: Only super admins can view and manage the whitelist
create policy "View Super Admins" on public.super_admins for select to authenticated
  using (public.is_super_admin());

create policy "Manage Super Admins" on public.super_admins for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());