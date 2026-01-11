-- ==============================================================================
-- RECYCLE BIN - Papelera de Reciclaje para Soft Delete y Restore
-- ==============================================================================

-- Tabla para registrar elementos eliminados con soft delete
create table public.recycle_bin (
  id bigserial primary key,
  
  -- Información de la entidad eliminada
  entity_type text not null check (length(entity_type) > 0 and length(entity_type) <= 50),
  entity_id text not null check (length(entity_id) > 0 and length(entity_id) <= 255),
  entity_display_name text not null check (length(entity_display_name) > 0 and length(entity_display_name) <= 255),
  
  -- Auditoría de eliminación
  deleted_by_id uuid not null references auth.users(id),
  deleted_by_name text not null check (length(deleted_by_name) > 0 and length(deleted_by_name) <= 255),
  deleted_at timestamptz not null default now(),
  reason text,
  
  -- Información de restauración
  restored_at timestamptz,
  restored_by_id uuid references auth.users(id),
  restored_by_name text check (length(restored_by_name) <= 255),
  can_restore boolean not null default true,
  
  -- Timestamps
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  
  -- Constraint: no se puede restaurar dos veces
  constraint check_restore check (
    (restored_at is null and restored_by_id is null) or 
    (restored_at is not null and restored_by_id is not null)
  )
);

-- Índices para mejorar performance
create index idx_recycle_bin_entity_type on public.recycle_bin(entity_type);
create index idx_recycle_bin_entity_id on public.recycle_bin(entity_id);
create index idx_recycle_bin_deleted_at on public.recycle_bin(deleted_at desc);
create index idx_recycle_bin_deleted_by_id on public.recycle_bin(deleted_by_id);
create index idx_recycle_bin_restored_at on public.recycle_bin(restored_at);
create index idx_recycle_bin_can_restore on public.recycle_bin(can_restore) where can_restore = true;
create index idx_recycle_bin_entity_type_id on public.recycle_bin(entity_type, entity_id) where restored_at is null;

-- Trigger para actualizar updated_at
create trigger handle_recycle_bin_updated_at 
  before update on public.recycle_bin
  for each row 
  execute procedure moddatetime(updated_at);

-- ==============================================================================
-- FUNCIONES PARA SOFT DELETE Y RESTORE
-- ==============================================================================

-- Función genérica para soft delete que registra en recycle_bin
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

-- Función genérica para restore que actualiza la tabla original y recycle_bin
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

-- Función helper para obtener el display name de una entidad
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
    when 'product_plans' then
      select name into v_display_name from public.product_plans where id = p_entity_id;
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

-- Función mejorada de soft delete que obtiene automáticamente el display name
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

-- ==============================================================================
-- GRANTS PARA FUNCIONES
-- ==============================================================================

-- Las funciones de soft delete y restore deben ser ejecutables por usuarios autenticados
-- pero solo funcionarán si el usuario tiene permisos (verificado por RLS)
grant execute on function public.fn_soft_delete(text, uuid, text, uuid, text, text) to authenticated;
grant execute on function public.fn_soft_delete_auto(text, uuid, uuid, text, text) to authenticated;
grant execute on function public.fn_restore_entity(bigint, uuid, text) to authenticated;
grant execute on function public.fn_get_entity_display_name(text, uuid) to authenticated;

-- ==============================================================================
-- RLS POLICIES PARA RECYCLE_BIN
-- ==============================================================================

-- Habilitar RLS
alter table public.recycle_bin enable row level security;

-- Solo super_admin puede ver todos los registros
create policy recycle_bin_select_super_admin
  on public.recycle_bin
  for select
  using (public.is_super_admin());

-- Solo super_admin puede insertar registros (a través de las funciones)
create policy recycle_bin_insert_super_admin
  on public.recycle_bin
  for insert
  with check (public.is_super_admin());

-- Solo super_admin puede actualizar registros (para restore)
create policy recycle_bin_update_super_admin
  on public.recycle_bin
  for update
  using (public.is_super_admin())
  with check (public.is_super_admin());

-- Solo super_admin puede eliminar permanentemente registros
create policy recycle_bin_delete_super_admin
  on public.recycle_bin
  for delete
  using (public.is_super_admin());

-- ==============================================================================
-- COMENTARIOS PARA DOCUMENTACIÓN
-- ==============================================================================

comment on table public.recycle_bin is 'Papelera de reciclaje para registrar elementos eliminados con soft delete. Permite restaurar elementos eliminados.';
comment on column public.recycle_bin.entity_type is 'Tipo de entidad eliminada (e.g., products, product_plans, organizations, profiles)';
comment on column public.recycle_bin.entity_id is 'ID del registro eliminado en su tabla original (UUID como texto)';
comment on column public.recycle_bin.entity_display_name is 'Nombre legible del registro para mostrar en la UI';
comment on column public.recycle_bin.deleted_by_id is 'UUID del usuario que eliminó el registro';
comment on column public.recycle_bin.deleted_by_name is 'Nombre del usuario que eliminó (snapshot al momento de eliminación)';
comment on column public.recycle_bin.deleted_at is 'Fecha y hora de eliminación';
comment on column public.recycle_bin.reason is 'Razón opcional de la eliminación';
comment on column public.recycle_bin.restored_at is 'Fecha y hora de restauración (si aplica)';
comment on column public.recycle_bin.restored_by_id is 'UUID del usuario que restauró el registro';
comment on column public.recycle_bin.restored_by_name is 'Nombre del usuario que restauró (snapshot)';
comment on column public.recycle_bin.can_restore is 'Indica si el registro puede ser restaurado (validación de integridad)';

comment on function public.fn_soft_delete is 'Función genérica para soft delete. Actualiza deleted_at en la tabla original y crea/actualiza registro en recycle_bin.';
comment on function public.fn_soft_delete_auto is 'Función mejorada de soft delete que obtiene automáticamente el display name de la entidad.';
comment on function public.fn_restore_entity is 'Función para restaurar una entidad. Actualiza deleted_at = null en la tabla original y marca como restaurado en recycle_bin.';
comment on function public.fn_get_entity_display_name is 'Función helper para obtener el nombre legible de una entidad según su tipo.';
