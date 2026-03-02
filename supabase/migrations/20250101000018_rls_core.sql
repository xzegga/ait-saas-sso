-- ==============================================================================
-- 018 - RLS CORE (enable RLS + policies with (select ...) for performance)
-- ==============================================================================

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.org_members enable row level security;
alter table public.org_product_subscriptions enable row level security;
alter table public.products enable row level security;
alter table public.product_role_definitions enable row level security;
alter table public.entitlements enable row level security;
alter table public.plans enable row level security;
alter table public.plan_entitlements enable row level security;
alter table public.product_plans enable row level security;
alter table public.member_product_roles enable row level security;
alter table public.org_invitations enable row level security;
alter table public.super_admins enable row level security;
alter table public.role_templates enable row level security;
alter table public.recycle_bin enable row level security;

create policy "Select Orgs" on public.organizations for select to authenticated
  using ((select public.is_super_admin()) or id = (select public.get_my_org_id()));

create policy "Update Orgs" on public.organizations for update to authenticated
  using ((select public.is_super_admin()) or (id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'));

create policy "Insert Orgs" on public.organizations for insert to authenticated
  with check ((select public.is_super_admin()));

create policy "Delete Orgs" on public.organizations for delete to authenticated
  using ((select public.is_super_admin()));

create policy "View Members" on public.org_members for select to authenticated
  using ((select public.is_super_admin()) or org_id = (select public.get_my_org_id()));

create policy "Manage Members" on public.org_members for all to authenticated
  using ((select public.is_super_admin()) or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'));

create policy "Read Profiles" on public.profiles for select to authenticated
  using ((select auth.uid()) = id or (select public.is_super_admin()));

create policy "Insert Profiles" on public.profiles for insert to authenticated
  with check ((select public.is_super_admin()));

create policy "Update Profiles" on public.profiles for update to authenticated
  using ((select auth.uid()) = id or (select public.is_super_admin()))
  with check ((select auth.uid()) = id or (select public.is_super_admin()));

create policy "View Invites" on public.org_invitations for select to authenticated
  using ((select public.is_super_admin()) or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'));

create policy "Manage Invites" on public.org_invitations for all to authenticated
  using ((select public.is_super_admin()) or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'));

create policy "Public Read Products" on public.products for select to authenticated using (true);
create policy "Manage Products" on public.products for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy "Public Read Role Definitions" on public.product_role_definitions for select to authenticated using (true);
create policy "Manage Role Definitions" on public.product_role_definitions for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy "Public Read Entitlements" on public.entitlements for select to authenticated using (deleted_at is null);
create policy "Insert Entitlements" on public.entitlements for insert to authenticated with check ((select public.is_super_admin()));
create policy "Update Entitlements" on public.entitlements for update to authenticated
  using ((select public.is_super_admin()) and deleted_at is null)
  with check ((select public.is_super_admin()));
create policy "Delete Entitlements" on public.entitlements for delete to authenticated using ((select public.is_super_admin()));

create policy "Public Read Plans" on public.plans for select to authenticated using (deleted_at is null);
create policy "Insert Plans" on public.plans for insert to authenticated with check ((select public.is_super_admin()));
create policy "Update Plans" on public.plans for update to authenticated
  using ((select public.is_super_admin()) and deleted_at is null)
  with check ((select public.is_super_admin()));
create policy "Delete Plans" on public.plans for delete to authenticated using ((select public.is_super_admin()));

create policy "Public Read Plan Entitlements" on public.plan_entitlements for select to authenticated using (true);
create policy "Insert Plan Entitlements" on public.plan_entitlements for insert to authenticated with check ((select public.is_super_admin()));
create policy "Update Plan Entitlements" on public.plan_entitlements for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));
create policy "Delete Plan Entitlements" on public.plan_entitlements for delete to authenticated using ((select public.is_super_admin()));

create policy "Public Read Product Plans" on public.product_plans for select to authenticated using (deleted_at is null);
create policy "Insert Product Plans" on public.product_plans for insert to authenticated with check ((select public.is_super_admin()));
create policy "Update Product Plans" on public.product_plans for update to authenticated
  using ((select public.is_super_admin()) and deleted_at is null)
  with check ((select public.is_super_admin()));
create policy "Delete Product Plans" on public.product_plans for delete to authenticated using ((select public.is_super_admin()));

create policy "View Member Roles" on public.member_product_roles for select to authenticated
  using (
    (select public.is_super_admin()) or
    exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = (select public.get_my_org_id()))
  );

create policy "Manage Member Roles" on public.member_product_roles for all to authenticated
  using (
    (select public.is_super_admin()) or
    (exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = (select public.get_my_org_id())) and (select public.get_my_role()) = 'Owner')
  )
  with check (
    (select public.is_super_admin()) or
    (exists (select 1 from public.org_members om where om.id = member_product_roles.member_id and om.org_id = (select public.get_my_org_id())) and (select public.get_my_role()) = 'Owner')
  );

create policy "View Subscriptions" on public.org_product_subscriptions for select to authenticated
  using ((select public.is_super_admin()) or org_id = (select public.get_my_org_id()));

create policy "Manage Subscriptions" on public.org_product_subscriptions for all to authenticated
  using ((select public.is_super_admin()) or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'))
  with check ((select public.is_super_admin()) or (org_id = (select public.get_my_org_id()) and (select public.get_my_role()) = 'Owner'));

create policy "View Super Admins" on public.super_admins for select to authenticated
  using ((select public.is_super_admin()));

create policy "Manage Super Admins" on public.super_admins for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy "View Role Templates" on public.role_templates for select to authenticated
  using ((select public.is_super_admin()));

create policy "Manage Role Templates" on public.role_templates for all to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

create policy recycle_bin_select_super_admin on public.recycle_bin for select using ((select public.is_super_admin()));
create policy recycle_bin_insert_super_admin on public.recycle_bin for insert with check ((select public.is_super_admin()));
create policy recycle_bin_update_super_admin on public.recycle_bin for update
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));
create policy recycle_bin_delete_super_admin on public.recycle_bin for delete using ((select public.is_super_admin()));
