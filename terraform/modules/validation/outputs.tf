# Outputs for Validation Module

output "pre_validation_results" {
  description = "Results of pre-deployment validation checks"
  value       = local.pre_validation_results
}

output "infra_validation_results" {
  description = "Results of infrastructure validation checks"
  value       = local.infra_validation_results
}

output "validation_results" {
  description = "Combined validation results (for backward compatibility)"
  value       = local.validation_results
}

output "all_validations_passed" {
  description = "Whether all validation checks passed"
  value       = local.all_validations_passed
}

output "failed_pre_validations" {
  description = "List of failed pre-deployment validation checks"
  value       = local.failed_pre_validations
}

output "failed_infra_validations" {
  description = "List of failed infrastructure validation checks"
  value       = local.failed_infra_validations
}

output "failed_validations" {
  description = "List of all failed validation checks"
  value       = local.failed_validations
}

output "region_info" {
  description = "Information about the current AWS region"
  value = {
    region              = data.aws_region.current.name
    availability_zones  = data.aws_availability_zones.available.names
    az_count           = length(data.aws_availability_zones.available.names)
  }
}

output "pre_validation_status" {
  description = "Status of pre-deployment validation"
  value = var.enable_pre_validation ? "Enabled" : "Disabled"
}

output "infra_validation_status" {
  description = "Status of infrastructure validation"
  value = var.enable_infra_validation ? "Enabled" : "Disabled"
}

output "post_validation_status" {
  description = "Status of post-deployment validation"
  value = var.enable_post_validation ? "Enabled" : "Disabled"
}

output "quota_validation_status" {
  description = "Status of AWS quota validation"
  value = var.enable_quota_validation ? "Enabled" : "Disabled"
}

output "rosa_validation_status" {
  description = "Status of ROSA CLI validation"
  value = var.enable_rosa_validation ? "Enabled" : "Disabled"
}