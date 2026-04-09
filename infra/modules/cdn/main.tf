# infra/modules/cdn/main.tf — CONTAINS BUGS. Fix before extending.

provider "aws" {
  region = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

resource "aws_s3_bucket" "static_site" {
    bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "static_site_acl" {
    bucket = aws_s3_bucket.static_site.id
    acl    = "public-read"
}

resource "aws_cloudfront_distribution" "cdn" {
    origin {
        domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
        origin_id = "S3Origin"
    }
    default_cache_behavior {
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3Origin"
        viewer_protocol_policy = "allow-all"
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
}

variable "bucket_name" {
    type = string
}