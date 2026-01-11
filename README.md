# AiT SaaS SSO Platform

Monorepo para la plataforma SaaS SSO de AiT, gestionando infraestructura, base de datos y aplicaciones frontend.

## 📁 Estructura del Monorepo

```
ait-saas-sso/
├── apps/                    # Aplicaciones frontend
│   ├── admin-web/          # Panel de administración (a crear)
│   ├── portal-web/         # Portal de clientes (a crear)
│   └── auth-web/           # Página de autenticación (a crear)
│
├── packages/                # Paquetes compartidos
│   ├── shared-ui/          # Componentes UI compartidos (a crear)
│   ├── types/              # Tipos TypeScript compartidos (a crear)
│   ├── utils/              # Utilidades compartidas (a crear)
│   └── config/             # Configuraciones compartidas (a crear)
│
├── infrastructure/          # Infraestructura como Código (IaC)
│   └── iac-aws/            # Terraform para AWS
│       ├── modules/        # Módulos reutilizables
│       └── environments/   # Ambientes (dev, prod)
│
├── supabase/               # Base de datos y Backend-as-a-Service
│   ├── migrations/         # Migraciones de PostgreSQL
│   ├── seed.sql            # Datos iniciales
│   └── config.toml         # Configuración de Supabase
│
├── package.json            # Configuración raíz del monorepo
├── pnpm-workspace.yaml     # Configuración de workspaces de pnpm
└── .npmrc                  # Configuración de npm/pnpm
```

## 🛠️ Stack Tecnológico

### Infraestructura
- **Terraform** - IaC para AWS
- **AWS** - Cloud provider (VPC, S3, CloudFront, ElastiCache, etc.)

### Base de Datos
- **Supabase** - PostgreSQL + Auth + Realtime
- **PostgreSQL 17** - Base de datos relacional

### Frontend (por definir)
- **React/Next.js** - Framework frontend
- **TypeScript** - Lenguaje
- **pnpm** - Gestor de paquetes

## 🚀 Comandos Principales

### Instalación

```bash
# Instalar todas las dependencias de todos los workspaces
pnpm install
```

### Ejecutar aplicaciones

```bash
# Ejecutar una aplicación específica
pnpm --filter <workspace-name> dev

# Ejemplos:
pnpm --filter admin-web dev
pnpm --filter portal-web dev
```

### Construir aplicaciones

```bash
# Construir una aplicación específica
pnpm --filter <workspace-name> build

# Construir todas las aplicaciones
pnpm -r --filter './apps/*' build
```

### Agregar dependencias

```bash
# Agregar dependencia a un workspace específico
pnpm --filter <workspace-name> add <package>

# Agregar dependencia a todos los workspaces
pnpm -r add <package>

# Agregar dependencia compartida al root
pnpm add -w <package>
```

### Ejecutar comandos en múltiples workspaces

```bash
# Ejecutar un comando en todos los workspaces que lo soporten
pnpm -r exec -- <command>

# Ejemplo: Ejecutar tests en todos los workspaces
pnpm -r exec -- pnpm test
```

## 📦 Workspaces

### Apps (`apps/*`)
Aplicaciones frontend independientes que pueden tener sus propias dependencias y configuraciones.

**Agregar nueva app:**
1. Crear directorio: `apps/mi-nueva-app/`
2. Inicializar con `package.json` dentro del directorio
3. pnpm lo detectará automáticamente gracias a `pnpm-workspace.yaml`

### Packages (`packages/*`)
Paquetes compartidos que pueden ser usados por múltiples apps.

**Agregar nuevo paquete:**
1. Crear directorio: `packages/mi-paquete/`
2. Inicializar con `package.json` dentro del directorio
3. Configurar como paquete (private: true, main/export fields)
4. Usar en apps con: `"mi-paquete": "workspace:*"`

### Infrastructure (`infrastructure/*`)
Recursos de infraestructura como código. Puede tener `package.json` para scripts de automatización si es necesario.

## 🔧 Configuración

### pnpm-workspace.yaml
Define qué directorios son considerados workspaces. Actualmente configurado para:
- `apps/*` - Aplicaciones frontend
- `packages/*` - Paquetes compartidos
- `infrastructure/*` - Infraestructura (opcional, si tiene package.json)

### .npmrc
Configuración global de pnpm para el monorepo:
- `auto-install-peers=true` - Instala peer dependencies automáticamente
- `shared-workspace-lockfile=true` - Comparte un solo lockfile
- `node-linker=isolated` - Usa node_modules por workspace

## 📝 Convenciones

### Naming
- **Apps**: `*-web`, `*-app` (ej: `admin-web`, `portal-app`)
- **Packages**: descriptivos (ej: `shared-ui`, `types`, `utils`)
- **Infrastructure**: por tecnología/cloud (ej: `iac-aws`, `iac-gcp`)

### Estructura de cada workspace

Cada workspace debe tener su propio `package.json` con:
```json
{
  "name": "@ait-saas-sso/mi-workspace",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "...",
    "build": "...",
    "start": "..."
  }
}
```

## 🔐 Variables de Entorno

Cada aplicación puede tener su propio `.env` local. Variables compartidas deberían documentarse en el README de cada workspace.

## 📚 Documentación Adicional

- [Infraestructura AWS](./infrastructure/iac-aws/README.md)
- [Migraciones Supabase](./supabase/migrations/README.md) (crear si es necesario)

## 🤝 Contribuir

1. Crear un nuevo workspace siguiendo las convenciones
2. Agregar documentación en su propio README
3. Actualizar este README si agrega una nueva categoría de workspace
