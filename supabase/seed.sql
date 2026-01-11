-- ==============================================================================
-- SEED DATA: Datos Maestros Requeridos para el Funcionamiento del Sistema
-- ==============================================================================
-- Este script asegura que todos los datos necesarios para el trigger handle_new_user
-- estén presentes en la base de datos antes de que los usuarios se registren.
-- Es idempotente: puede ejecutarse múltiples veces sin errores.
-- ==============================================================================

-- 1. CREATE MAIN PRODUCT (Core Platform)
-- REQUERIDO por handle_new_user: busca client_id = 'prod_core_system'
-- Usa UPSERT para asegurar que el producto exista, usando client_id como clave única
insert into public.products (id, name, description, client_id, client_secret, redirect_urls)
values (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'AiT SaaS Platform',
  'The core management system for all products.',
  'prod_core_system', -- REQUERIDO: Referenciado en handle_new_user
  'sec_local_dev_secret', -- Secret for local development
  ARRAY['http://localhost:3000', 'http://127.0.0.1:3000'] -- Local frontend
) on conflict (client_id) do update set
  name = excluded.name,
  description = excluded.description,
  client_secret = excluded.client_secret,
  redirect_urls = excluded.redirect_urls,
  deleted_at = null; -- Asegurar que no esté soft-deleted

-- Nota: Si el producto ya existe con otro ID pero el mismo client_id,
-- el UPDATE mantendrá el ID original (correcto para integridad referencial)

-- 2. DEFINE ROLES FOR CORE PRODUCT
-- REQUERIDO por handle_new_user: busca role_name = 'Owner' para el producto core
-- REQUERIDO por accept_invitation: busca role_name = 'Member' como default
with core_product as (
  select id from public.products where client_id = 'prod_core_system' limit 1
)
insert into public.product_role_definitions (product_id, role_name, is_default)
select 
  core_product.id,
  role_data.role_name,
  role_data.is_default
from core_product,
(values 
  ('Owner', false),    -- REQUERIDO: Usado por handle_new_user para nuevos usuarios
  ('Admin', false),    -- Opcional: Para gestión avanzada
  ('Member', true)     -- REQUERIDO: Default para invitaciones (accept_invitation)
) as role_data(role_name, is_default)
where core_product.id is not null
on conflict (product_id, role_name) do nothing;

-- 3. DEFINE FEATURES (Catalog of limitations)
-- Opcional: Usado por plan_entitlements para definir límites de planes
with core_product as (
  select id from public.products where client_id = 'prod_core_system' limit 1
)
insert into public.product_features (product_id, key, description, data_type)
select 
  core_product.id,
  feature_data.key,
  feature_data.description,
  feature_data.data_type
from core_product,
(values 
  ('max_seats', 'Maximum number of users', 'integer'),
  ('can_access_beta', 'Access to beta features', 'boolean')
) as feature_data(key, description, data_type)
where core_product.id is not null
on conflict (product_id, key) do nothing;

-- 4. CREATE COMMERCIAL PLANS
-- REQUERIDO por handle_new_user: busca name = 'Free Tier' para el producto core

-- Free Plan (Default Plan for New Users)
with core_product as (
  select id from public.products where client_id = 'prod_core_system' limit 1
)
insert into public.product_plans (id, product_id, name, is_public)
select 
  'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22',
  core_product.id,
  'Free Tier', -- REQUERIDO: Referenciado en handle_new_user
  true
from core_product
where core_product.id is not null
on conflict (id) do update set
  product_id = excluded.product_id,
  name = excluded.name,
  is_public = excluded.is_public,
  deleted_at = null;

-- Pro Plan (Upgrade Option)
with core_product as (
  select id from public.products where client_id = 'prod_core_system' limit 1
)
insert into public.product_plans (id, product_id, name, is_public)
select 
  'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
  core_product.id,
  'Pro Bundle',
  true
from core_product
where core_product.id is not null
on conflict (id) do update set
  product_id = excluded.product_id,
  name = excluded.name,
  is_public = excluded.is_public,
  deleted_at = null;

-- 5. ASSIGN ENTITLEMENTS (Business rules for each plan)
-- Define límites y capacidades de cada plan

-- Free Plan rules: Max 2 users, No Beta access
insert into public.plan_entitlements (plan_id, feature_key, value_text)
select 
  'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22',
  entitlement_data.feature_key,
  entitlement_data.value_text
from (values 
  ('max_seats', '2'),
  ('can_access_beta', 'false')
) as entitlement_data(feature_key, value_text)
on conflict (plan_id, feature_key) do update set
  value_text = excluded.value_text;

-- Pro Plan rules: Unlimited users (-1), With Beta access
insert into public.plan_entitlements (plan_id, feature_key, value_text)
select 
  'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
  entitlement_data.feature_key,
  entitlement_data.value_text
from (values 
  ('max_seats', '-1'), -- -1 significa ilimitado
  ('can_access_beta', 'true')
) as entitlement_data(feature_key, value_text)
on conflict (plan_id, feature_key) do update set
  value_text = excluded.value_text;

-- 6. INITIAL SUPER ADMIN
-- REQUERIDO: Whitelist de usuarios con permisos totales (bypass RLS)
-- Este usuario tendrá system_role = 'super_admin' en el JWT cuando se registre
insert into public.super_admins (email, description)
values ('raul.escamilla@asesoriait.com', 'System Owner / Initial Admin')
on conflict (email) do update set
  description = excluded.description;

-- ==============================================================================
-- VERIFICACIÓN POST-SEED (Opcional: Comentado para producción)
-- ==============================================================================
-- Descomentar para verificar que todos los datos requeridos están presentes:
--
-- DO $$
-- DECLARE
--   product_exists boolean;
--   plan_exists boolean;
--   owner_role_exists boolean;
--   member_role_exists boolean;
-- BEGIN
--   SELECT EXISTS(SELECT 1 FROM public.products WHERE client_id = 'prod_core_system') INTO product_exists;
--   SELECT EXISTS(SELECT 1 FROM public.product_plans pp JOIN public.products p ON pp.product_id = p.id WHERE p.client_id = 'prod_core_system' AND pp.name = 'Free Tier') INTO plan_exists;
--   SELECT EXISTS(SELECT 1 FROM public.product_role_definitions prd JOIN public.products p ON prd.product_id = p.id WHERE p.client_id = 'prod_core_system' AND prd.role_name = 'Owner') INTO owner_role_exists;
--   SELECT EXISTS(SELECT 1 FROM public.product_role_definitions prd JOIN public.products p ON prd.product_id = p.id WHERE p.client_id = 'prod_core_system' AND prd.role_name = 'Member') INTO member_role_exists;
--   
--   IF NOT product_exists THEN RAISE EXCEPTION 'SEED ERROR: Product prod_core_system not found'; END IF;
--   IF NOT plan_exists THEN RAISE EXCEPTION 'SEED ERROR: Free Tier plan not found'; END IF;
--   IF NOT owner_role_exists THEN RAISE EXCEPTION 'SEED ERROR: Owner role not found'; END IF;
--   IF NOT member_role_exists THEN RAISE EXCEPTION 'SEED ERROR: Member role not found'; END IF;
--   
--   RAISE NOTICE 'SEED VERIFICATION: All required data present ✓';
-- END $$;
-- ==============================================================================