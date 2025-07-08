# Outputs for Validation Module

output "validation_results" {
  description = "Results of pre-deployment validation checks"
  value       = local.validation_results
}

output "all_validations_passed" {
  description = "Whether all validation checks passed"
  value       = local.all_validations_passed
}

output "failed_validations" {
  description = "List of failed validation checks"
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
  value = var.enable_pre_validation ? "Enabled and executed" : "Disabled"
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