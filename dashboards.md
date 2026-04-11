# Dashboards and Alerts for SLOs

## Dashboard
Below is a Terraform snippet that creates a CloudWatch dashboard for monitoring the SLOs, availability, latency, errors and costs.

```hcl
resource "aws_cloudwatch_dashboard" "api_monitoring" {
  dashboard_name = "API-Monitoring-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${aws_lb.alb.arn_suffix}", { "stat": "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat": "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "API Availability (Requests vs 5XX Errors)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${aws_lb.alb.arn_suffix}", { "stat": "p95" }]
          ]
          view    = "timeSeries"
          region  = "us-east-1"
          title   = "P95 Latency on /healthz"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "Currency", "USD", { "stat": "Maximum" }],
            [".", "EstimatedCharges", ".", "AmazonECS", ".", ".", { "stat": "Maximum" }],
            [".", "EstimatedCharges", ".", "AmazonCloudFront", ".", ".", { "stat": "Maximum" }]
          ]
          view    = "timeSeries"
          region  = "us-east-1"
          title   = "Daily Estimated Costs"
          period  = 86400
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${aws_lb.alb.arn_suffix}", { "stat": "Sum" }],
            ["AWS/ApplicationELB", "RequestCount", ".", ".", { "stat": "Sum" }]
          ]
          view    = "timeSeries"
          region  = "us-east-1"
          title   = "Error Rate (5XX / Total Requests)"
          period  = 300
        }
      }
    ]
  })
}
```

## Alert Rules

### 1. SLO Burn Alert
This alert triggers when the error rate exceeds a threshold that would burn the error budget too quickly. For a 99.9% availability SLO, we alert if 5-minute error rate > 0.02%.

```hcl
resource "aws_cloudwatch_metric_alarm" "slo_burn" {
  alarm_name          = "SLO-Burn-Alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0.0002 * 300
  alarm_description   = "Alert when error rate indicates fast burn of SLO budget"
  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### 2. 5-Minute Error Rate >2%
Alert when the 5-minute error rate exceeds 2%.

```hcl
resource "aws_cloudwatch_metric_alarm" "error_rate_5min" {
  alarm_name          = "5Min-Error-Rate-Alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0.02 * 300
  alarm_description   = "Alert when 5-minute error rate > 2%"
  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### 3. Daily Cost Threshold
Alert when daily estimated charges exceed $100.

```hcl
resource "aws_cloudwatch_metric_alarm" "daily_cost_threshold" {
  alarm_name          = "Daily-Cost-Threshold-Alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = 100
  alarm_description   = "Alert when daily estimated charges exceed $100"
  dimensions = {
    ServiceName = "AmazonEC2"
    Currency    = "USD"
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```
