# Security
## IAM Least Privilege + GitHub OIDC to AWS

IAM roles are created with least privilege principles, granting only the necessary permissions for CI/CD operations.

GitHub OIDC is used for authentication from GitHub Actions to AWS, eliminating the need for long-lived credentials.

### Implementation

In `infra/modules/iam/main.tf`, an IAM role is created with a trust policy for GitHub OIDC provider:

```hcl
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_deploy" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_subjects
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"  # Example; adjust to least privilege
}
```

Permissions are scoped to specific ECR, ECS, and IAM resources as defined in the variables.

## Secrets in AWS Secrets Manager

Sensitive data such as database credentials, API keys, and environment-specific secrets are stored in AWS Secrets Manager.

### Implementation

Secrets are created and referenced in Terraform:

```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "securepassword"
  })
}
```

In ECS tasks, secrets are injected via environment variables or mounted volumes.

## Image Scan in CI with Trivy

Container images are scanned for vulnerabilities during CI using Trivy.

### Implementation

In GitHub Actions workflow (e.g., `.github/workflows/ci.yml`):

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'image'
    scan-ref: 'docker.io/myorg/myapp:latest'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

Failures on high-severity vulnerabilities can block deployments.

## HTTPS Everywhere: Redirect 80→443, Secure Headers at CDN/LB

All traffic is enforced over HTTPS. HTTP traffic is redirected to HTTPS.

Secure headers are added at the CDN and ALB levels.

## WAF Managed Rules Enabled in Prod

WAF is enabled in production with AWS managed rules.

### Implementation

In `infra/modules/waf/main.tf`:

```hcl
resource "aws_wafv2_web_acl" "web_acl" {
  name  = var.name
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Add more managed rules as needed

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "wafWebAcl"
    sampled_requests_enabled   = true
  }
}
```

### Exclusions

No exclusions are currently documented. If any rules cause false positives, they can be excluded by adding rule overrides with action "allow" for specific rules.
