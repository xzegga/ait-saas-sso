-- ==============================================================================
-- TRIGGERS
-- ==============================================================================
-- All database triggers consolidated in one file
-- ==============================================================================

-- Automatic timestamp updates
create trigger handle_updated_at before update on public.organizations
  for each row execute procedure moddatetime (updated_at);

create trigger handle_updated_at before update on public.profiles
  for each row execute procedure moddatetime (updated_at);

create trigger handle_entitlements_updated_at before update on public.entitlements
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_plans_updated_at before update on public.plans
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_product_plans_updated_at before update on public.product_plans
  for each row execute procedure public.moddatetime(updated_at);

create trigger handle_updated_at before update on public.role_templates
  for each row execute procedure moddatetime (updated_at);

-- Trigger for recycle_bin updated_at
create trigger handle_recycle_bin_updated_at 
  before update on public.recycle_bin
  for each row 
  execute procedure moddatetime(updated_at);
