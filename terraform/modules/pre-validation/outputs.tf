# Outputs for Pre-Validation Module
# Provides validation results and environment information

# =============================================================================
# VALIDATION RESULTS
# =============================================================================

output "pre_validation_results" {
  description = "Results of all pre-deployment validation checks"
  value       = local.pre_validation_results
}

output "all_validations_passed" {
  description = "Whether all pre-validation checks passed"
  value       = local.all_pre_validations_passed
}

output "failed_validations" {
  description = "List of failed pre-validation checks"
  value       = local.failed_pre_validations
}

output "validation_summary" {
  description = "Summary of validation status by type"
  value = {
    region_validation      = local.pre_validation_results.region_valid
    az_validation         = local.pre_validation_results.az_count_sufficient
    cluster_config        = local.pre_validation_results.cluster_name_valid && local.pre_validation_results.openshift_version_valid && local.pre_validation_results.instance_type_valid
    autoscaling_config    = local.pre_validation_results.autoscaling_config_valid
    environment_config    = local.pre_validation_results.environment_valid
  }
}

# =============================================================================
# ENVIRONMENT INFORMATION
# =============================================================================

output "environment_info" {
  description = "Environment-specific configuration details"
  value = {
    environment              = local.environment
    environment_config       = local.current_env_config
    region                  = data.aws_region.current.name
    availability_zones      = data.aws_availability_zones.available.names
    az_count               = length(data.aws_availability_zones.available.names)
    required_az_count      = local.current_env_config.required_az_count
  }
}

output "aws_info" {
  description = "AWS account and region information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
    user_id    = data.aws_caller_identity.current.user_id
    arn        = data.aws_caller_identity.current.arn
  }
}

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

output "cluster_config" {
  description = "Validated cluster configuration"
  value = {
    cluster_name         = var.cluster_name
    openshift_version    = var.openshift_version
    compute_machine_type = var.compute_machine_type
    enable_autoscaling   = var.enable_autoscaling
    min_replicas        = var.min_replicas
    max_replicas        = var.max_replicas
  }
}

# =============================================================================
# VALIDATION STATUS
# =============================================================================

output "validation_status" {
  description = "Status of each validation type"
  value = {
    overall_status      = local.all_pre_validations_passed ? "PASSED" : "FAILED"
    validation_enabled  = var.enable_validation
    quota_validation    = var.enable_quota_validation ? "enabled" : "disabled"
    rosa_validation     = var.enable_rosa_validation ? "enabled" : "disabled"
    environment        = local.environment
  }
}

# =============================================================================
# NEXT STEPS
# =============================================================================

output "next_steps" {
  description = "Recommended next steps based on validation results"
  value = local.all_pre_validations_passed ? [
    "✅ Pre-validation completed successfully",
    "▶️  Next: Create infrastructure with 'terraform apply -target=module.networking'",
    "▶️  Then: Run infra-validation phase",
    "📖 See documentation: docs/terraform/modules/pre-validation/"
  ] : [
    "❌ Pre-validation failed",
    "🔍 Check failed validations: ${join(", ", local.failed_pre_validations)}",
    "🛠️  Fix configuration issues and retry",
    "📖 See troubleshooting: docs/terraform/modules/pre-validation/"
  ]
}

# =============================================================================
# RESOURCE INFORMATION
# =============================================================================

output "validation_resources" {
  description = "Information about created validation resources"
  value = {
    region_validation      = var.enable_validation ? "created" : "skipped"
    az_validation         = var.enable_validation ? "created" : "skipped"
    cluster_config        = var.enable_validation ? "created" : "skipped"
    autoscaling_config    = var.enable_validation && var.enable_autoscaling ? "created" : "skipped"
    quota_validation      = var.enable_quota_validation ? "created" : "skipped"
    rosa_cli_validation   = var.enable_rosa_validation ? "created" : "skipped"
    environment_check     = var.enable_validation ? "created" : "skipped"
  }
}