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
