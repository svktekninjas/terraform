# Outputs for Storage Module

output "image_registry_bucket_name" {
  description = "Name of the S3 bucket for image registry"
  value       = var.create_image_registry_bucket ? aws_s3_bucket.rosa_image_registry[0].bucket : null
}

output "image_registry_bucket_arn" {
  description = "ARN of the S3 bucket for image registry"
  value       = var.create_image_registry_bucket ? aws_s3_bucket.rosa_image_registry[0].arn : null
}

output "backup_bucket_name" {
  description = "Name of the S3 bucket for backups"
  value       = var.create_backup_bucket ? aws_s3_bucket.rosa_backup_bucket[0].bucket : null
}

output "backup_bucket_arn" {
  description = "ARN of the S3 bucket for backups"
  value       = var.create_backup_bucket ? aws_s3_bucket.rosa_backup_bucket[0].arn : null
}