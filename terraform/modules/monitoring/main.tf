# Monitoring Module for ROSA CLI Integration
# Creates CloudWatch resources for additional monitoring (ROSA has built-in Prometheus/Grafana)

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module = "monitoring"
      Purpose = "ROSA-Monitoring"
    }
  )
}

# =============================================================================
# CLOUDWATCH LOG GROUPS (for ROSA cluster logs)
# =============================================================================

resource "aws_cloudwatch_log_group" "rosa_cluster_logs" {
  count = var.enable_cloudwatch_logging ? 1 : 0
  
  name              = "/aws/rosa/${var.cluster_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-logs"
    Type = "ClusterLogs"
  })
}

resource "aws_cloudwatch_log_group" "rosa_audit_logs" {
  count = var.enable_audit_logs ? 1 : 0
  
  name              = "/aws/rosa/${var.cluster_name}/audit"
  retention_in_days = var.audit_log_retention_days
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-audit-logs"
    Type = "AuditLogs"
  })
}

resource "aws_cloudwatch_log_group" "rosa_application_logs" {
  count = var.enable_application_logs ? 1 : 0
  
  name              = "/aws/rosa/${var.cluster_name}/application"
  retention_in_days = var.application_log_retention_days
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-application-logs"
    Type = "ApplicationLogs"
  })
}

# =============================================================================
# CLOUDWATCH ALARMS (for infrastructure monitoring)
# =============================================================================

# SNS Topic for alerts
resource "aws_sns_topic" "rosa_alerts" {
  count = var.enable_alerts ? 1 : 0
  
  name         = "${var.cluster_name}-rosa-alerts"
  display_name = "ROSA Cluster ${var.cluster_name} Alerts"
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alerts"
  })
}

# SNS Topic Subscription for email alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.enable_alerts && var.alert_email != "" ? 1 : 0
  
  topic_arn = aws_sns_topic.rosa_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Metric Filters for log-based alerts
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  count = var.enable_cloudwatch_logging && var.enable_alerts ? 1 : 0
  
  name           = "${var.cluster_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.rosa_cluster_logs[0].name
  pattern        = "ERROR"
  
  metric_transformation {
    name      = "${var.cluster_name}-ErrorCount"
    namespace = "ROSA/Cluster"
    value     = "1"
  }
}

# CloudWatch Alarm for error rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.enable_cloudwatch_logging && var.enable_alerts ? 1 : 0
  
  alarm_name          = "${var.cluster_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "${var.cluster_name}-ErrorCount"
  namespace           = "ROSA/Cluster"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  alarm_description   = "This metric monitors error rate in ROSA cluster ${var.cluster_name}"
  alarm_actions       = [aws_sns_topic.rosa_alerts[0].arn]
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-high-error-rate-alarm"
  })
}

# =============================================================================
# CLOUDWATCH DASHBOARD (Optional)
# =============================================================================

resource "aws_cloudwatch_dashboard" "rosa_dashboard" {
  count = var.create_dashboard ? 1 : 0
  
  dashboard_name = "${var.cluster_name}-rosa-dashboard"
  
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
            ["ROSA/Cluster", "${var.cluster_name}-ErrorCount"],
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Error Count"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        
        properties = {
          query   = "SOURCE '/aws/rosa/${var.cluster_name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = data.aws_region.current.name
          title   = "Recent Cluster Logs"
          view    = "table"
        }
      }
    ]
  })
}

# =============================================================================
# CUSTOM METRICS (for application monitoring)
# =============================================================================

# Custom namespace for application metrics
resource "aws_cloudwatch_metric_stream" "rosa_metric_stream" {
  count = var.enable_metric_stream ? 1 : 0
  
  name          = "${var.cluster_name}-metric-stream"
  firehose_arn  = var.firehose_delivery_stream_arn
  role_arn      = var.metric_stream_role_arn
  output_format = "json"
  
  include_filter {
    namespace = "ROSA/Application"
  }
  
  include_filter {
    namespace = "ROSA/Cluster"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-metric-stream"
  })
}