# IDP SDK

SDK para integración con el Identity Provider (IDP) - Autenticación, Gestión de Usuarios, Organizaciones y Facturación.

## Instalación

```bash
npm install @ait-saas-sso/idp-sdk
# o
pnpm add @ait-saas-sso/idp-sdk
# o
yarn add @ait-saas-sso/idp-sdk
```

**Nota:** El SDK incluye `@supabase/supabase-js` como dependencia, no necesitas instalarlo manualmente.

## Uso Básico

```tsx
import { IDPProvider, AuthProvider, LoginForm } from '@ait-saas-sso/idp-sdk';

function App() {
  return (
    <IDPProvider
      supabaseUrl="https://your-project.supabase.co"
      supabaseAnonKey="your-anon-key"
      productId="your-product-id"
      clientSecret="your-client-secret"
    >
      <AuthProvider>
        <LoginForm onSuccess={() => console.log('Logged in!')} />
      </AuthProvider>
    </IDPProvider>
  );
}
```

## Personalización de Estilos

El SDK incluye estilos embebidos basados en Tailwind CSS y shadcn/ui. Todos los componentes usan el prefijo `idp-` para evitar conflictos.

### Sobrescribir Estilos Globales

Puedes sobrescribir las variables CSS del SDK:

```css
/* En tu archivo CSS global */
:root {
  --idp-primary: 221.2 83.2% 53.3%; /* Color primario */
  --idp-radius: 0.5rem; /* Radio de bordes */
  /* ... más variables */
}
```

### Sobrescribir Estilos de Componentes Específicos

Puedes pasar `className` a cualquier componente para sobrescribir estilos:

```tsx
<LoginForm 
  className="my-custom-class"
  onSuccess={() => {}}
/>

<Button className="bg-red-500 hover:bg-red-600">
  Custom Button
</Button>
```

### Usar Selectores CSS Más Específicos

```css
/* Sobrescribir estilos del SDK con mayor especificidad */
.my-app .idp-button {
  background-color: #custom-color;
}

/* O usar !important si es necesario */
.idp-button-primary {
  background-color: #custom-color !important;
}
```

## Componentes Disponibles

### Autenticación
- `LoginForm` - Formulario de inicio de sesión
- `ForgotPasswordForm` - Formulario de recuperación de contraseña
- `AuthGuard` - Componente para proteger rutas

### Perfil
- `UserProfileForm` - Formulario de perfil de usuario
- `OrganizationProfileForm` - Formulario de perfil de organización

### Organizaciones
- `OrganizationMembersList` - Lista de miembros
- `InviteMemberDialog` - Diálogo para invitar miembros
- `RoleAssignmentDialog` - Diálogo para asignar roles

### Facturación
- `PlansCatalog` - Catálogo de planes
- `SubscriptionManagement` - Gestión de suscripciones

## Hooks Disponibles

Ver documentación completa en cada módulo:
- `@ait-saas-sso/idp-sdk/auth`
- `@ait-saas-sso/idp-sdk/profile`
- `@ait-saas-sso/idp-sdk/organization`
- `@ait-saas-sso/idp-sdk/billing`
- `@ait-saas-sso/idp-sdk/permissions`

## Variables CSS Disponibles

El SDK expone las siguientes variables CSS que puedes sobrescribir:

```css
--idp-background
--idp-foreground
--idp-primary
--idp-primary-foreground
--idp-secondary
--idp-secondary-foreground
--idp-destructive
--idp-destructive-foreground
--idp-muted
--idp-muted-foreground
--idp-accent
--idp-accent-foreground
--idp-border
--idp-input
--idp-ring
--idp-radius
```

## Soporte para Dark Mode

El SDK soporta dark mode automáticamente. Asegúrate de tener la clase `dark` en tu elemento raíz:

```tsx
<html className="dark">
  {/* ... */}
</html>
```
