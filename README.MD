# Part 1
Screenshot after first running `terraform plan`

![alt text](images/1st-tf-plan.png)

## Bug 1

The name of the bucket is different that the name that is referenced in line 8.

I changed the line from `aws_s3_bucket.static.bucket_regional_domain_name` to `aws_s3_bucket.static_site.bucket_regional_domain_name`

Also fixed the warning of the argument `acl` which is deprecated and replaced it with `aws_s3_bucket_acl`

## Bug 2

![alt text](images/2nd-tf-plan.png)

The provider block was missing and terraform didn't know what plugin to download.

I added the below code to fix it:

```hcl
provider "aws" {
  region = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}
```

## Bug 3

The security issue with Trivy that will flag is that `acl` was set to `public-read`.

I added `aws_s3_bucket_ownership_controls` block so we can control the ownership of objects uploaded to the bucket.

Then I set the `acl` to `private`

```hcl
resource "aws_s3_bucket_ownership_controls" "static_site_ownership" {
    bucket = aws_s3_bucket.static_site.id
    rule {
        object_ownership = "BucketOwnerPreferred"
    }
}

resource "aws_s3_bucket_acl" "static_site_acl" {
    depends_on = [ aws_s3_bucket_ownership_controls.static_site_ownership ]

    bucket = aws_s3_bucket.static_site.id
    acl    = "private"
}
```

## Bug 4

The CloudFront distribution was configured with an S3 origin but without `s3_origin_config` and an Origin Access Control, which is required for a private S3 bucket origin using SigV4.

I replaced `aws_cloudfront_origin_access_identity` with `aws_cloudfront_origin_access_control`, updated `aws_cloudfront_distribution.cdn` to use `origin_access_control_id`, and kept the bucket private with a policy allowing the CloudFront service principal to read objects from `aws_s3_bucket.static_site`.

```hcl
resource "aws_cloudfront_origin_access_control" "cdn_oac" {
  name                              = "cdn-oac"
  description                       = "OAC for S3 static site"
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
```