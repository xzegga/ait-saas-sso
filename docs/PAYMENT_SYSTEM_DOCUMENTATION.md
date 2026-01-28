# Documentación del Sistema de Pagos Genérico

Este documento explica cómo funciona el sistema de pagos genérico y cómo se relaciona con el resto de las secciones del admin panel.

---

## 🎯 Visión General

El sistema de pagos está diseñado para ser **genérico y extensible**, permitiendo integrar múltiples payment providers (Stripe, PayPal, Razorpay, etc.) sin necesidad de crear tablas específicas para cada uno.

### Principios de Diseño:
1. **Normalización:** Estados y datos se normalizan para compatibilidad cross-provider
2. **Extensibilidad:** Fácil agregar nuevos providers sin cambios en el schema
3. **Trazabilidad:** Todo evento de webhook se registra para debugging
4. **Idempotencia:** Los webhooks se procesan de forma idempotente

---

## 📊 Arquitectura de Tablas

### 1. `payment_providers`
**Propósito:** Catálogo de proveedores de pago disponibles

**Campos clave:**
- `name`: Identificador técnico (ej: 'stripe', 'paypal')
- `display_name`: Nombre para mostrar en UI
- `status`: active, inactive, deprecated
- `config_schema`: JSON schema definiendo configuración requerida

**Relaciones:**
- Una cuenta de pago pertenece a un provider
- Un producto de pago pertenece a un provider
- Un precio de pago pertenece a un provider
- Una suscripción de pago pertenece a un provider
- Un invoice de pago pertenece a un provider
- Un webhook event pertenece a un provider

**En el Admin:**
- Sección: **Payment Providers** (ya implementado)
- Permite crear/editar/deprecar providers
- Configurar schema de configuración

---

### 2. `payment_accounts`
**Propósito:** Cuentas de pago de organizaciones en providers

**Campos clave:**
- `org_id`: Organización dueña de la cuenta
- `provider_id`: Provider de pago
- `external_account_id`: ID de la cuenta en el provider (ej: 'cus_xxx' en Stripe)
- `email`: Email de facturación
- `metadata`: Datos específicos del provider (payment methods, tax IDs, etc.)
- `status`: active, inactive, suspended

**Relaciones:**
- Una organización puede tener múltiples cuentas (una por provider)
- Una cuenta puede tener múltiples suscripciones
- Una cuenta puede tener múltiples invoices

**En el Admin:**
- Sección: **Payment Accounts** (pendiente)
- Ver todas las cuentas por organización
- Ver todas las cuentas por provider
- Crear/editar cuentas
- Ver suscripciones e invoices asociados

**Relación con otras secciones:**
- **Organizations:** Ver cuenta de pago asociada
- **Subscriptions:** Ver cuenta de pago de la organización
- **Invoices:** Ver cuenta de pago que generó el invoice

---

### 3. `payment_products`
**Propósito:** Mapeo de productos internos a productos del provider

**Campos clave:**
- `product_id`: Producto interno
- `provider_id`: Provider de pago
- `external_product_id`: ID del producto en el provider (ej: 'prod_xxx' en Stripe)
- `metadata`: Datos específicos del provider

**Relaciones:**
- Un producto interno puede estar mapeado a múltiples providers
- Un producto de pago puede tener múltiples precios

**En el Admin:**
- Sección: **Payment Products** (pendiente)
- Ver qué productos están sincronizados con qué providers
- Crear/editar mapeos
- Ver metadata del provider

**Relación con otras secciones:**
- **Products:** Ver mapeos de payment products
- **Payment Prices:** Ver producto de pago asociado

---

### 4. `payment_prices`
**Propósito:** Mapeo de planes a precios del provider

**Campos clave:**
- `product_plan_id`: Relación producto-plan interna
- `provider_id`: Provider de pago
- `external_price_id`: ID del precio en el provider (ej: 'price_xxx' en Stripe)
- `external_product_id`: Referencia al producto de pago
- `billing_interval`: month, year, day, week
- `currency`: Código de moneda
- `amount`: Monto en cents o unidad más pequeña
- `metadata`: Datos específicos del provider

**Relaciones:**
- Un plan interno puede tener múltiples precios (uno por provider)
- Un precio de pago pertenece a un producto de pago
- Un precio de pago puede tener múltiples suscripciones

**En el Admin:**
- Sección: **Payment Prices** (pendiente)
- Ver precios por plan y provider
- Crear/editar mapeos
- Ver billing intervals y currencies

**Relación con otras secciones:**
- **Product Plans:** Ver precios de pago asociados
- **Payment Subscriptions:** Ver precio de pago usado

---

### 5. `payment_subscriptions`
**Propósito:** Suscripciones sincronizadas con providers de pago

**Campos clave:**
- `subscription_id`: Suscripción interna (`org_product_subscriptions.id`)
- `provider_id`: Provider de pago
- `payment_account_id`: Cuenta de pago
- `external_subscription_id`: ID de suscripción en el provider (ej: 'sub_xxx' en Stripe)
- `external_price_id`: Precio usado
- `status`: Estado normalizado (active, trial, past_due, canceled, incomplete)
- `provider_status`: Estado original del provider (para debugging)
- `current_period_start/end`: Período de facturación actual
- `cancel_at_period_end`: Si está programada para cancelar
- `canceled_at`: Fecha de cancelación
- `metadata`: Datos específicos del provider

**Relaciones:**
- Una suscripción interna puede tener múltiples suscripciones de pago (una por provider)
- Una suscripción de pago pertenece a una cuenta de pago
- Una suscripción de pago puede tener múltiples invoices

**En el Admin:**
- Sección: **Payment Subscriptions** (pendiente)
- Ver todas las suscripciones sincronizadas
- Filtrar por organización, provider, estado
- Ver estado normalizado vs provider_status
- Ver períodos de facturación
- Link a suscripción interna

**Relación con otras secciones:**
- **Subscriptions:** Ver suscripción de pago asociada
- **Organizations:** Ver suscripciones de pago de la organización
- **Payment Accounts:** Ver suscripciones de la cuenta
- **Invoices:** Ver suscripción que generó el invoice

---

### 6. `payment_invoices`
**Propósito:** Facturas de providers de pago

**Campos clave:**
- `provider_id`: Provider de pago
- `payment_account_id`: Cuenta de pago
- `payment_subscription_id`: Suscripción de pago (opcional)
- `org_id`: Organización (para acceso rápido)
- `external_invoice_id`: ID del invoice en el provider (ej: 'in_xxx' en Stripe)
- `amount_due`: Monto debido en cents
- `amount_paid`: Monto pagado en cents
- `currency`: Código de moneda
- `status`: Estado normalizado (draft, open, paid, void, uncollectible)
- `provider_status`: Estado original del provider
- `invoice_pdf`: URL al PDF del invoice
- `hosted_invoice_url`: URL a la página del invoice
- `period_start/end`: Período facturado
- `metadata`: Datos específicos del provider

**Relaciones:**
- Un invoice pertenece a un provider
- Un invoice puede pertenecer a una cuenta de pago
- Un invoice puede pertenecer a una suscripción de pago
- Un invoice pertenece a una organización

**En el Admin:**
- Sección: **Billing/Invoices** (implementado pero usa `useStripeInvoices`, necesita migración)
- Ver todas las facturas
- Filtrar por organización, provider, estado
- Descargar PDFs
- Ver hosted invoice URLs
- Ver período facturado

**Relación con otras secciones:**
- **Organizations:** Ver invoices de la organización
- **Subscriptions:** Ver invoices de la suscripción
- **Payment Accounts:** Ver invoices de la cuenta
- **Payment Subscriptions:** Ver invoices de la suscripción de pago

---

### 7. `payment_webhook_events`
**Propósito:** Log de eventos de webhooks de todos los providers

**Campos clave:**
- `provider_id`: Provider de pago
- `external_event_id`: ID del evento en el provider (ej: 'evt_xxx' en Stripe)
- `event_type`: Tipo normalizado (ej: 'subscription.created', 'invoice.paid')
- `provider_event_type`: Tipo original del provider (ej: 'customer.subscription.created' en Stripe)
- `processed`: Si el evento fue procesado
- `processed_at`: Fecha de procesamiento
- `event_data`: Payload completo del webhook (JSONB)
- `error_message`: Mensaje de error si el procesamiento falló

**Relaciones:**
- Un evento pertenece a un provider
- Un evento puede estar relacionado con múltiples entidades (cuenta, suscripción, invoice)

**En el Admin:**
- Sección: **Payment Webhook Events** (pendiente)
- Ver todos los eventos recibidos
- Filtrar por provider, tipo, estado
- Ver payload completo
- Re-procesar eventos fallidos
- Estadísticas de eventos

**Relación con otras secciones:**
- **Payment Providers:** Ver eventos del provider
- **Payment Subscriptions:** Ver eventos relacionados
- **Invoices:** Ver eventos relacionados

---

## 🔄 Flujos de Sincronización

### Flujo 1: Crear Suscripción
1. Super Admin crea suscripción en **Subscriptions** (`org_product_subscriptions`)
2. Si hay payment provider configurado:
   - Se crea/actualiza `payment_account` (si no existe)
   - Se crea/actualiza `payment_product` (mapeo producto)
   - Se crea/actualiza `payment_price` (mapeo plan)
   - Se crea `payment_subscription` (sincronización)
3. El webhook del provider confirma la creación
4. Se actualiza el estado en ambas tablas (interna y payment)

### Flujo 2: Webhook de Invoice
1. Provider envía webhook de invoice creado/pagado
2. Se registra en `payment_webhook_events`
3. Se procesa el evento:
   - Se crea/actualiza `payment_invoice`
   - Se actualiza estado de `payment_subscription` si aplica
   - Se actualiza estado de `org_product_subscriptions` si aplica
4. Se marca el evento como procesado

### Flujo 3: Cambio de Estado de Suscripción
1. Provider envía webhook (ej: subscription.canceled)
2. Se registra en `payment_webhook_events`
3. Se actualiza `payment_subscription.status` (normalizado)
4. Se actualiza `org_product_subscriptions.status` (sincronizado)
5. Se marca el evento como procesado

---

## 🔗 Relaciones con Otras Secciones

### Organizations
- **Ver:** Cuenta de pago asociada (`payment_accounts`)
- **Ver:** Suscripciones de pago activas (`payment_subscriptions`)
- **Ver:** Historial de facturación (`payment_invoices`)
- **Ver:** Total gastado (suma de invoices pagados)

### Subscriptions (`org_product_subscriptions`)
- **Ver:** Suscripción de pago asociada (`payment_subscriptions`)
- **Ver:** Invoices relacionados (`payment_invoices`)
- **Ver:** Estado sincronizado vs estado interno
- **Sincronizar:** Manualmente si hay desincronización

### Products
- **Ver:** Mapeos de payment products (`payment_products`)
- **Ver:** Qué providers tienen este producto sincronizado

### Product Plans
- **Ver:** Precios de pago asociados (`payment_prices`)
- **Ver:** Qué providers tienen este plan con precio

### Payment Providers
- **Ver:** Cuentas creadas (`payment_accounts`)
- **Ver:** Productos sincronizados (`payment_products`)
- **Ver:** Precios configurados (`payment_prices`)
- **Ver:** Suscripciones activas (`payment_subscriptions`)
- **Ver:** Eventos de webhook (`payment_webhook_events`)

---

## 🛠️ Funciones de Sincronización

Todas las funciones están en `supabase/migrations/20250101000012_functions_payment_sync.sql`:

### `sync_payment_account(org_id, provider_id, external_account_id, ...)`
Crea o actualiza una cuenta de pago para una organización.

### `sync_payment_product(product_id, provider_id, external_product_id, ...)`
Crea o actualiza el mapeo de un producto interno a un producto del provider.

### `sync_payment_price(product_plan_id, provider_id, external_price_id, ...)`
Crea o actualiza el mapeo de un plan a un precio del provider.

### `sync_payment_subscription(subscription_id, provider_id, ...)`
Crea o actualiza una suscripción de pago y sincroniza el estado con la suscripción interna.

### `sync_payment_invoice(provider_id, external_invoice_id, ...)`
Crea o actualiza un invoice de pago desde un webhook.

### `log_payment_webhook_event(provider_id, external_event_id, ...)`
Registra un evento de webhook (idempotente).

### `mark_payment_webhook_processed(event_id, error_message)`
Marca un evento como procesado.

---

## 🔐 Seguridad (RLS)

### Super Admins
- Acceso completo a todas las tablas de payment
- Pueden ver todos los datos de todas las organizaciones

### Org Admins (Owners)
- Solo pueden ver datos de sus propias organizaciones
- Pueden ver:
  - `payment_accounts` de su org
  - `payment_subscriptions` de su org
  - `payment_invoices` de su org
- No pueden crear/editar (solo super admins)

### Service Role
- Puede insertar/actualizar para procesar webhooks
- Usado por Edge Functions que procesan webhooks

---

## 📝 Normalización de Estados

### Subscription Status
- **Provider → Normalizado:**
  - `active`, `trialing` → `active`
  - `past_due`, `unpaid`, `payment_failed` → `past_due`
  - `canceled`, `cancelled`, `expired` → `canceled`
  - `incomplete`, `incomplete_expired` → `incomplete`

### Invoice Status
- **Provider → Normalizado:**
  - `paid`, `succeeded` → `paid`
  - `open`, `pending`, `unpaid` → `open`
  - `void`, `voided` → `void`
  - `uncollectible`, `failed` → `uncollectible`

---

## 🚀 Próximos Pasos

1. **Implementar Payment Accounts** (alta prioridad)
2. **Implementar Payment Subscriptions** (alta prioridad)
3. **Implementar Payment Webhook Events** (alta prioridad)
4. **Migrar Billing/Invoices a genérico** (alta prioridad)
5. **Implementar Payment Products** (media prioridad)
6. **Implementar Payment Prices** (media prioridad)
7. **Agregar links entre secciones** (mejoras)

---

**Última actualización:** 2025-01-XX
**Versión:** 1.0
