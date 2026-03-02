# Configuración de Variables de Entorno

## Resend SMTP Configuration

Para que Supabase pueda enviar emails usando Resend, necesitas configurar la variable de entorno `RESEND_API_KEY`.

### Opción 1: Archivo .env (Recomendado para desarrollo local)

Crea un archivo `.env` en la raíz del proyecto con:

```bash
RESEND_API_KEY=re_LepmVtBj_71RL4wAFTvpi9C5D54sfx1HX
```

Luego, exporta las variables antes de iniciar Supabase:

```bash
export $(cat .env | xargs)
supabase start
```

### Opción 2: Exportar directamente en el shell

```bash
export RESEND_API_KEY=re_LepmVtBj_71RL4wAFTvpi9C5D54sfx1HX
supabase start
```

### Opción 3: Inline al iniciar Supabase

```bash
RESEND_API_KEY=re_LepmVtBj_71RL4wAFTvpi9C5D54sfx1HX supabase start
```

## Verificación

Para verificar que la configuración está funcionando:

1. Inicia Supabase: `supabase start`
2. Revisa los logs para confirmar que SMTP está habilitado
3. Prueba enviando un email de confirmación desde la UI de Supabase Studio

## Configuración Actual

- **SMTP Host**: smtp.resend.com
- **Port**: 587
- **User**: resend
- **Sender Name**: ait-sso
- **Admin Email**: noreply@ait-sso.com

**Nota**: Asegúrate de verificar tu dominio en Resend antes de usar `noreply@ait-sso.com` en producción. Para desarrollo, puedes usar el dominio de prueba de Resend.
