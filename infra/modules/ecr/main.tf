resource "aws_ecr_repository" "repo" {
  name                 = "${var.env}-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.days_keep} images"
        selection = {
          tagStatus     = var.tag_status
          countType     = "imageCountMoreThan"
          countNumber   = var.days_keep
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
