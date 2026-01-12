-- 1. INITIAL SUPER ADMIN
-- REQUERIDO: Whitelist de usuarios con permisos totales (bypass RLS)
-- Este usuario tendrá system_role = 'super_admin' en el JWT cuando se registre
insert into public.super_admins (email, description)
values ('raul.escamilla@asesoriait.com', 'System Owner / Initial Admin')
on conflict (email) do update set
  description = excluded.description;
