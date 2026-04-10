provider "aws" {
  region     = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

module "repo" {
  source   = "../../modules/ecr"
  env      = "prod"
  days_keep = 30
  tag_status = "any"
}

module "cdn" {
  source               = "../../modules/cdn"
  bucket_name          = "my-static-site-prod"
  env                  = "prod"
  oac_name             = "cdn-oac-prod"
  oac_description      = "OAC for S3 static site in prod"
  default_root_object  = "index.html"
}