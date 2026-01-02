resource "aws_security_group" "redis_sg" {
  vpc_id = var.vpc_id
  name   = "${var.project_name_prefix}-${var.environment}-redis-sg"

  ingress {
    protocol    = "tcp"
    from_port   = 6379
    to_port     = 6379
    cidr_blocks = ["10.0.0.0/8"] # Allow access from the entire 10.x.x.x network range
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.project_name_prefix}-${var.environment}-redis-sng"
  subnet_ids = var.subnet_ids
}

# Traditional ElastiCache Cluster (for PROD or when use_serverless = false)
resource "aws_elasticache_cluster" "valkey_cache" {
  count = var.use_serverless ? 0 : 1

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

# ElastiCache Serverless Cache (for DEV when use_serverless = true)
resource "aws_elasticache_serverless_cache" "valkey_serverless" {
  count = var.use_serverless ? 1 : 0

  engine = "valkey"
  name   = "${var.project_name_prefix}-${var.environment}-valkey-serverless"

  cache_usage_limits {
    data_storage {
      maximum = var.serverless_max_storage
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.serverless_max_ecpu
    }
  }

  daily_snapshot_time      = "03:00"
  description              = "Serverless Valkey cache for ${var.environment} environment"
  kms_key_id               = var.serverless_kms_key_id
  major_engine_version      = "7"
  security_group_ids        = [aws_security_group.redis_sg.id]
  snapshot_retention_limit  = 1
  subnet_ids                = var.subnet_ids

  tags = var.common_tags
}