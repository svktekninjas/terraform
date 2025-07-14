# Demo Pre-Validation (No AWS Credentials Required)
# This demonstrates the validation logic without requiring active AWS credentials

# =============================================================================
# MOCK DATA SOURCES (for demo purposes)
# =============================================================================

locals {
  # Mock AWS data (normally from data sources)
  mock_aws_data = {
    account_id = "123456789012"
    region     = "us-east-1"
    user_arn   = "arn:aws:iam::123456789012:user/demo-user"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
  
  # Environment configuration (same as real module)
  environment = "dev"
  
  env_config = {
    dev = {
      min_vcpu_quota           = 25
      cluster_ready_timeout    = 1800
      required_az_count        = 2
      enable_strict_validation = false
    }
  }
  
  current_env_config = local.env_config[local.environment]
  
  # Demo cluster configuration
  cluster_config = {
    cluster_name         = "rosa-cluster-dev"
    openshift_version    = "4.14"
    compute_machine_type = "m5.large"
    enable_autoscaling   = true
    min_replicas        = 2
    max_replicas        = 5
  }
  
  # Validation results (same logic as real module)
  pre_validation_results = {
    region_valid = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "ca-central-1", "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3",
      "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
      "ap-south-1", "sa-east-1"
    ], local.mock_aws_data.region)
    
    az_count_sufficient = length(local.mock_aws_data.availability_zones) >= local.current_env_config.required_az_count
    
    cluster_name_valid = can(regex("^[a-z0-9-]+$", local.cluster_config.cluster_name)) && length(local.cluster_config.cluster_name) <= 54
    
    openshift_version_valid = can(regex("^4\\.[0-9]+$", local.cluster_config.openshift_version))
    
    instance_type_valid = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge"
    ], local.cluster_config.compute_machine_type)
    
    autoscaling_config_valid = !local.cluster_config.enable_autoscaling || (local.cluster_config.min_replicas <= local.cluster_config.max_replicas && local.cluster_config.min_replicas >= 1)
    
    environment_valid = contains(["dev", "staging", "prod"], local.environment)
  }
  
  all_validations_passed = alltrue(values(local.pre_validation_results))
  
  failed_validations = [
    for key, value in local.pre_validation_results : key if !value
  ]
}

# =============================================================================
# DEMO VALIDATION RESOURCES
# =============================================================================

resource "null_resource" "demo_region_validation" {
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.region_valid
      error_message = "Region ${local.mock_aws_data.region} is not supported for ROSA."
    }
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=================================================="
      echo "🔍 ROSA Pre-Validation Demo - Region Check"
      echo "=================================================="
      echo "✅ Region: ${local.mock_aws_data.region}"
      echo "✅ Region supported: ${local.pre_validation_results.region_valid}"
      echo "✅ Environment: ${local.environment}"
      echo ""
    EOT
  }
  
  triggers = {
    region      = local.mock_aws_data.region
    environment = local.environment
  }
}

resource "null_resource" "demo_az_validation" {
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.az_count_sufficient
      error_message = "Region must have at least ${local.current_env_config.required_az_count} availability zones for ${local.environment} environment. Current region has ${length(local.mock_aws_data.availability_zones)} AZs."
    }
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Availability Zones Validation"
      echo "✅ Available AZs: ${join(", ", local.mock_aws_data.availability_zones)}"
      echo "✅ AZ count: ${length(local.mock_aws_data.availability_zones)}"
      echo "✅ Required for ${local.environment}: ${local.current_env_config.required_az_count}"
      echo "✅ Sufficient AZs: ${local.pre_validation_results.az_count_sufficient}"
      echo ""
    EOT
  }
  
  triggers = {
    az_count          = length(local.mock_aws_data.availability_zones)
    required_az_count = local.current_env_config.required_az_count
    environment       = local.environment
  }
}

resource "null_resource" "demo_cluster_config_validation" {
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.cluster_name_valid
      error_message = "Cluster name '${local.cluster_config.cluster_name}' must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
    }
    
    precondition {
      condition     = local.pre_validation_results.openshift_version_valid
      error_message = "OpenShift version '${local.cluster_config.openshift_version}' must be in format 4.x (e.g., 4.14)."
    }
    
    precondition {
      condition     = local.pre_validation_results.instance_type_valid
      error_message = "Compute machine type '${local.cluster_config.compute_machine_type}' is not supported."
    }
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Cluster Configuration Validation"
      echo "✅ Cluster name: ${local.cluster_config.cluster_name}"
      echo "✅ Name valid: ${local.pre_validation_results.cluster_name_valid}"
      echo "✅ OpenShift version: ${local.cluster_config.openshift_version}"
      echo "✅ Version valid: ${local.pre_validation_results.openshift_version_valid}"
      echo "✅ Instance type: ${local.cluster_config.compute_machine_type}"
      echo "✅ Instance type valid: ${local.pre_validation_results.instance_type_valid}"
      echo ""
    EOT
  }
  
  triggers = {
    cluster_name         = local.cluster_config.cluster_name
    openshift_version    = local.cluster_config.openshift_version
    compute_machine_type = local.cluster_config.compute_machine_type
    environment          = local.environment
  }
}

resource "null_resource" "demo_autoscaling_validation" {
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.autoscaling_config_valid
      error_message = "Autoscaling configuration invalid: min_replicas (${local.cluster_config.min_replicas}) must be <= max_replicas (${local.cluster_config.max_replicas}) and >= 1."
    }
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Autoscaling Configuration Validation"
      echo "✅ Autoscaling enabled: ${local.cluster_config.enable_autoscaling}"
      echo "✅ Min replicas: ${local.cluster_config.min_replicas}"
      echo "✅ Max replicas: ${local.cluster_config.max_replicas}"
      echo "✅ Configuration valid: ${local.pre_validation_results.autoscaling_config_valid}"
      echo ""
    EOT
  }
  
  triggers = {
    enable_autoscaling = local.cluster_config.enable_autoscaling
    min_replicas       = local.cluster_config.min_replicas
    max_replicas       = local.cluster_config.max_replicas
    environment        = local.environment
  }
}

resource "null_resource" "demo_validation_summary" {
  depends_on = [
    null_resource.demo_region_validation,
    null_resource.demo_az_validation,
    null_resource.demo_cluster_config_validation,
    null_resource.demo_autoscaling_validation
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=================================================="
      echo "🎉 ROSA Pre-Validation Demo Summary"
      echo "=================================================="
      echo "Environment: ${local.environment}"
      echo "Overall Status: ${local.all_validations_passed ? "✅ PASSED" : "❌ FAILED"}"
      echo ""
      echo "Validation Results:"
      echo "  ✅ Region Support: ${local.pre_validation_results.region_valid}"
      echo "  ✅ Availability Zones: ${local.pre_validation_results.az_count_sufficient}"
      echo "  ✅ Cluster Name: ${local.pre_validation_results.cluster_name_valid}"
      echo "  ✅ OpenShift Version: ${local.pre_validation_results.openshift_version_valid}"
      echo "  ✅ Instance Type: ${local.pre_validation_results.instance_type_valid}"
      echo "  ✅ Autoscaling Config: ${local.pre_validation_results.autoscaling_config_valid}"
      echo "  ✅ Environment: ${local.pre_validation_results.environment_valid}"
      echo ""
      echo "Environment Configuration:"
      echo "  📍 Region: ${local.mock_aws_data.region}"
      echo "  🏗️  Required AZs: ${local.current_env_config.required_az_count}"
      echo "  💰 Min vCPU Quota: ${local.current_env_config.min_vcpu_quota}"
      echo "  ⏱️  Timeout: ${local.current_env_config.cluster_ready_timeout}s"
      echo "  🔒 Strict Validation: ${local.current_env_config.enable_strict_validation}"
      echo ""
      echo "Cluster Configuration:"
      echo "  🏷️  Name: ${local.cluster_config.cluster_name}"
      echo "  🚀 Version: ${local.cluster_config.openshift_version}"
      echo "  💻 Instance: ${local.cluster_config.compute_machine_type}"
      echo "  📈 Replicas: ${local.cluster_config.min_replicas}-${local.cluster_config.max_replicas}"
      echo ""
      if [ "${local.all_validations_passed}" = "true" ]; then
        echo "✅ All pre-validation checks passed!"
        echo "▶️  Next Steps:"
        echo "   1. Create infrastructure: terraform apply -target=module.networking"
        echo "   2. Run infra-validation phase"
        echo "   3. Create ROSA cluster"
        echo "   4. Run post-validation phase"
      else
        echo "❌ Some validations failed:"
        echo "   Failed checks: ${join(", ", local.failed_validations)}"
        echo "   Please fix configuration and retry"
      fi
      echo "=================================================="
    EOT
  }
  
  triggers = {
    validation_complete = timestamp()
    environment        = local.environment
    all_passed         = local.all_validations_passed
  }
}

# =============================================================================
# DEMO OUTPUTS
# =============================================================================

output "demo_validation_results" {
  description = "Demo validation results"
  value       = local.pre_validation_results
}

output "demo_validation_status" {
  description = "Demo validation status"
  value = {
    overall_status = local.all_validations_passed ? "PASSED" : "FAILED"
    environment   = local.environment
    failed_checks = local.failed_validations
  }
}

output "demo_environment_info" {
  description = "Demo environment information"
  value = {
    environment       = local.environment
    region           = local.mock_aws_data.region
    availability_zones = local.mock_aws_data.availability_zones
    az_count         = length(local.mock_aws_data.availability_zones)
    required_az_count = local.current_env_config.required_az_count
    config           = local.current_env_config
  }
}

output "demo_cluster_config" {
  description = "Demo cluster configuration"
  value       = local.cluster_config
}