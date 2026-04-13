# Cost & Performance

## Architecture Comparison: ALB vs API Gateway vs CloudFront-Only

### Overview
For a small API service with static assets, we evaluate three architectures based on cost, performance, scalability and operational overhead. The service uses ECS for compute, ECR for images, and RDS for data.

### ALB (Application Load Balancer) + ECS
- **Description**: ALB routes traffic to ECS tasks. Static assets served via CloudFront backed by S3.
- **Cost**: ~$20-50/month (ALB: $16.43 + ECS tasks). Scales with traffic.
- **Pros**: Full control, integrates with ECS health checks, supports complex routing.
- **Cons**: Higher cost for low traffic; requires VPC/subnets.
- **Best For**: Balanced workloads with dynamic content.

### API Gateway + Lambda/ECS
- **Description**: API Gateway proxies to ECS or Lambda. Static assets via CloudFront/S3.
- **Cost**: ~$5-20/month (API Gateway: $3.50 + data transfer). Pay-per-request.
- **Pros**: Serverless, auto-scaling, built-in auth/caching.
- **Cons**: Cold starts, vendor lock-in, less control over infra.
- **Best For**: Event-driven or sporadic traffic.

### CloudFront-Only (with Lambda@Edge or S3)
- **Description**: CloudFront serves static assets from S3; dynamic requests via Lambda@Edge to ECS.
- **Cost**: ~$1-10/month (CloudFront: $0.085/GB + Lambda@Edge).
- **Pros**: Lowest cost, global CDN, serverless edge compute.
- **Cons**: Limited for complex APIs; debugging harder.
- **Best For**: Static-heavy sites with minimal dynamic logic.

### Recommendation
For this small service, use **ALB + ECS + CloudFront** for simplicity and control. Switch to API Gateway if traffic is very low and sporadic. CloudFront-only if mostly static.

## Default Autoscaling Policy and Static Asset Caching Strategy

### Autoscaling Policy
ECS service scales based on CPU/memory utilization.

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

- **Default**: Scale to maintain 70% CPU utilization, min 1, max 10 tasks.
- **Cost Impact**: Prevents over-provisioning; scales down during low traffic.

### Static Asset Caching Strategy
Use CloudFront with S3 origin for static assets (images, CSS, JS).

- **Cache Behavior**: Default TTL 86400s (1 day), compress enabled.
- **Invalidation**: Use CloudFront invalidations on deploy.
- **Cost Savings**: Reduces ALB/ECS load; CloudFront cheaper for static content.

```hcl
resource "aws_cloudfront_distribution" "cdn" {
  # ... existing config ...
  default_cache_behavior {
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    default_ttl            = 86400
    max_ttl                = 31536000
  }
}
```

## Daily Budget Guardrail with Alert and Pipeline Toggle

### Budget Guardrail
Use AWS Budgets to monitor daily spend.

```hcl
resource "aws_budgets_budget" "daily_budget" {
  name         = "daily-budget-guardrail"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "DAILY"

  cost_filters = {
    Service = "Amazon Elastic Compute Cloud - Compute"
  }

  notifications {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["alerts@example.com"]
  }
}
```

- **Alert**: Email when 80% of $100 daily budget reached.

### Pipeline Toggle to Pause Prod Deploys
In CI/CD (e.g., GitHub Actions), check budget before deploy.

```yaml
- name: Check Budget
  run: |
    BUDGET_STATUS=$(aws budgets describe-budget --budget-name daily-budget-guardrail --query 'Budget.BudgetLimit.Amount' --output text)
    if [ "$BUDGET_STATUS" -gt 8 ]; then
      echo "Budget exceeded, pausing deploy"
      exit 1
    fi
```

- **Toggle**: Fail pipeline if budget alert triggered, preventing prod deploys.
- **Cost Impact**: Prevents runaway costs by halting deploys.