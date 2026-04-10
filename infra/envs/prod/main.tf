provider "aws" {
  region     = "us-east-1"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}

module "repo" {
  source     = "../../modules/ecr"
  env        = "prod"
  days_keep  = 30
  tag_status = "any"
}

module "alb" {
  source = "../../modules/alb"
  name   = "prod-alb"
  env    = "prod"
}

module "ecs" {
  source                = "../../modules/ecs"
  cluster_name          = "prod-ecs"
  container_name        = "app"
  container_image       = "amazon/amazon-ecs-sample"
  container_port        = 80
  desired_count         = 4
  alb_target_group_arn  = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id
  env                   = "prod"
  cpu                   = "256"
  memory                = "512"
  assign_public_ip      = true
  subnets               = ["subnet-12345678", "subnet-876543"]
}

module "waf" {
  source      = "../../modules/waf"
  name        = "prod-cdn-waf"
  description = "WAF for CloudFront distribution in prod"
  scope       = "CLOUDFRONT"
  env         = "prod"
}

module "cdn" {
  source              = "../../modules/cdn"
  bucket_name         = "my-static-site-prod"
  env                 = "prod"
  oac_name            = "cdn-oac-prod"
  oac_description     = "OAC for S3 static site in prod"
  default_root_object = "index.html"
  web_acl_id          = module.waf.web_acl_arn
}