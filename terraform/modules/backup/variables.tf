# Variables for Backup Module

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "enable_backup" {
  description = "Enable AWS Backup for ROSA cluster resources"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for backup encryption"
  type        = string
  default     = ""
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "cron(0 2 ? * * *)"
}

variable "backup_start_window" {
  description = "Backup start window in minutes"
  type        = number
  default     = 60
}

variable "backup_completion_window" {
  description = "Backup completion window in minutes"
  type        = number
  default     = 480
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 90
}

variable "backup_cold_storage_after" {
  description = "Days after which to move backups to cold storage"
  type        = number
  default     = 30
}

variable "enable_weekly_backup" {
  description = "Enable weekly backup with longer retention"
  type        = bool
  default     = true
}

variable "weekly_backup_schedule" {
  description = "Cron expression for weekly backup schedule"
  type        = string
  default     = "cron(0 3 ? * SUN *)"
}

variable "weekly_backup_retention_days" {
  description = "Weekly backup retention period in days"
  type        = number
  default     = 365
}

variable "weekly_backup_cold_storage_after" {
  description = "Days after which to move weekly backups to cold storage"
  type        = number
  default     = 90
}

variable "backup_resource_arns" {
  description = "List of specific resource ARNs to backup"
  type        = list(string)
  default     = []
}

variable "backup_selection_tags" {
  description = "Tags to select resources for backup"
  type        = map(string)
  default     = {}
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup for disaster recovery"
  type        = bool
  default     = false
}

variable "cross_region_kms_key_arn" {
  description = "ARN of KMS key in backup region"
  type        = string
  default     = ""
}

variable "cross_region_backup_schedule" {
  description = "Cron expression for cross-region backup schedule"
  type        = string
  default     = "cron(0 4 ? * * *)"
}

variable "cross_region_retention_days" {
  description = "Cross-region backup retention period in days"
  type        = number
  default     = 365
}

variable "cross_region_cold_storage_after" {
  description = "Days after which to move cross-region backups to cold storage"
  type        = number
  default     = 90
}

variable "enable_etcd_backup" {
  description = "Enable ETCD backup to S3"
  type        = bool
  default     = true
}

variable "etcd_backup_retention_days" {
  description = "ETCD backup retention period in days"
  type        = number
  default     = 30
}

variable "force_destroy_backup_bucket" {
  description = "Allow backup bucket to be destroyed even if not empty"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all backup resources"
  type        = map(string)
  default     = {}
}