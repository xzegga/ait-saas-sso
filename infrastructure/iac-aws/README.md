A continuación, se enumeran todos los recursos de AWS que se **provisionarán** al ejecutar `terraform apply` en los *workspaces* `dev` o `prod`:

---

## 🛠️ Recursos de AWS a Provisionar con Terraform (IaC)

| Módulo | Tipo de Recurso | Nombre Lógico de Terraform | Propósito |
| :--- | :--- | :--- | :--- |
| **Network** | `aws_vpc` | `aws_vpc.main` | Red privada virtual central para aislar todos los recursos del cliente. |
| **Network** | `aws_internet_gateway` | `aws_internet_gateway.gw` | Permite la comunicación entre la VPC y el internet (necesario para la CDN y Auth0). |
| **Network** | `aws_subnet` | `aws_subnet.public` (2 instancias) | Subredes públicas para alojar temporalmente los recursos y permitir la conexión a internet. |
| **Redis** | `aws_security_group` | `aws_security_group.redis_sg` | Reglas de *firewall* que permiten el acceso al puerto 6379 de Redis **solo** desde dentro de la VPC. |
| **Redis** | `aws_elasticache_subnet_group` | `aws_elasticache_subnet_group.redis_subnet_group` | Agrupación de las subredes que se utilizarán para desplegar los nodos de ElastiCache. |
| **Redis** | `aws_elasticache_cluster` | `aws_elasticache_cluster.redis_cache` | El clúster de caché de Redis (nodo `t4g.micro`) para almacenar el JWKS de Auth0 y el cacheo de la API. |
| **Root** | `aws_s3_bucket` | `aws_s3_bucket.mfe_static_hosting` | Almacenamiento de bajo costo para los *bundles* de JavaScript de los Micro Frontends. |
| **Root** | `aws_s3_bucket_public_access_block` | `aws_s3_bucket_public_access_block.mfe_bucket_block` | Bloquea el acceso público directo al *bucket* S3, forzando el acceso a través de CloudFront (por seguridad). |

**Nota:** La configuración de **CloudFront**, **API Gateway**, **Lambda** y **RDS (Base de Datos de Negocio)** aún no se han añadido al código de Terraform y son los siguientes pasos en la fase de IaC.