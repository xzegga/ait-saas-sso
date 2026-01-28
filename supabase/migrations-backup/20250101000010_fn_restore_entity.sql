-- ==============================================================================
-- RESTORE ENTITY FUNCTION
-- ==============================================================================
-- Function to restore an entity. Updates deleted_at = null in the original table
-- and marks as restored in recycle_bin
-- ==============================================================================

create or replace function public.fn_restore_entity(
  p_recycle_bin_id bigint,
  p_restored_by_id uuid,
  p_restored_by_name text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record record;
  v_restored_count int;
begin
  -- Verificar que el usuario es super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform restore operations';
  end if;
  
  -- Obtener información del registro en recycle_bin
  select entity_type, entity_id, can_restore, restored_at
  into v_record
  from public.recycle_bin
  where id = p_recycle_bin_id;
  
  if not found then
    raise exception 'Recycle bin entry with id % not found', p_recycle_bin_id;
  end if;
  
  if v_record.restored_at is not null then
    raise exception 'Entity has already been restored';
  end if;
  
  if not v_record.can_restore then
    raise exception 'Entity cannot be restored (can_restore = false)';
  end if;
  
  -- Restaurar en la tabla original (poner deleted_at = null)
  -- Intentar convertir entity_id a UUID y actualizar
  begin
    execute format(
      'update public.%I set deleted_at = null where id = $1 and deleted_at is not null',
      v_record.entity_type
    ) using v_record.entity_id::uuid;
    
    get diagnostics v_restored_count = row_count;
  exception
    when invalid_text_representation then
      raise exception 'Invalid UUID format for entity_id: %', v_record.entity_id;
  end;
  
  if v_restored_count = 0 then
    -- El registro no existe o no estaba eliminado, actualizar can_restore
    update public.recycle_bin
    set can_restore = false,
        reason = coalesce(reason, '') || ' [Restore failed: entity not found or not deleted]'
    where id = p_recycle_bin_id;
    raise exception 'Entity not found or not deleted in table %', v_record.entity_type;
  end if;
  
  -- Marcar como restaurado en recycle_bin
  update public.recycle_bin
  set restored_at = now(),
      restored_by_id = p_restored_by_id,
      restored_by_name = p_restored_by_name,
      can_restore = false
  where id = p_recycle_bin_id;
  
  return true;
exception
  when others then
    raise exception 'Error in fn_restore_entity: %', sqlerrm;
end;
$$;

grant execute on function public.fn_restore_entity(bigint, uuid, text) to authenticated;

comment on function public.fn_restore_entity is 'Función para restaurar una entidad. Actualiza deleted_at = null en la tabla original y marca como restaurado en recycle_bin.';
