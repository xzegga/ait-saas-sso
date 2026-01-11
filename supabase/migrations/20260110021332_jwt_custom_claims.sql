-- Función para inyectar datos en el JWT (Custom Claims)
-- Esta función se ejecuta automáticamente después de cada login para añadir información
-- de organización, rol y plan al token JWT del usuario
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  claims jsonb;
  user_id uuid;
  active_org_id uuid;
  active_role text;
  active_plan text;
  features jsonb;
begin
  -- Manejo de errores: Si algo falla, retornar el evento sin modificar
  begin
    -- 1. Obtener el ID del usuario desde el evento de Supabase Auth
    user_id := (event->>'user_id')::uuid;
    
    -- Si no hay user_id, retornar evento sin modificar
    if user_id is null then
      return event;
    end if;

    -- 2. Buscar la primera Org activa del usuario
    -- (En el futuro, podrías pasar un header 'x-org-id' para seleccionar cuál usar si tiene varias)
    select org_id into active_org_id
    from public.org_members
    where org_members.user_id = user_id
    and status = 'active'
    limit 1;

    -- 3. Si tiene Org, buscar su Rol, Plan y Features
    if active_org_id is not null then
      
      -- Buscar Rol en el producto principal (AiT SaaS Platform)
      -- Manejar caso donde no existe el rol
      select prd.role_name into active_role
      from public.member_product_roles mpr
      join public.product_role_definitions prd on mpr.role_definition_id = prd.id
      join public.org_members om on mpr.member_id = om.id
      where om.user_id = user_id and om.org_id = active_org_id
      limit 1;

      -- Buscar Plan y Features
      -- Manejar caso donde no hay suscripción o features
      select 
        pp.name, 
        coalesce(
          ops.custom_entitlements, 
          coalesce(
            (
              select jsonb_object_agg(pe.feature_key, pe.value_text)
              from public.plan_entitlements pe
              where pe.plan_id = pp.id
            ),
            '{}'::jsonb
          )
        )
      into active_plan, features
      from public.org_product_subscriptions ops
      join public.product_plans pp on ops.plan_id = pp.id
      where ops.org_id = active_org_id
        and ops.status = 'active'
      limit 1;
      
    end if;

    -- 4. Construir el objeto de Claims extra
    claims := coalesce(event->'claims', '{}'::jsonb);
    
    -- Inicializar app_metadata si no existe
    if claims->'app_metadata' is null then
      claims := jsonb_set(claims, '{app_metadata}', '{}'::jsonb);
    end if;

    -- Inyectar en 'app_metadata' (esto es lo estándar en Supabase/GoTrue)
    if active_org_id is not null then
      claims := jsonb_set(claims, '{app_metadata, org_id}', to_jsonb(active_org_id));
      
      if active_role is not null then
        claims := jsonb_set(claims, '{app_metadata, role}', to_jsonb(active_role));
      end if;
      
      if active_plan is not null then
        claims := jsonb_set(claims, '{app_metadata, plan}', to_jsonb(active_plan));
      end if;
      
      -- features puede ser null si no hay features definidas, manejamos eso:
      if features is not null and features != '{}'::jsonb then
        claims := jsonb_set(claims, '{app_metadata, features}', features);
      end if;
    end if;

    -- 5. Retornar el evento modificado
    event := jsonb_set(event, '{claims}', claims);
    
  exception
    when others then
      -- Si hay algún error, log y retornar el evento sin modificar
      -- Esto permite que el login continúe aunque haya problemas con los claims adicionales
      raise warning 'Error in custom_access_token_hook for user %: %', user_id, sqlerrm;
      return event;
  end;

  return event;
end;
$$;

-- Permisos necesarios para que el sistema de Auth ejecute esto
grant execute on function public.custom_access_token_hook to supabase_auth_admin;

-- IMPORTANTE: Revocar acceso público para que nadie pueda llamar esta función desde la API
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;
