# Key Decisions



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

## Part 2

### EC2 vs ECS Fargate

I chose to use ECS Fargate instead of EC2 because even though EC2 is cheaper, if a sudden spike hits, you have to wait for a new EC2 instance to boot, join the cluster and then start the container. In Faragate, you don't have to provision, configure or scale clusters of virtual machines to run containers making it ideal for production use.

### Isolation approach

For this implementation, I would use a seperate AWS account because it has a hard boundary for security, billing and api quottas.

- A breach in staging is physically locked out of Production
- Easier billing as is seperated by the account
- A bug in staging can hit AWS rate limits and take down Production. With seperate accounts you avoid this.

The tradoff is the lower initial setup with isolated VPC. Also there is a network layer protection because resources of one VPC cannot communicate with resources of another VPC.

### Reduced task sizing for ECS Fargate

I reduced the below values:

- `desired_count` from 4 to 2. **Lowest value should be 2 to test rolling updates**
- `cpu` from 512 to 256. **Reduced cpu because in production we always add more to guarantee stability**
- `memory` from 1024 to 512. **Reduced memory because in production we always add more to guarantee stability**

### WAF not required in staging

You don't need WAF in staging because it reduces the complexity for internal testing as WAFs are nottoriouus for "False Positives". For example, it might block a developers's legitimate API call or a manual QA test because the payload looks "suspicious". Also is more cost efficient if you remove WAF in staging bringing the cost down.

The risk that carries is that you might write a code that works in staging but gets blocked by WAF in prodution.

### Terraform Commands

- Production

**terraform init**

```
Initializing the backend...
Initializing modules...
- alb in ../../modules/alb
- cdn in ../../modules/cdn
- ecs in ../../modules/ecs
- iam in ../../modules/iam
- repo in ../../modules/ecr
- waf in ../../modules/waf
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/tls...
- Installing hashicorp/aws v6.40.0...
- Installed hashicorp/aws v6.40.0 (signed by HashiCorp)
- Installing hashicorp/tls v4.2.1...
- Installed hashicorp/tls v4.2.1 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

**terraform plan**

Output saved in part2/tf-plan-prod.txt

- Staging

**terraform init**

```
Initializing the backend...
Initializing modules...
- alb in ../../modules/alb
- cdn in ../../modules/cdn
- ecs in ../../modules/ecs
- iam in ../../modules/iam
- repo in ../../modules/ecr
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Finding latest version of hashicorp/tls...
- Installing hashicorp/aws v6.40.0...
- Installed hashicorp/aws v6.40.0 (signed by HashiCorp)
- Installing hashicorp/tls v4.2.1...
- Installed hashicorp/tls v4.2.1 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

**terraform plan**

Output saved in part2/tf-plan-staging.txt

