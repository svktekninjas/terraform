# Outputs for Backup Module

output "backup_vault_name" {
  description = "Name of the AWS Backup vault"
  value       = var.enable_backup ? aws_backup_vault.rosa_backup_vault[0].name : null
}

output "backup_vault_arn" {
  description = "ARN of the AWS Backup vault"
  value       = var.enable_backup ? aws_backup_vault.rosa_backup_vault[0].arn : null
}

output "backup_plan_id" {
  description = "ID of the AWS Backup plan"
  value       = var.enable_backup ? aws_backup_plan.rosa_backup_plan[0].id : null
}

output "backup_plan_arn" {
  description = "ARN of the AWS Backup plan"
  value       = var.enable_backup ? aws_backup_plan.rosa_backup_plan[0].arn : null
}

output "backup_role_arn" {
  description = "ARN of the IAM role for AWS Backup"
  value       = var.enable_backup ? aws_iam_role.backup_role[0].arn : null
}

output "etcd_backup_bucket_name" {
  description = "Name of the S3 bucket for ETCD backups"
  value       = var.enable_etcd_backup ? aws_s3_bucket.etcd_backup_bucket[0].bucket : null
}

output "etcd_backup_bucket_arn" {
  description = "ARN of the S3 bucket for ETCD backups"
  value       = var.enable_etcd_backup ? aws_s3_bucket.etcd_backup_bucket[0].arn : null
}

output "cross_region_vault_name" {
  description = "Name of the cross-region backup vault"
  value       = var.enable_cross_region_backup ? aws_backup_vault.rosa_cross_region_vault[0].name : null
}

output "cross_region_vault_arn" {
  description = "ARN of the cross-region backup vault"
  value       = var.enable_cross_region_backup ? aws_backup_vault.rosa_cross_region_vault[0].arn : null
}