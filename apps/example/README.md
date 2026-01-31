# IDP SDK Demo Application

Demo completo del SDK de Identity Provider (@ait-saas-sso/idp-sdk) mostrando todas las funcionalidades disponibles.

## Configuración

1. **Configurar variables de entorno:**

   Copia `.env.local.example` a `.env.local` y configura tus credenciales:

   ```bash
   cp .env.local.example .env.local
   ```

2. **Configurar Supabase:**

   Las credenciales por defecto son para Supabase localhost:
   - URL: `http://127.0.0.1:54321`
   - Anon Key: (la key por defecto de Supabase local)

3. **Configurar Product ID y Client Secret:**

   Para que el SDK valide que tu aplicación es un producto legítimo:
   
   a. Accede al admin panel del IDP (`ait-sso-admin`)
   b. Ve a la sección "Products"
   c. Crea un nuevo producto o selecciona uno existente
   d. Copia el **Product ID** y el **Client Secret** generado
   e. Agrega estos valores a tu `.env.local`:
   
   ```env
   VITE_PRODUCT_ID=tu-product-id-aqui
   VITE_CLIENT_SECRET=tu-client-secret-aqui
   ```
   
   **Ejemplo con tu producto "Example App":**
   ```env
   VITE_PRODUCT_ID=el-id-del-producto-example-app
   VITE_CLIENT_SECRET=1ed457ef1d33212b554e4f65163e377867dcfbf987c8cb5ed8e7a9cbb9c30c98
   ```

2. **Asegúrate de que Supabase local esté corriendo:**

   ```bash
   supabase start
   ```

## Ejecutar el Demo

```bash
pnpm dev
```

La aplicación estará disponible en `http://localhost:5173`

## Funcionalidades Demo

### 1. Autenticación
- **Login Page** (`/login`): Formulario de login con email/password
- **Forgot Password** (`/forgot-password`): Recuperación de contraseña

### 2. Dashboard
- **Dashboard** (`/dashboard`): Página principal con estadísticas y ejemplos de permisos
- Muestra ejemplos de `PermissionGate` y `FeatureFlag`

### 3. Perfiles
- **Profile** (`/profile`): Gestión de perfil de usuario y organización
- Tabs para alternar entre perfil de usuario y organización

### 4. Organización
- **Organization** (`/organization`): Gestión de miembros de la organización
- Lista de miembros, invitaciones, y asignación de roles

### 5. Billing
- **Billing** (`/billing`): Gestión de planes y suscripciones
- Catálogo de planes y gestión de suscripción actual

## Estructura

```
src/
├── App.tsx                 # Router principal y providers
├── components/
│   └── Layout.tsx         # Layout con navegación
├── pages/
│   ├── HomePage.tsx       # Página de inicio
│   ├── LoginPage.tsx      # Login
│   ├── ForgotPasswordPage.tsx
│   ├── DashboardPage.tsx
│   ├── ProfilePage.tsx
│   ├── OrganizationPage.tsx
│   └── BillingPage.tsx
└── config/
    └── supabase.ts        # Configuración de Supabase
```

## Notas

- Los IDs de organización y producto son mock data para el demo
- En producción, estos vendrían del contexto o JWT
- Todas las funcionalidades del SDK están integradas y funcionando
