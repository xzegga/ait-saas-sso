
**Documento Maestro de Arquitectura y Desarrollo**. Este documento consolida todo el trabajo realizado en los archivos SQL, las discusiones de diseño y los requerimientos de negocio.

Puedes entregar este documento a cualquier desarrollador nuevo o cargarlo en una nueva instancia de IA para que entienda exactamente el estado actual y el norte del proyecto.

---

# Documento Maestro: Core SaaS Identity & Management Platform

## 1. Visión Ejecutiva

El sistema es una **Plataforma Centralizada de Identidad y Gestión (Platform Shell)**. Funciona como un Identity Provider (IdP) propietario y un sistema de gestión de suscripciones B2B (Billing Engine).

* **Modelo:** Hub & Spoke. El Core es el "Hub", los Productos (Apps externas como CRM, ERP) son los "Spokes".
* **Propósito:** Centralizar la autenticación (SSO), la gestión de organizaciones (Multi-tenancy), y el control de licencias/suscripciones.
* **Filosofía:** Las aplicaciones de terceros **no gestionan usuarios ni pagos**; delegan esa responsabilidad en este Core.

---

## 2. Stack Tecnológico

| Capa | Tecnología | Función |
| --- | --- | --- |
| **Backend & DB** | **Supabase** | PostgreSQL, Auth (GoTrue), Realtime, Storage. |
| **Logica Backend** | **PL/pgSQL & Edge Functions** | Lógica transaccional crítica en DB (Triggers/RLS) y lógica de negocio async en Deno. |
| **Frontend Admin** | **Refine.dev** (React) | Panel exclusivo para el **Super Admin**. |
| **Frontend Tenant** | **Next.js** (App Router) | Panel para **Org Admins** y **Usuarios** (Gestión de equipo, perfil). |
| **Emails** | **Resend** (Dev) / **AWS SES** (Prod) | Infraestructura de correos transaccionales. |
| **Pagos** | **Stripe** | Sincronización de planes y subscripciones vía Webhooks. |

---

## 3. Arquitectura de Datos (Schema)

El esquema de base de datos divide el mundo en dos: el lado del **Proveedor** (Tú) y el lado del **Consumidor** (Clientes).

### A. Dominio del Proveedor (Provider-Side)

*Configuración global del sistema.*

1. **`products`**: Define las aplicaciones satélite (ej. "Core App", "External CRM"). Contiene `client_id` y `redirect_urls`.
2. **`product_plans`**: Paquetes comerciales (ej. "Free", "Pro", "Enterprise").
3. **`product_features`**: Catálogo de capacidades técnicas (ej. "max_users", "api_access").
4. **`product_role_definitions`**: Roles abstractos definidos por cada producto (ej. El CRM define "Sales Rep" y "Manager").
5. **`super_admins`**: Whitelist de usuarios con control total sobre la plataforma.

### B. Dominio del Consumidor (Consumer-Side)

*Datos de los clientes y sus accesos.*

1. **`organizations`**: La entidad legal/cliente (Tenant).
2. **`org_product_subscriptions`**: Qué Organización tiene acceso a Qué Producto y bajo Qué Plan.
3. **`org_members`**: Tabla pivote Usuario <-> Organización.
4. **`member_product_roles`**: Define qué rol ejerce un usuario dentro de un producto específico (ej. "Juan" es "Admin" en la Org, pero solo "Viewer" en el producto "ERP").

---

## 4. Arquitectura de Seguridad (Auth & RLS)

La seguridad es **Zero Trust**. El frontend no contiene lógica de seguridad crítica; todo se valida en la base de datos o Edge Functions.

### A. Autenticación (SSO)

* Se utiliza Supabase Auth.
* **Single Identity:** Un email = Un `auth.user`.
* **Contexto de Sesión:** Un usuario puede pertenecer a múltiples organizaciones, pero **solo una está activa a la vez** en el token JWT.

### B. JWT Custom Claims (Token Enrichment)

Para que las apps de terceros (Spokes) sepan qué puede hacer el usuario sin consultar la DB constantemente, inyectamos datos en el JWT mediante un Hook de Base de Datos (`custom_access_token_hook`).

**Estructura del Payload del Token:**

```json
{
  "aud": "authenticated",
  "app_metadata": {
    "system_role": "user",       // o 'super_admin'
    "org_id": "uuid-org-123",    // Organización activa actual
    "role": "Owner"              // Rol dentro de esa organización
  }
}

```

### C. Autorización (RLS)

Todas las tablas tienen Row Level Security habilitado.

* **Super Admin:** Acceso total (bypass de políticas vía función `is_super_admin()`).
* **Org Admin (Owner):** Puede ver y editar datos solo de su `org_id`. Puede invitar usuarios.
* **Member:** Solo lectura de su propia data y productos asignados.

---

## 5. Roles y Capacidades

### 1. Super Admin (Tú)

* **Interfaz:** Panel Refine.dev.
* **Capacidades:**
* Crear Productos (`products`).
* Definir Planes y Features (`product_plans`).
* Ver todas las Organizaciones y Usuarios.
* Forzar asignación de productos a organizaciones.



### 2. Organization Admin (Cliente)

* **Interfaz:** Dashboard Next.js (Tenant Dashboard).
* **Capacidades:**
* Ver detalles de facturación de su Org.
* Invitar usuarios por correo electrónico.
* Asignar roles de producto a sus miembros (ej. "Hacer a María admin del CRM").
* Revocar acceso a miembros.



### 3. End User (Empleado del Cliente)

* **Interfaz:** Dashboard Next.js (Perfil) y Apps de Terceros.
* **Capacidades:**
* Aceptar invitaciones.
* Gestionar su perfil personal (avatar, password).
* Consumir los productos a los que tiene acceso.



---

## 6. Estrategia de Integración MFE (Apps de Terceros)

Las aplicaciones externas (Productos) no deben implementar su propio login. Deben consumir el Core.

**Estrategia: Librería SDK Compartida (`@acme/auth-sdk`)**
Se desarrollará un paquete ligero (NPM o Submódulo) que las apps externas instalen.

**Flujo de Consumo:**

1. La App Externa inicializa el SDK con su `product_id`.
2. Si no hay sesión, el SDK redirige al Core para login.
3. Al volver, el SDK decodifica el JWT de Supabase.
4. **Validación:** La App Externa lee `app_metadata`.
* ¿Tiene `org_id`? -> Sí.
* ¿Tiene acceso a *este* producto? -> (Validado por RLS al intentar leer datos o vía claim específico si se decide agregar).
* ¿Qué rol tiene? -> Lee `role` del token y habilita/deshabilita botones en su UI.



---

## 7. Plan de Desarrollo (Roadmap)

### Fase 1: Backend Core (Completado al 90%)

* [x] Esquema de Base de datos (Tablas y Relaciones).
* [x] Políticas RLS (Seguridad).
* [x] Triggers de creación de usuario (Onboarding automático).
* [x] Hook de Custom Claims para JWT.
* [x] Función SQL para aceptar invitaciones.

### Fase 2: Dashboard de Tenant (Next.js) - **(Punto Actual)**

* [ ] Configuración de Next.js con Supabase SSR.
* [ ] **Middleware:** Protección de rutas `/dashboard` basándose en sesión.
* [ ] **Layout:** Sidebar, Header con selector de Org (si aplica) y User Menu.
* [ ] **Página Team:** Listado de miembros (lectura de `org_members`).
* [ ] **Acción Invitar:** Formulario que conecta con Edge Function `invite-user`.

### Fase 3: Edge Functions & Email

* [ ] Implementar `invite-user` (Deno) con validación de rol de Admin.
* [ ] Integración con API de Resend (Emails transaccionales HTML).

### Fase 4: Integración MFE (SDK)

* [ ] Crear paquete básico para leer sesión y claims en apps externas.
* [ ] Probar flujo: Login en Core -> Redirección a App Externa con sesión activa.

### Fase 5: Super Admin (Refine.dev)

* [ ] Conectar Refine a Supabase.
* [ ] Vistas CRUD para `products` y `product_plans`.

---

## 8. Flujos Críticos (Diagramas Conceptuales)

### Flujo de Invitación de Usuario

1. **Org Admin** (Next.js) -> `POST /functions/v1/invite-user` (Email + Rol).
2. **Edge Function**:
* Valida JWT (¿Es Admin de la Org?).
* Crea registro en `org_invitations`.
* Envía correo vía **Resend** con Link mágico (`/invite/accept?token=xyz`).


3. **Usuario Invitado**:
* Clic en link -> Landing page en Next.js.
* Si es usuario nuevo -> Sign Up -> Trigger `handle_new_user`.
* Si es usuario existente -> Login.
* Ejecuta `accept_invitation(token)` -> Se une a la Org.



---

Este documento sirve como la "Verdad Única" del proyecto. El siguiente paso técnico inmediato es **Fase 2: Configuración del Middleware y Layout en Next.js**.