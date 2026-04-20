terraform {
  backend "s3" {
    bucket         = "devops-assessment-tfstate-staging"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-staging"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "repo" {
  source     = "../../modules/ecr"
  env        = "staging"
  days_keep  = 30
  tag_status = "any"
}

module "alb" {
  source = "../../modules/alb"
  name   = "staging-alb"
  env    = "staging"
}

module "ecs" {
  source                = "../../modules/ecs"
  cluster_name          = "staging-ecs"
  container_name        = "app"
  container_image       = "amazon/amazon-ecs-sample"
  container_port        = 80
  desired_count         = 2
  alb_target_group_arn  = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id
  env                   = "staging"
  cpu                   = "256"
  memory                = "512"
  assign_public_ip      = true
  subnets               = ["subnet-12345678", "subnet-876543"]
}

module "iam" {
  source = "../../modules/iam"
  name   = "staging-github-deploy-role"
  github_subjects = ["repo:Mavros619/devops-home-assessment:environment:staging"]
  ecr_repository_arn      = module.repo.ecr_repository_arn
  ecs_cluster_arn         = module.ecs.cluster_arn
  ecs_service_arn         = module.ecs.service_arn
  task_execution_role_arn = module.ecs.task_execution_role_arn
  task_role_arn           = module.ecs.task_role_arn
  env                     = "staging"
}

module "cdn" {
  source              = "../../modules/cdn"
  bucket_name         = "my-static-site-staging"
  env                 = "staging"
  oac_name            = "cdn-oac-staging"
  oac_description     = "OAC for S3 static site in staging"
  default_root_object = "index.html"
}
