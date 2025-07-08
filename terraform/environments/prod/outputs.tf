# Production Environment Outputs

# =============================================================================
# CLUSTER INFORMATION
# =============================================================================

output "cluster_name" {
  description = "Name of the ROSA cluster"
  value       = var.cluster_name
}

output "cluster_region" {
  description = "AWS region where cluster is deployed"
  value       = var.aws_region
}

output "openshift_version" {
  description = "OpenShift version of the cluster"
  value       = var.openshift_version
}

output "cluster_creation_status" {
  description = "Status of cluster creation"
  value       = module.compute.cluster_creation_status
}

# =============================================================================
# NETWORKING OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC (if created by Terraform)"
  value       = length(module.networking) > 0 ? module.networking[0].vpc_id : null
}

output "private_subnet_ids" {
  description = "IDs of private subnets used by ROSA cluster"
  value       = length(var.subnet_ids) > 0 ? var.subnet_ids : (length(module.networking) > 0 ? module.networking[0].private_subnet_ids : [])
}

output "public_subnet_ids" {
  description = "IDs of public subnets (if created by Terraform)"
  value       = length(module.networking) > 0 ? module.networking[0].public_subnet_ids : null
}

# =============================================================================
# SECURITY OUTPUTS
# =============================================================================

output "kms_key_arn" {
  description = "ARN of KMS key used for encryption"
  value       = module.security.kms_key_arn
}

output "kms_key_alias" {
  description = "Alias of KMS key"
  value       = module.security.kms_key_alias
}

# =============================================================================
# STORAGE OUTPUTS
# =============================================================================

output "image_registry_bucket_name" {
  description = "Name of S3 bucket for image registry (if created)"
  value       = module.storage.image_registry_bucket_name
}

output "backup_bucket_name" {
  description = "Name of S3 bucket for backups"
  value       = module.backup.etcd_backup_bucket_name
}

# =============================================================================
# MONITORING OUTPUTS
# =============================================================================

output "cloudwatch_log_groups" {
  description = "CloudWatch log groups created for monitoring"
  value       = module.monitoring.cloudwatch_log_group_names
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_url" {
  description = "URL of CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

# =============================================================================
# BACKUP OUTPUTS
# =============================================================================

output "backup_vault_arn" {
  description = "ARN of AWS Backup vault"
  value       = module.backup.backup_vault_arn
}

output "backup_plan_arn" {
  description = "ARN of AWS Backup plan"
  value       = module.backup.backup_plan_arn
}

# =============================================================================
# VALIDATION OUTPUTS
# =============================================================================

output "pre_validation_results" {
  description = "Results of pre-deployment validation"
  value       = module.validation.validation_results
}

output "post_validation_status" {
  description = "Status of post-deployment validation"
  value       = module.post_validation.all_validations_passed
}

# =============================================================================
# ROSA CLI COMMANDS
# =============================================================================

output "rosa_create_cluster_command" {
  description = "ROSA CLI command used to create the cluster"
  value       = module.compute.rosa_create_cluster_command
}

output "rosa_create_admin_command" {
  description = "ROSA CLI command used to create admin user"
  value       = module.compute.rosa_create_admin_command
}

# =============================================================================
# ACCESS INFORMATION
# =============================================================================

output "cluster_info_location" {
  description = "Location of saved cluster information files"
  value       = var.save_cluster_info ? "${var.output_dir}/" : "Not saved"
}

output "next_steps" {
  description = "Next steps after cluster creation"
  value = <<-EOT
    1. Cluster creation initiated: ${module.compute.cluster_creation_status}
    2. Check cluster status: rosa describe cluster --cluster=${var.cluster_name}
    3. Access cluster info: ${var.save_cluster_info ? "Check files in ${var.output_dir}/" : "Use rosa CLI commands"}
    4. Login to cluster: Use admin credentials from 'rosa create admin' command
    5. Access console: rosa describe cluster --cluster=${var.cluster_name} | grep "Console URL"
    6. Monitor in CloudWatch: ${module.monitoring.dashboard_url != null ? module.monitoring.dashboard_url : "Dashboard not created"}
  EOT
}

# =============================================================================
# COST INFORMATION
# =============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (approximate)"
  value = {
    disclaimer = "These are rough estimates. Actual costs may vary based on usage patterns."
    cluster_base = "~$300-400/month (3 control plane nodes)"
    worker_nodes = "~${6 * 100}-${20 * 100}/month (${6}-${20} m5.xlarge nodes)"
    storage = "~$50-200/month (EBS volumes + S3)"
    data_transfer = "~$50-500/month (depends on usage)"
    backup = "~$20-100/month (AWS Backup + S3)"
    monitoring = "~$10-50/month (CloudWatch)"
    total_estimate = "~$430-1350/month (highly variable based on actual usage)"
  }
}

# =============================================================================
# TROUBLESHOOTING INFORMATION
# =============================================================================

output "troubleshooting_commands" {
  description = "Useful commands for troubleshooting"
  value = {
    check_cluster_status = "rosa describe cluster --cluster=${var.cluster_name}"
    check_install_logs = "rosa logs install --cluster=${var.cluster_name} --watch"
    list_operator_roles = "rosa list operator-roles --cluster=${var.cluster_name}"
    check_account_roles = "rosa list account-roles"
    verify_permissions = "rosa verify permissions"
    check_quota = "rosa verify quota --region=${var.aws_region}"
    delete_cluster = "rosa delete cluster --cluster=${var.cluster_name} --yes"
  }
}