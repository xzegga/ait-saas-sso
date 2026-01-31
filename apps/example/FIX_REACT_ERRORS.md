# Solución para Errores de React

## Problema
Error: `Cannot read properties of undefined (reading 'ReactCurrentDispatcher')`

Este error ocurre cuando hay múltiples instancias de React o cuando React no está correctamente externalizado en el SDK.

## Pasos para Resolver

### 1. Reconstruir el SDK

```bash
# Desde la raíz del proyecto
cd packages/idp-sdk

# Limpiar build anterior
pnpm clean

# Reconstruir el SDK
pnpm build
```

### 2. Publicar con yalc

```bash
# Aún en packages/idp-sdk
pnpm yalc publish
```

### 3. Actualizar en el ejemplo

```bash
# Desde la raíz del proyecto
cd apps/example

# Remover la instalación anterior de yalc
pnpm yalc remove @ait-saas-sso/idp-sdk

# Agregar la nueva versión
pnpm yalc add @ait-saas-sso/idp-sdk

# Reinstalar dependencias para asegurar que React esté deduplicado
rm -rf node_modules
pnpm install
```

### 4. Verificar configuración

Asegúrate de que tu `.env.local` tenga:

```env
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvf0xg_3BJgxAaH
VITE_PRODUCT_ID=tu-product-id
VITE_CLIENT_SECRET=1ed457ef1d33212b554e4f65163e377867dcfbf987c8cb5ed8e7a9cbb9c30c98
```

### 5. Ejecutar el ejemplo

```bash
# Aún en apps/example
pnpm dev
```

## Si el problema persiste

1. **Limpiar completamente yalc:**
   ```bash
   cd apps/example
   pnpm yalc remove @ait-saas-sso/idp-sdk
   rm -rf .yalc node_modules
   pnpm install
   pnpm yalc add @ait-saas-sso/idp-sdk
   ```

2. **Verificar que no haya múltiples versiones de React:**
   ```bash
   cd apps/example
   pnpm list react react-dom
   ```
   
   Deberías ver solo una versión de cada uno.

3. **Limpiar cache de Vite:**
   ```bash
   cd apps/example
   rm -rf node_modules/.vite
   pnpm dev
   ```
