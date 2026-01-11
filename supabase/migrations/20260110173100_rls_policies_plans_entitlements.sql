-- ==============================================================================
-- RLS POLICIES FOR PLANS & ENTITLEMENTS
-- ==============================================================================

-- Entitlements: Public read, Super Admin full CRUD
create policy "Public Read Entitlements" on public.entitlements for select 
  to authenticated using (deleted_at is null);

create policy "Insert Entitlements" on public.entitlements for insert 
  to authenticated with check (public.is_super_admin());

create policy "Update Entitlements" on public.entitlements for update 
  to authenticated 
  using (public.is_super_admin() and deleted_at is null)
  with check (public.is_super_admin());

create policy "Delete Entitlements" on public.entitlements for delete 
  to authenticated using (public.is_super_admin());

-- Plans: Public read, Super Admin full CRUD
create policy "Public Read Plans" on public.plans for select 
  to authenticated using (deleted_at is null);

create policy "Insert Plans" on public.plans for insert 
  to authenticated with check (public.is_super_admin());

create policy "Update Plans" on public.plans for update 
  to authenticated 
  using (public.is_super_admin() and deleted_at is null)
  with check (public.is_super_admin());

create policy "Delete Plans" on public.plans for delete 
  to authenticated using (public.is_super_admin());

-- Plan Entitlements: Public read, Super Admin full CRUD
create policy "Public Read Plan Entitlements" on public.plan_entitlements for select 
  to authenticated using (true);

create policy "Insert Plan Entitlements" on public.plan_entitlements for insert 
  to authenticated with check (public.is_super_admin());

create policy "Update Plan Entitlements" on public.plan_entitlements for update 
  to authenticated 
  using (public.is_super_admin())
  with check (public.is_super_admin());

create policy "Delete Plan Entitlements" on public.plan_entitlements for delete 
  to authenticated using (public.is_super_admin());

-- Product Plans: Public read, Super Admin full CRUD
create policy "Public Read Product Plans" on public.product_plans for select 
  to authenticated using (deleted_at is null);

create policy "Insert Product Plans" on public.product_plans for insert 
  to authenticated with check (public.is_super_admin());

create policy "Update Product Plans" on public.product_plans for update 
  to authenticated 
  using (public.is_super_admin() and deleted_at is null)
  with check (public.is_super_admin());

create policy "Delete Product Plans" on public.product_plans for delete 
  to authenticated using (public.is_super_admin());
