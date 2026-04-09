# Part 1
Screenshot after first running `terraform plan`

![alt text](images/1st-tf-plan.png)

## Bug 1
The name of the bucket is different that the name that is referenced in line 8
I changed the line from `aws_s3_bucket.static.bucket_regional_domain_name` to `aws_s3_bucket.static_site.bucket_regional_domain_name`

Also fixed the warning of the argument `acl` which is deprecated and replaced it with `aws_s3_bucket_acl`
