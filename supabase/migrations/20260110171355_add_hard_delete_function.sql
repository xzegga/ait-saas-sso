-- ==============================================================================
-- FUNCIÓN PARA HARD DELETE (BORRADO PERMANENTE)
-- ==============================================================================

-- Función para hard delete que borra el registro original pero mantiene la referencia en recycle_bin
create or replace function public.fn_hard_delete_entity(
  p_recycle_bin_id bigint,
  p_deleted_by_id uuid,
  p_deleted_by_name text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record record;
  v_deleted_count int;
begin
  -- Verificar que el usuario es super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform hard delete operations';
  end if;
  
  -- Obtener información del registro en recycle_bin
  select entity_type, entity_id, can_restore, restored_at
  into v_record
  from public.recycle_bin
  where id = p_recycle_bin_id;
  
  if not found then
    raise exception 'Recycle bin entry with id % not found', p_recycle_bin_id;
  end if;
  
  -- Verificar que no esté restaurado
  if v_record.restored_at is not null then
    raise exception 'Cannot hard delete a restored entity';
  end if;
  
  -- Borrar el registro original de la tabla correspondiente
  begin
    execute format(
      'delete from public.%I where id = $1',
      v_record.entity_type
    ) using v_record.entity_id::uuid;
    
    get diagnostics v_deleted_count = row_count;
  exception
    when invalid_text_representation then
      raise exception 'Invalid UUID format for entity_id: %', v_record.entity_id;
    when others then
      -- Si el registro ya no existe, continuar (puede haber sido borrado manualmente)
      raise notice 'Entity not found in table % (may have been already deleted): %', v_record.entity_type, sqlerrm;
      v_deleted_count := 0;
  end;
  
  -- Actualizar recycle_bin para marcar que fue hard deleted
  -- Marcamos can_restore = false para indicar que ya no se puede restaurar
  update public.recycle_bin
  set can_restore = false,
      reason = coalesce(reason, '') || ' [Hard deleted permanently]',
      updated_at = now()
  where id = p_recycle_bin_id;
  
  -- Si el registro no existía, aún así marcamos como hard deleted en recycle_bin
  -- para mantener el historial
  
  return true;
exception
  when others then
    raise exception 'Error in fn_hard_delete_entity: %', sqlerrm;
end;
$$;

-- Grant execute permission
grant execute on function public.fn_hard_delete_entity(bigint, uuid, text) to authenticated;

-- Add comment
comment on function public.fn_hard_delete_entity is 'Función para hard delete. Borra permanentemente el registro original de la tabla pero mantiene la referencia en recycle_bin marcada como no restaurable.';
