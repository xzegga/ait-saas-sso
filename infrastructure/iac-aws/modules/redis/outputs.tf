# Output for traditional cluster endpoint
output "cache_endpoint" {
  description = "The endpoint address of the Valkey cache cluster (traditional)"
  value       = var.use_serverless ? null : (length(aws_elasticache_cluster.valkey_cache) > 0 ? aws_elasticache_cluster.valkey_cache[0].configuration_endpoint : null)
}

# Output for serverless cache endpoint
output "serverless_endpoint" {
  description = "The endpoint address of the Valkey serverless cache"
  value       = var.use_serverless ? (length(aws_elasticache_serverless_cache.valkey_serverless) > 0 ? aws_elasticache_serverless_cache.valkey_serverless[0].endpoint[0].address : null) : null
}

# Unified endpoint output (works for both traditional and serverless)
output "endpoint" {
  description = "The endpoint address of the Valkey cache (works for both traditional and serverless)"
  value = var.use_serverless ? (
    length(aws_elasticache_serverless_cache.valkey_serverless) > 0 ? aws_elasticache_serverless_cache.valkey_serverless[0].endpoint[0].address : null
  ) : (
    length(aws_elasticache_cluster.valkey_cache) > 0 ? aws_elasticache_cluster.valkey_cache[0].configuration_endpoint : null
  )
}

# Port output
output "port" {
  description = "The port number for the cache"
  value       = 6379
}

# Cache type indicator
output "cache_type" {
  description = "Type of cache deployment (traditional or serverless)"
  value       = var.use_serverless ? "serverless" : "traditional"
}


