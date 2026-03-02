-- ==============================================================================
-- 027 - RLS: allow users to read own org_members + read orgs they belong to (when JWT has no org_id)
-- ==============================================================================

-- So useOrganization() can resolve org_id from org_members when app_metadata.org_id is missing (e.g. token before refresh)
create policy "View own memberships" on public.org_members for select to authenticated
  using ((select auth.uid()) = user_id);

-- Allow reading organization row when user is a member (needed when JWT has no org_id; get_my_org_id() is null so "Select Orgs" would block)
create policy "Select orgs where member" on public.organizations for select to authenticated
  using (
    exists (
      select 1 from public.org_members om
      where om.org_id = organizations.id and om.user_id = (select auth.uid())
    )
  );
