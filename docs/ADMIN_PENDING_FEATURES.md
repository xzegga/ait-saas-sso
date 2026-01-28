# Plan de Trabajo - Funcionalidades Pendientes del Admin Panel

Este documento detalla todas las funcionalidades que faltan implementar en el panel de administración, priorizadas y organizadas por categorías.

---

## 📊 Estado Actual

### ✅ Implementado (12 páginas)
1. **Dashboard** - Estadísticas generales
2. **Products** - CRUD completo con gestión de planes y roles
3. **Plans & Entitlements** - Gestión de planes y entitlements globales
4. **Product Plans** - Gestión de relaciones producto-plan con precios ⭐ (Recién completado)
5. **Organizations** - Listado y gestión
6. **Organization Members** - Gestión de miembros por organización
7. **Member Product Roles** - Asignación de roles por producto
8. **Subscriptions** - Listado, creación y edición
9. **Users/Profiles** - Listado y detalle
10. **Super Admins** - Gestión de whitelist
11. **Recycle Bin** - Gestión de elementos eliminados
12. **Billing/Invoices** - Facturas (usa `useStripeInvoices`, necesita migración)
13. **Payment Providers** - CRUD de proveedores de pago

---

## 🚨 Alta Prioridad

### 1. Payment Accounts (`payment_accounts`)
**Propósito:** Ver y gestionar cuentas de pago por organización

**Funcionalidad requerida:**
- [ ] Listar todas las cuentas de pago
- [ ] Filtrar por organización
- [ ] Filtrar por provider
- [ ] Ver detalles de cuenta (external_account_id, metadata, status)
- [ ] Crear/editar cuentas (asociar org con provider account)
- [ ] Ver historial de pagos por cuenta
- [ ] Ver suscripciones asociadas a la cuenta

**Archivos a crear:**
- `apps/ait-sso-admin/src/hooks/usePaymentAccounts.ts`
- `apps/ait-sso-admin/src/pages/payment-accounts/list.tsx`
- `apps/ait-sso-admin/src/components/payment-accounts/*`

**Estimación:** 4-6 horas

---

### 2. Payment Subscriptions (`payment_subscriptions`)
**Propósito:** Ver suscripciones sincronizadas con providers de pago

**Funcionalidad requerida:**
- [ ] Listar todas las suscripciones de pago
- [ ] Filtrar por organización
- [ ] Filtrar por provider
- [ ] Filtrar por estado (active, trial, past_due, canceled)
- [ ] Ver estado normalizado vs provider_status
- [ ] Ver períodos de facturación (current_period_start, current_period_end)
- [ ] Ver si está programada para cancelar (cancel_at_period_end)
- [ ] Link a suscripción interna (`org_product_subscriptions`)
- [ ] Sincronizar manualmente si es necesario

**Archivos a crear:**
- `apps/ait-sso-admin/src/hooks/usePaymentSubscriptions.ts`
- `apps/ait-sso-admin/src/pages/payment-subscriptions/list.tsx`
- `apps/ait-sso-admin/src/components/payment-subscriptions/*`

**Estimación:** 5-7 horas

---

### 3. Payment Webhook Events (`payment_webhook_events`)
**Propósito:** Debugging y monitoreo de webhooks de payment providers

**Funcionalidad requerida:**
- [ ] Listar todos los eventos recibidos
- [ ] Filtrar por provider
- [ ] Filtrar por tipo de evento (event_type)
- [ ] Filtrar por estado (processed/unprocessed)
- [ ] Ver payload completo del evento
- [ ] Ver error_message si el procesamiento falló
- [ ] Re-procesar eventos fallidos manualmente
- [ ] Estadísticas de eventos (total, processed, failed)
- [ ] Búsqueda por external_event_id

**Archivos a crear:**
- `apps/ait-sso-admin/src/hooks/usePaymentWebhookEvents.ts`
- `apps/ait-sso-admin/src/pages/payment-webhook-events/list.tsx`
- `apps/ait-sso-admin/src/components/payment-webhook-events/*`

**Estimación:** 6-8 horas

---

### 4. Migrar Billing/Invoices a Sistema Genérico
**Propósito:** Soportar múltiples payment providers en lugar de solo Stripe

**Cambios requeridos:**
- [ ] Crear hook `usePaymentInvoices` genérico (reemplazar `useStripeInvoices`)
- [ ] Actualizar `apps/ait-sso-admin/src/pages/billing/invoices.tsx`
- [ ] Agregar filtro por provider
- [ ] Mostrar provider en la tabla
- [ ] Agregar links para descargar PDFs
- [ ] Agregar links a hosted invoice URLs
- [ ] Mantener compatibilidad con datos existentes

**Archivos a modificar:**
- `apps/ait-sso-admin/src/hooks/useStripeInvoices.ts` → `usePaymentInvoices.ts`
- `apps/ait-sso-admin/src/pages/billing/invoices.tsx`
- `apps/ait-sso-admin/src/components/billing/*`

**Estimación:** 3-4 horas

---

## 📋 Media Prioridad

### 5. Payment Products (`payment_products`)
**Propósito:** Mapear productos internos a productos del provider

**Funcionalidad requerida:**
- [ ] Listar todos los mapeos producto → provider product
- [ ] Filtrar por producto interno
- [ ] Filtrar por provider
- [ ] Crear/editar mapeos
- [ ] Ver qué productos están sincronizados con qué providers
- [ ] Ver metadata del provider

**Archivos a crear:**
- `apps/ait-sso-admin/src/hooks/usePaymentProducts.ts`
- `apps/ait-sso-admin/src/pages/payment-products/list.tsx`
- `apps/ait-sso-admin/src/components/payment-products/*`

**Estimación:** 3-4 horas

---

### 6. Payment Prices (`payment_prices`)
**Propósito:** Mapear planes a precios del provider

**Funcionalidad requerida:**
- [ ] Listar todos los mapeos plan → provider price
- [ ] Filtrar por producto-plan interno
- [ ] Filtrar por provider
- [ ] Crear/editar mapeos
- [ ] Ver precios por provider y plan
- [ ] Ver billing_interval (month, year, day, week)
- [ ] Ver amount en cents y currency

**Archivos a crear:**
- `apps/ait-sso-admin/src/hooks/usePaymentPrices.ts`
- `apps/ait-sso-admin/src/pages/payment-prices/list.tsx`
- `apps/ait-sso-admin/src/components/payment-prices/*`

**Estimación:** 3-4 horas

---

### 7. Role Templates (`role_templates`)
**Propósito:** Templates reutilizables de roles para productos

**Estado:** Hook existe (`useRoleTemplates`), falta la página

**Funcionalidad requerida:**
- [ ] Listar todos los templates
- [ ] Crear/editar/eliminar templates
- [ ] Ver roles incluidos en cada template
- [ ] Aplicar template a un producto
- [ ] Previsualizar qué roles se crearán

**Archivos a crear:**
- `apps/ait-sso-admin/src/pages/role-templates/list.tsx`
- `apps/ait-sso-admin/src/components/role-templates/*`

**Estimación:** 3-4 horas

---

## 🔧 Mejoras en Páginas Existentes

### 8. Mejoras en Subscriptions
**Funcionalidad adicional:**
- [ ] Ver suscripción de pago asociada (link a `payment_subscriptions`)
- [ ] Ver historial de cambios de estado
- [ ] Ver invoices relacionados
- [ ] Ver payment account asociada

**Archivos a modificar:**
- `apps/ait-sso-admin/src/pages/subscriptions/list.tsx`
- `apps/ait-sso-admin/src/components/subscriptions/*`

**Estimación:** 2-3 horas

---

### 9. Mejoras en Organizations
**Funcionalidad adicional:**
- [ ] Ver cuenta de pago asociada (link a `payment_accounts`)
- [ ] Ver suscripciones de pago activas
- [ ] Ver historial de facturación
- [ ] Ver total gastado por organización

**Archivos a modificar:**
- `apps/ait-sso-admin/src/pages/organizations/list.tsx`
- `apps/ait-sso-admin/src/components/organizations/*`

**Estimación:** 2-3 horas

---

## 📝 Notas de Implementación

### Patrones a seguir:
1. **Hooks:** Usar el mismo patrón que `usePaymentProviders` para consistencia
2. **Componentes:** Reutilizar componentes de `payment-providers` como base
3. **Filtros:** Implementar filtros por organización, provider, estado
4. **Tablas:** Mostrar información clave con links a entidades relacionadas
5. **Forms:** Usar Sheets para crear/editar, similar a otras páginas

### Consideraciones técnicas:
- Todas las tablas de payment tienen RLS habilitado
- Super admins tienen acceso completo
- Org admins solo ven datos de sus organizaciones
- Service role puede insertar/actualizar para webhooks

### Orden sugerido de implementación:
1. Payment Accounts (base para todo lo demás)
2. Payment Subscriptions (más usado)
3. Payment Webhook Events (debugging crítico)
4. Migrar Billing/Invoices (mejora existente)
5. Payment Products y Prices (completar mapeos)
6. Role Templates (funcionalidad independiente)
7. Mejoras en páginas existentes (polish final)

---

## 📊 Resumen de Estimación

| Prioridad | Funcionalidad | Estimación |
|-----------|--------------|------------|
| Alta | Payment Accounts | 4-6 horas |
| Alta | Payment Subscriptions | 5-7 horas |
| Alta | Payment Webhook Events | 6-8 horas |
| Alta | Migrar Billing/Invoices | 3-4 horas |
| Media | Payment Products | 3-4 horas |
| Media | Payment Prices | 3-4 horas |
| Media | Role Templates | 3-4 horas |
| Baja | Mejoras Subscriptions | 2-3 horas |
| Baja | Mejoras Organizations | 2-3 horas |
| **TOTAL** | | **31-43 horas** |

---

**Última actualización:** 2025-01-XX
**Estado:** En progreso - Product Plans completado ✅
