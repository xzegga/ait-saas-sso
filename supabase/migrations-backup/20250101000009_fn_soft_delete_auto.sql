-- ==============================================================================
-- SOFT DELETE AUTO FUNCTION
-- ==============================================================================
-- Improved soft delete function that automatically gets the display name
-- ==============================================================================

create or replace function public.fn_soft_delete_auto(
  p_table_name text,
  p_entity_id uuid,
  p_deleted_by_id uuid,
  p_deleted_by_name text,
  p_reason text default null
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  v_display_name := public.fn_get_entity_display_name(p_table_name, p_entity_id);
  
  return public.fn_soft_delete(
    p_table_name,
    p_entity_id,
    v_display_name,
    p_deleted_by_id,
    p_deleted_by_name,
    p_reason
  );
end;
$$;

grant execute on function public.fn_soft_delete_auto(text, uuid, uuid, text, text) to authenticated;

comment on function public.fn_soft_delete_auto is 'Función mejorada de soft delete que obtiene automáticamente el display name de la entidad.';
