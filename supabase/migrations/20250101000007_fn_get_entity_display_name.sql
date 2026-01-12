-- ==============================================================================
-- GET ENTITY DISPLAY NAME FUNCTION
-- ==============================================================================
-- Helper function to get a human-readable display name for an entity
-- Used by recycle bin functions
-- ==============================================================================

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

comment on function public.fn_get_entity_display_name is 'Función helper para obtener el nombre legible de una entidad según su tipo.';
