# Comparación: Valkey Traditional vs Serverless

## 📊 Resumen Ejecutivo

Este documento compara las dos implementaciones de Valkey disponibles en el módulo:
1. **Traditional Cluster** (usado en PROD)
2. **Serverless Cache** (usado en DEV)

---

## 🔧 Código: Traditional Cluster

```hcl
# Traditional ElastiCache Cluster
resource "aws_elasticache_cluster" "valkey_cache" {
  cluster_id           = "${var.project_name_prefix}-${var.environment}-valkey-cache"
  engine               = "valkey"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  security_group_ids   = [aws_security_group.redis_sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  engine_version       = "7.2"
  port                 = 6379
  
  tags = var.common_tags
}
```

### Características:
- ✅ **Node type fijo**: `cache.t4g.micro`
- ✅ **Número de nodos**: 1 (configurable)
- ✅ **Engine version específica**: `7.2`
- ✅ **Subnet Group**: Requiere `aws_elasticache_subnet_group`
- ✅ **Control total**: Configuración explícita de recursos

### Recursos Adicionales Necesarios:
- `aws_elasticache_subnet_group` (obligatorio)
- `aws_security_group` (obligatorio)

---

## 🚀 Código: Serverless Cache

```hcl
# ElastiCache Serverless Cache
resource "aws_elasticache_serverless_cache" "valkey_serverless" {
  engine = "valkey"
  name   = "${var.project_name_prefix}-${var.environment}-valkey-serverless"

  cache_usage_limits {
    data_storage {
      maximum = var.serverless_max_storage  # 5 GB por defecto
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.serverless_max_ecpu  # 5000 por defecto
    }
  }

  daily_snapshot_time      = "03:00"
  description              = "Serverless Valkey cache for ${var.environment} environment"
  kms_key_id               = var.serverless_kms_key_id  # Opcional
  major_engine_version     = "7"
  security_group_ids       = [aws_security_group.redis_sg.id]
  snapshot_retention_limit = 1
  subnet_ids               = var.subnet_ids  # Usa subnets directamente

  tags = var.common_tags
}
```

### Características:
- ✅ **Sin node type**: AWS gestiona el escalado automáticamente
- ✅ **Límites configurables**: Storage y ECPU máximos
- ✅ **Major version**: Solo especifica `7` (AWS gestiona la versión exacta)
- ✅ **Subnets directas**: No requiere `aws_elasticache_subnet_group`
- ✅ **Snapshots automáticos**: Configuración de snapshot diario
- ✅ **Escalado automático**: AWS escala según demanda

### Recursos Adicionales Necesarios:
- `aws_security_group` (obligatorio)
- **NO requiere** `aws_elasticache_subnet_group`

---

## 📋 Tabla Comparativa

| Característica | Traditional Cluster | Serverless Cache |
|----------------|---------------------|------------------|
| **Node Type** | `cache.t4g.micro` (fijo) | Automático (AWS gestiona) |
| **Escalado** | Manual | Automático |
| **Costo Base** | Fijo (~$12-15/mes) | Variable (pago por uso) |
| **Configuración** | Más control | Menos control, más simple |
| **Subnet Group** | Requerido | No requerido |
| **Engine Version** | Específica (`7.2`) | Major version (`7`) |
| **Snapshots** | Configurable manualmente | Automático diario |
| **Cold Start** | No | Posible (mínimo) |
| **Ideal para** | Cargas constantes, PROD | Cargas variables, DEV |

---

## 💰 Análisis de Costos

### Traditional Cluster (cache.t4g.micro)

```
Costo mensual estimado: ~$12-15 USD
- Costo fijo 24/7
- No importa el uso
- Predecible
```

**Ejemplo de facturación:**
- Mes completo: $12-15 USD
- Uso bajo: $12-15 USD
- Uso alto: $12-15 USD (mismo precio)

### Serverless Cache

```
Costo mensual estimado: $5-20 USD (dependiendo del uso)
- Pago por GB-hora de almacenamiento: ~$0.125/GB-hora
- Pago por ECPU: ~$0.125 por millón de ECPU
- Sin costo cuando no se usa
```

**Ejemplo de facturación (DEV típico):**
- Uso bajo (2 GB, 1M ECPU/día): ~$5-8 USD/mes
- Uso medio (3 GB, 5M ECPU/día): ~$10-15 USD/mes
- Uso alto (5 GB, 10M ECPU/día): ~$15-25 USD/mes

**Ahorro potencial en DEV:**
- Si el uso es < 50% del tiempo: **Ahorro del 30-50%**
- Si el uso es esporádico: **Ahorro del 60-80%**

---

## 🎯 Cuándo Usar Cada Uno

### Usa Traditional Cluster cuando:
- ✅ Carga de trabajo constante y predecible
- ✅ Necesitas control total sobre la configuración
- ✅ Rendimiento consistente es crítico
- ✅ Ambiente de PRODUCCIÓN
- ✅ Presupuesto fijo y predecible

### Usa Serverless Cache cuando:
- ✅ Carga de trabajo variable o esporádica
- ✅ Quieres optimizar costos
- ✅ Ambiente de DESARROLLO o TESTING
- ✅ No necesitas configuración avanzada
- ✅ Prefieres que AWS gestione el escalado

---

## 🔄 Migración Entre Tipos

### De Traditional a Serverless

1. **Backup de datos** (si es necesario)
2. **Destruir cluster tradicional:**
   ```bash
   terraform destroy -target=module.redis.aws_elasticache_cluster.valkey_cache
   ```
3. **Actualizar configuración:**
   ```hcl
   use_serverless = true
   ```
4. **Aplicar cambios:**
   ```bash
   terraform apply
   ```

### De Serverless a Traditional

1. **Backup de datos** (si es necesario)
2. **Destruir cache serverless:**
   ```bash
   terraform destroy -target=module.redis.aws_elasticache_serverless_cache.valkey_serverless
   ```
3. **Actualizar configuración:**
   ```hcl
   use_serverless = false
   ```
4. **Aplicar cambios:**
   ```bash
   terraform apply
   ```

---

## 📝 Configuración Actual

### PROD (Traditional)
```hcl
module "redis" {
  # ...
  use_serverless = false  # Traditional cluster
}
```

### DEV (Serverless)
```hcl
module "redis" {
  # ...
  use_serverless         = true
  serverless_max_storage = 5   # 5 GB
  serverless_max_ecpu    = 5000  # 5000 ECPU/seg
}
```

---

## ✅ Recomendación Final

**Para este proyecto:**
- ✅ **PROD**: Traditional Cluster (rendimiento predecible, control total)
- ✅ **DEV**: Serverless Cache (optimización de costos, uso variable)

Esta configuración balancea:
- **Rendimiento** en producción
- **Economía** en desarrollo
- **Flexibilidad** para ajustar según necesidades


