# Variables for Monitoring Module

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "enable_cloudwatch_logging" {
  description = "Enable CloudWatch logging for ROSA cluster"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "enable_audit_logs" {
  description = "Enable audit log collection"
  type        = bool
  default     = true
}

variable "audit_log_retention_days" {
  description = "Audit log retention in days"
  type        = number
  default     = 365
}

variable "enable_application_logs" {
  description = "Enable application log collection"
  type        = bool
  default     = false
}

variable "application_log_retention_days" {
  description = "Application log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = ""
}

variable "enable_alerts" {
  description = "Enable CloudWatch alerts"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}

variable "error_rate_threshold" {
  description = "Threshold for error rate alarm"
  type        = number
  default     = 10
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "enable_metric_stream" {
  description = "Enable CloudWatch metric stream"
  type        = bool
  default     = false
}

variable "firehose_delivery_stream_arn" {
  description = "ARN of Kinesis Data Firehose delivery stream for metric stream"
  type        = string
  default     = ""
}

variable "metric_stream_role_arn" {
  description = "ARN of IAM role for metric stream"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all monitoring resources"
  type        = map(string)
  default     = {}
}