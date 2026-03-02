# Migraciones – Orden consolidado

Las migraciones están ordenadas para crear el esquema desde cero con dependencias correctas.

| # | Archivo | Contenido |
|---|---------|-----------|
| 001 | schema_extensions_and_base | Extensiones, tablas base (con `trial_days`, `origin_urls` text[], `redirect_urls` text[], `trial_starts_at`/`trial_ends_at`, FKs a profiles/product_plans), índices base |
| 002 | schema_billing_intervals | Tabla `billing_intervals`, índices, trigger, seed (month, year) |
| 003 | schema_subscriptions_billing_interval | Columna `billing_interval_id` en `org_product_subscriptions` |
| 004 | schema_product_plan_prices | Tabla `product_plan_prices` (FK a billing_intervals), índices, RLS, trigger |
| 005 | schema_payment | Tablas de pago (con `payment_prices` unique por intervalo y FK a billing_intervals), índices, RLS, seed Stripe |
| 006 | schema_email_templates | Tabla `email_templates`, `get_email_template`, `render_email_template`, trigger, grants, seed plantillas |
| 007 | functions_security_helpers | `is_super_admin`, `get_my_org_id`, `get_my_role` |
| 008 | functions_business | `accept_invitation`, `custom_access_token_hook`, `fn_get_entity_display_name` |
| 009 | functions_soft_delete | `fn_soft_delete`, `fn_soft_delete_auto`, `fn_restore_entity`, `fn_hard_delete_entity` |
| 010 | functions_subscription_validation | `is_subscription_active`, `expire_trials` |
| 011 | functions_payment_sync | Funciones de sincronización de pago |
| 012 | functions_complete_user_signup | `fn_complete_user_signup` (con `billing_interval`) |
| 013 | functions_validate_client_secret | `validate_client_secret` (origin from request headers via `get_request_origin`), `get_product_by_client_secret` |
| 014 | functions_origin_validation | `validate_product_origin`, `extract_request_origin`, `get_request_origin` (robusta, desde headers), `is_product_origin_valid`, `is_product_origin_valid_by_client_id` (equiv. original 032) |
| 015 | functions_email_extra | `update_confirmation_sent_at` |
| 016 | triggers | `handle_new_user`, `moddatetime`, `validate_trial_dates` |
| 017 | views | `v_user_org_roles`, `v_subscription_details` |
| 018 | rls_core | RLS en tablas core con forma `(select ...)` |
| 019 | rls_payment | RLS en tablas de pago con forma `(select ...)` |
| 020 | rls_anon_views_misc | Políticas anon + **validación de origen** en products, product_plans, plans, product_plan_prices, plan_entitlements, entitlements (equiv. original 027). RLS product_plan_prices/billing/email_templates, grants de vistas |
| 021 | indexes_force_rls | Índices adicionales y `FORCE ROW LEVEL SECURITY` |
| 022 | email_sending_functions | `get_email_template_data`, `get_signup_confirmation_email_data`, `get_admin_new_user_notification_data`, `get_password_reset_email_data` (original 035) |
| 023 | otp_email_templates | Plantillas user_signup_otp, password_reset_otp, user_welcome, password_reset_success (original 037) |
| 024 | fix_render_email_template_otp_functions | `get_signup_otp_email_data`, `get_password_reset_otp_email_data`, `get_welcome_email_data`, `get_password_reset_success_email_data` con firma correcta de `render_email_template` (original 039) |
| 025 | subscription_purchased_email | Plantilla subscription_purchased + `get_subscription_purchased_email_data` (original 040) |
| 026 | schema_organizations_extended | Organizaciones: `slug`, `legal_name`, `tax_id`, `status`, `support_email`, `phone`. Tabla `organization_addresses` (tipos: billing, shipping, legal, headquarters), RLS e índices |
| 027 | rls_org_members_own | Política "View own memberships" en org_members (user_id = auth.uid()) para poder resolver org_id cuando el JWT no lo trae |
