# Outputs for Security Module

output "kms_key_id" {
  description = "ID of the KMS key created for ROSA cluster"
  value       = var.create_kms_key ? aws_kms_key.rosa_kms_key[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key (pass to ROSA CLI --kms-key-arn)"
  value       = var.create_kms_key ? aws_kms_key.rosa_kms_key[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = var.create_kms_key ? aws_kms_alias.rosa_kms_alias[0].name : null
}

output "additional_security_group_id" {
  description = "ID of additional security group (if created)"
  value       = var.create_additional_security_group ? aws_security_group.rosa_additional_sg[0].id : null
}