-- ==============================================================================
-- SOFT DELETE FUNCTIONS
-- ==============================================================================
-- Functions for managing soft delete operations and recycle bin
-- ==============================================================================

-- ====================== SOFT DELETE FUNCTION ======================
-- Generic function for soft delete. Updates deleted_at in the original table
-- and creates/updates record in recycle_bin
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
  -- Verify that the user is super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform soft delete operations';
  end if;
  
  -- Verify that the table exists and has deleted_at
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
  
  -- Update deleted_at in the original table
  execute format(
    'update public.%I set deleted_at = now() where id = $1 and deleted_at is null',
    p_table_name
  ) using p_entity_id;
  
  get diagnostics v_deleted_count = row_count;
  
  if v_deleted_count = 0 then
    raise exception 'Entity with id % not found or already deleted in table %', p_entity_id, p_table_name;
  end if;
  
  -- Check if a record already exists in recycle_bin for this entity (not restored)
  if exists (
    select 1 
    from public.recycle_bin 
    where entity_type = p_table_name 
      and entity_id = p_entity_id::text
      and restored_at is null
  ) then
    -- Update the existing record
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
    -- Create new record in recycle_bin
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

comment on function public.fn_soft_delete is 'Generic function for soft delete. Updates deleted_at in the original table and creates/updates record in recycle_bin.';

-- ====================== SOFT DELETE AUTO FUNCTION ======================
-- Improved soft delete function that automatically gets the display name
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

comment on function public.fn_soft_delete_auto is 'Improved soft delete function that automatically gets the display name of the entity.';

-- ====================== RESTORE ENTITY FUNCTION ======================
-- Function to restore an entity. Updates deleted_at = null in the original table
-- and marks as restored in recycle_bin
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
  -- Verify that the user is super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform restore operations';
  end if;
  
  -- Get information from recycle_bin record
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
  
  -- Restore in the original table (set deleted_at = null)
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
    -- The record does not exist or was not deleted, update can_restore
    update public.recycle_bin
    set can_restore = false,
        reason = coalesce(reason, '') || ' [Restore failed: entity not found or not deleted]'
    where id = p_recycle_bin_id;
    raise exception 'Entity not found or not deleted in table %', v_record.entity_type;
  end if;
  
  -- Mark as restored in recycle_bin
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

comment on function public.fn_restore_entity is 'Function to restore an entity. Updates deleted_at = null in the original table and marks as restored in recycle_bin.';

-- ====================== HARD DELETE ENTITY FUNCTION ======================
-- Function for hard delete. Permanently deletes the original record from the table
-- but keeps the reference in recycle_bin marked as non-restorable
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
  -- Verify that the user is super_admin
  if not public.is_super_admin() then
    raise exception 'Only super_admin can perform hard delete operations';
  end if;
  
  -- Get information from recycle_bin record
  select entity_type, entity_id, can_restore, restored_at
  into v_record
  from public.recycle_bin
  where id = p_recycle_bin_id;
  
  if not found then
    raise exception 'Recycle bin entry with id % not found', p_recycle_bin_id;
  end if;
  
  -- Verify that it is not restored
  if v_record.restored_at is not null then
    raise exception 'Cannot hard delete a restored entity';
  end if;
  
  -- Delete the original record from the corresponding table
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
      -- If the record no longer exists, continue (may have been deleted manually)
      raise notice 'Entity not found in table % (may have been already deleted): %', v_record.entity_type, sqlerrm;
      v_deleted_count := 0;
  end;
  
  -- Update recycle_bin to mark that it was hard deleted
  -- Mark can_restore = false to indicate that it can no longer be restored
  update public.recycle_bin
  set can_restore = false,
      reason = coalesce(reason, '') || ' [Hard deleted permanently]',
      updated_at = now()
  where id = p_recycle_bin_id;
  
  -- If the record did not exist, still mark as hard deleted in recycle_bin
  -- to maintain history
  
  return true;
exception
  when others then
    raise exception 'Error in fn_hard_delete_entity: %', sqlerrm;
end;
$$;

grant execute on function public.fn_hard_delete_entity(bigint, uuid, text) to authenticated;

comment on function public.fn_hard_delete_entity is 'Function for hard delete. Permanently deletes the original record from the table but keeps the reference in recycle_bin marked as non-restorable.';
