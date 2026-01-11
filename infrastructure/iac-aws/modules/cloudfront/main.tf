# Origin Access Control (OAC) - Modern replacement for OAI
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name_prefix}-${var.environment}-s3-oac"
  description                       = "OAC for ${var.project_name_prefix} ${var.environment} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "CloudFront distribution for ${var.project_name_prefix} ${var.environment} SPA"
  default_root_object = "index.html"
  price_class         = var.price_class

  # Origin configuration with OAC
  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = "S3-${var.s3_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # Default cache behavior for SPA
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.s3_bucket_name}"

    # Use managed cache policy for optimal performance (CachingOptimized)
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # Custom error responses for SPA routing (403/404 -> 200 with index.html)
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
    error_caching_min_ttl = 300
  }

  # Viewer certificate (use default CloudFront certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Restrictions (optional - can be configured via variables)
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-${var.environment}-cloudfront"
    }
  )

  depends_on = [aws_cloudfront_origin_access_control.s3_oac]
}

# S3 Bucket Policy to allow CloudFront OAC access
resource "aws_s3_bucket_policy" "cloudfront_oac_policy" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${var.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_cloudfront_distribution.s3_distribution,
    aws_cloudfront_origin_access_control.s3_oac
  ]
}

