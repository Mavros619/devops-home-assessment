resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name

  tags = {
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_ownership_controls" "static_site_ownership" {
  bucket = aws_s3_bucket.static_site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "static_site_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.static_site_ownership]

  bucket = aws_s3_bucket.static_site.id
  acl    = "private"
}

resource "aws_cloudfront_origin_access_control" "cdn_oac" {
  name                              = "${var.oac_name}-${var.env}"
  description                       = "${var.oac_description} in ${var.env}"
  origin_access_control_origin_type = "s3"
  signing_protocol                  = "sigv4"
  signing_behavior                  = "always"
}

resource "aws_s3_bucket_policy" "static_site_policy" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "cdn" {
  default_root_object = var.default_root_object
  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn_oac.id
  }
  web_acl_id = var.web_acl_id
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  enabled = true

  tags = {
    Environment = var.env
    ManagedBy   = "terraform"
  }
}
