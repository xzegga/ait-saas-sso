-- ==============================================================================
-- UPDATE RECYCLE BIN FUNCTIONS FOR NEW PLANS & ENTITLEMENTS STRUCTURE
-- ==============================================================================

-- Update fn_get_entity_display_name to handle new tables
create or replace function public.fn_get_entity_display_name(
  p_table_name text,
  p_entity_id uuid
) returns text
language plpgsql
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
    else
      v_display_name := p_entity_id::text;
  end case;
  
  return coalesce(v_display_name, 'Unknown');
end;
$$;

-- Update comment
comment on column public.recycle_bin.entity_type is 'Tipo de entidad eliminada (e.g., products, plans, entitlements, product_plans, organizations, profiles)';
