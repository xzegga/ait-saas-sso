-- ==============================================================================
-- SOFT DELETE FUNCTION
-- ==============================================================================
-- Generic function for soft delete. Updates deleted_at in the original table
-- and creates/updates record in recycle_bin
-- ==============================================================================

create or replace function public.fn_soft_delete(
  p_table_name text,
  p_entity_id uuid,
  p_entity_display_name text,
  p_deleted_by_id uuid,
  p_deleted_by_name text,
  p_reason text default null
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted_count int;
  v_has_deleted_at boolean;
begin
  -- Verificar que el usuario es super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform soft delete operations';
  end if;
  
  -- Verificar que la tabla existe y tiene deleted_at
  select exists (
    select 1 
    from information_schema.columns 
    where table_schema = 'public' 
      and table_name = p_table_name 
      and column_name = 'deleted_at'
  ) into v_has_deleted_at;
  
  if not v_has_deleted_at then
    raise exception 'Table % does not have deleted_at column', p_table_name;
  end if;
  
  -- Actualizar deleted_at en la tabla original
  execute format(
    'update public.%I set deleted_at = now() where id = $1 and deleted_at is null',
    p_table_name
  ) using p_entity_id;
  
  get diagnostics v_deleted_count = row_count;
  
  if v_deleted_count = 0 then
    raise exception 'Entity with id % not found or already deleted in table %', p_entity_id, p_table_name;
  end if;
  
  -- Verificar si ya existe un registro en recycle_bin para esta entidad (no restaurado)
  if exists (
    select 1 
    from public.recycle_bin 
    where entity_type = p_table_name 
      and entity_id = p_entity_id::text
      and restored_at is null
  ) then
    -- Actualizar el registro existente
    update public.recycle_bin
    set deleted_by_id = p_deleted_by_id,
        deleted_by_name = p_deleted_by_name,
        deleted_at = now(),
        reason = coalesce(p_reason, reason),
        can_restore = true,
        restored_at = null,
        restored_by_id = null,
        restored_by_name = null
    where entity_type = p_table_name 
      and entity_id = p_entity_id::text
      and restored_at is null;
  else
    -- Crear nuevo registro en recycle_bin
    insert into public.recycle_bin (
      entity_type,
      entity_id,
      entity_display_name,
      deleted_by_id,
      deleted_by_name,
      reason,
      can_restore
    ) values (
      p_table_name,
      p_entity_id::text,
      p_entity_display_name,
      p_deleted_by_id,
      p_deleted_by_name,
      p_reason,
      true
    );
  end if;
  
  return true;
exception
  when others then
    raise exception 'Error in fn_soft_delete: %', sqlerrm;
end;
$$;

grant execute on function public.fn_soft_delete(text, uuid, text, uuid, text, text) to authenticated;

comment on function public.fn_soft_delete is 'Función genérica para soft delete. Actualiza deleted_at en la tabla original y crea/actualiza registro en recycle_bin.';
