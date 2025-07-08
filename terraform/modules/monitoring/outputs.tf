# Outputs for Monitoring Module

output "cloudwatch_log_group_names" {
  description = "Names of CloudWatch log groups created"
  value = compact([
    var.enable_cloudwatch_logging ? aws_cloudwatch_log_group.rosa_cluster_logs[0].name : "",
    var.enable_audit_logs ? aws_cloudwatch_log_group.rosa_audit_logs[0].name : "",
    var.enable_application_logs ? aws_cloudwatch_log_group.rosa_application_logs[0].name : ""
  ])
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = var.enable_alerts ? aws_sns_topic.rosa_alerts[0].arn : null
}

output "dashboard_url" {
  description = "URL of CloudWatch dashboard"
  value       = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.rosa_dashboard[0].dashboard_name}" : null
}

output "metric_stream_name" {
  description = "Name of CloudWatch metric stream"
  value       = var.enable_metric_stream ? aws_cloudwatch_metric_stream.rosa_metric_stream[0].name : null
}