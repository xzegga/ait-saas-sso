# Guía de Migración: Redis a Valkey

## 📋 Resumen de Cambios

Este documento describe los pasos para migrar de Redis a Valkey en la infraestructura de AWS ElastiCache.

### Cambios Implementados

1. **Engine actualizado**: De `redis` a `valkey`
2. **Versión actualizada**: De `7.0` a `7.2`
3. **Soporte Serverless**: Opción para usar ElastiCache Serverless en DEV
4. **Nomenclatura**: Recursos renombrados de `redis_cache` a `valkey_cache`

---

## 🔄 Pasos de Migración para PROD

### ⚠️ IMPORTANTE: Backup y Preparación

Antes de proceder, asegúrate de:
- [ ] Tener backups de los datos en Redis
- [ ] Notificar al equipo sobre el mantenimiento
- [ ] Verificar que no hay aplicaciones conectadas críticas
- [ ] Tener un plan de rollback

### Paso 1: Verificar el Estado Actual

```bash
cd infrastructure/iac-aws/environments/prod
terraform init
terraform state list | grep redis
```

Deberías ver:
- `module.redis.aws_elasticache_cluster.redis_cache`
- `module.redis.aws_security_group.redis_sg`
- `module.redis.aws_elasticache_subnet_group.redis_subnet_group`

### Paso 2: Ver el Plan de Cambios

```bash
terraform plan
```

Esto mostrará que el recurso `redis_cache` será destruido y `valkey_cache` será creado.

### Paso 3: Destruir el Recurso Redis Existente

**Opción A: Destroy específico del módulo Redis (RECOMENDADO)**

```bash
# Destruir solo el cluster Redis, manteniendo Security Group y Subnet Group
terraform destroy -target=module.redis.aws_elasticache_cluster.redis_cache
```

**Opción B: Destroy de todo el módulo Redis**

```bash
# Destruir todo el módulo Redis (incluye Security Group y Subnet Group)
terraform destroy -target=module.redis
```

**⚠️ Nota**: Si usas la Opción B, necesitarás recrear el Security Group y Subnet Group antes de crear Valkey.

### Paso 4: Aplicar los Cambios para Crear Valkey

```bash
terraform apply
```

Esto creará:
- `module.redis.aws_elasticache_cluster.valkey_cache` (nuevo recurso Valkey)

### Paso 5: Verificar la Creación

```bash
# Ver el estado
terraform state list | grep valkey

# Ver detalles del recurso
terraform show module.redis.aws_elasticache_cluster.valkey_cache
```

### Paso 6: Actualizar Aplicaciones

Actualiza las conexiones de tus aplicaciones para usar el nuevo endpoint de Valkey:

```bash
# Obtener el endpoint
terraform output -module=redis endpoint
```

---

## 🚀 Pasos de Migración para DEV

### Opción 1: Migración a Valkey Serverless (RECOMENDADO para DEV)

DEV está configurado para usar **ElastiCache Serverless**, que es más económico ya que pagas solo por uso.

```bash
cd infrastructure/iac-aws/environments/dev
terraform init
terraform plan
terraform apply
```

Esto creará:
- `module.redis.aws_elasticache_serverless_cache.valkey_serverless`

### Opción 2: Migración a Valkey Traditional (si prefieres consistencia con PROD)

Si prefieres usar el mismo tipo de cluster que PROD:

1. Edita `environments/dev/main.tf` y cambia:
   ```hcl
   use_serverless = false
   ```

2. Aplica los cambios:
   ```bash
   terraform apply
   ```

---

## 📊 Comparación: Traditional vs Serverless

### Traditional Cluster (PROD)

**Ventajas:**
- ✅ Rendimiento predecible
- ✅ Control total sobre la configuración
- ✅ Mejor para cargas de trabajo constantes
- ✅ Más fácil de monitorear

**Desventajas:**
- ❌ Costo fijo (pagas 24/7)
- ❌ Requiere planificación de capacidad
- ❌ Puede estar sobre-provisionado

**Costo estimado (cache.t4g.micro):**
- ~$12-15 USD/mes (dependiendo de la región)

### Serverless Cache (DEV)

**Ventajas:**
- ✅ Pago solo por uso (más económico para dev)
- ✅ Escalado automático
- ✅ Sin gestión de capacidad
- ✅ Ideal para cargas de trabajo variables

**Desventajas:**
- ❌ Latencia de cold start posible
- ❌ Menos control sobre configuración
- ❌ Puede ser más caro si hay uso constante alto

**Costo estimado:**
- ~$0.125 USD por GB-hora de almacenamiento
- ~$0.125 USD por millón de ECPU
- Típicamente $5-20 USD/mes para dev (dependiendo del uso)

---

## 🔍 Verificación Post-Migración

### 1. Verificar en AWS Console

1. Ve a **ElastiCache** en AWS Console
2. Busca el cluster/cache: `saas-mfe-tlinks-prod-valkey-cache`
3. Verifica:
   - Engine: `valkey`
   - Engine Version: `7.2`
   - Status: `Available`

### 2. Probar Conexión

```bash
# Obtener el endpoint
terraform output -module=redis endpoint

# Probar conexión (requiere redis-cli o similar)
redis-cli -h <endpoint> -p 6379 ping
# Debería responder: PONG
```

### 3. Verificar Tags

Todos los recursos deben tener los tags:
- `Project = "saas-mfe"`
- `Environment = "prod"` o `"dev"`
- `ManagedBy = "Terraform"`
- `ProjectName = "saas-mfe-tlinks"`

---

## 🛠️ Troubleshooting

### Error: "Engine valkey not supported"

Si AWS aún no soporta Valkey en tu región, puedes:
1. Verificar las versiones disponibles: `aws elasticache describe-cache-engine-versions --engine valkey`
2. Usar `redis` como engine pero con versión 7.2 (Valkey es compatible con Redis)

### Error: "Subnet group not found"

Si destruiste el subnet group, recréalo primero:
```bash
terraform apply -target=module.redis.aws_elasticache_subnet_group.redis_subnet_group
```

### Error: "Security group not found"

Si destruiste el security group, recréalo primero:
```bash
terraform apply -target=module.redis.aws_security_group.redis_sg
```

---

## 📝 Notas Importantes

1. **Compatibilidad**: Valkey es compatible con Redis, así que tus aplicaciones deberían funcionar sin cambios
2. **Downtime**: La migración requiere destruir y recrear el cluster, causando downtime
3. **Datos**: Los datos en Redis se perderán a menos que tengas backups
4. **Rollback**: Si necesitas volver a Redis, simplemente revierte los cambios en el código y aplica

---

## ✅ Checklist de Migración

- [ ] Backup de datos Redis
- [ ] Notificación al equipo
- [ ] Verificación de estado actual (`terraform state list`)
- [ ] Plan de cambios (`terraform plan`)
- [ ] Destroy del recurso Redis (`terraform destroy -target`)
- [ ] Apply de Valkey (`terraform apply`)
- [ ] Verificación en AWS Console
- [ ] Prueba de conexión
- [ ] Actualización de aplicaciones
- [ ] Documentación actualizada

---

## 📚 Referencias

- [AWS ElastiCache Valkey Documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/WhatIs.html)
- [ElastiCache Serverless](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/serverless.html)
- [Valkey Project](https://valkey.io/)


