-- RLS Policies for role_templates table
-- Only super_admin can view and manage role templates

create policy "View Role Templates" on public.role_templates for select to authenticated
  using (public.is_super_admin());

create policy "Manage Role Templates" on public.role_templates for all to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());
