data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_subjects
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_oidc_deploy" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json

  tags = {
    Environment = "${var.env}"
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "deploy_policy" {
  statement {
    sid    = "GitHubActionsECRAccess"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:CreateRepository",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]

    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "GitHubActionsECRAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "GitHubActionsECSDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTasks"
    ]
    resources = [
      var.ecs_cluster_arn,
      var.ecs_service_arn
    ]
  }

  statement {
    sid    = "GitHubActionsPassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      var.task_execution_role_arn,
      var.task_role_arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_oidc_deploy_policy" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.github_oidc_deploy.id
  policy = data.aws_iam_policy_document.deploy_policy.json
}
