# Pre-Validation Module for ROSA
# Validates prerequisites before any infrastructure creation
# Environment-aware with customizations from environments/{env} folder

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Environment-specific configuration
  environment = var.environment
  
  # Load environment-specific defaults
  env_config = {
    dev = {
      min_vcpu_quota           = 50
      cluster_ready_timeout    = 1800  # 30 minutes
      required_az_count        = 2     # Relaxed for dev
      enable_strict_validation = false
    }
    staging = {
      min_vcpu_quota           = 100
      cluster_ready_timeout    = 2400  # 40 minutes
      required_az_count        = 3
      enable_strict_validation = true
    }
    prod = {
      min_vcpu_quota           = 200
      cluster_ready_timeout    = 3600  # 60 minutes
      required_az_count        = 3
      enable_strict_validation = true
    }
  }
  
  # Get environment-specific settings
  current_env_config = local.env_config[local.environment]
  
  # Pre-validation results
  pre_validation_results = {
    # AWS Infrastructure Prerequisites
    region_valid = contains(var.supported_regions, data.aws_region.current.name)
    
    # AZ validation (environment-aware)
    az_count_sufficient = length(data.aws_availability_zones.available.names) >= local.current_env_config.required_az_count
    
    # Cluster Configuration
    cluster_name_valid = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 54
    openshift_version_valid = can(regex("^4\\.[0-9]+$", var.openshift_version))
    instance_type_valid = contains(var.supported_instance_types, var.compute_machine_type)
    
    # Autoscaling Configuration
    autoscaling_config_valid = !var.enable_autoscaling || (var.min_replicas <= var.max_replicas && var.min_replicas >= 1)
    
    # Environment-specific validation
    environment_valid = contains(["dev", "staging", "prod"], local.environment)
  }
  
  # Overall validation status
  all_pre_validations_passed = alltrue(values(local.pre_validation_results))
  
  # Failed validations
  failed_pre_validations = [
    for key, value in local.pre_validation_results : key if !value
  ]
  
  # Common tags
  common_tags = merge(var.tags, {
    Environment     = local.environment
    ValidationPhase = "pre"
    Module          = "pre-validation"
    ManagedBy       = "Terraform"
  })
}

# =============================================================================
# PRE-VALIDATION: AWS REGION SUPPORT
# =============================================================================

resource "null_resource" "pre_validate_region" {
  count = var.enable_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.region_valid
      error_message = "Region ${data.aws_region.current.name} is not supported for ROSA. Supported regions: ${join(", ", var.supported_regions)}"
    }
  }
  
  triggers = {
    region      = data.aws_region.current.name
    environment = local.environment
  }
  
}

# =============================================================================
# PRE-VALIDATION: AVAILABILITY ZONES
# =============================================================================

resource "null_resource" "pre_validate_availability_zones" {
  count = var.enable_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.az_count_sufficient
      error_message = "Region must have at least ${local.current_env_config.required_az_count} availability zones for ${local.environment} environment. Current region has ${length(data.aws_availability_zones.available.names)} AZs."
    }
  }
  
  triggers = {
    az_count           = length(data.aws_availability_zones.available.names)
    required_az_count  = local.current_env_config.required_az_count
    environment        = local.environment
  }
  
}

# =============================================================================
# PRE-VALIDATION: CLUSTER CONFIGURATION
# =============================================================================

resource "null_resource" "pre_validate_cluster_config" {
  count = var.enable_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.cluster_name_valid
      error_message = "Cluster name '${var.cluster_name}' must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
    }
    
    precondition {
      condition     = local.pre_validation_results.openshift_version_valid
      error_message = "OpenShift version '${var.openshift_version}' must be in format 4.x (e.g., 4.14)."
    }
    
    precondition {
      condition     = local.pre_validation_results.instance_type_valid
      error_message = "Compute machine type '${var.compute_machine_type}' is not supported. Supported types: ${join(", ", slice(var.supported_instance_types, 0, 10))}..."
    }
    
    precondition {
      condition     = local.pre_validation_results.environment_valid
      error_message = "Environment '${local.environment}' is not valid. Supported environments: dev, staging, prod."
    }
  }
  
  triggers = {
    cluster_name         = var.cluster_name
    openshift_version    = var.openshift_version
    compute_machine_type = var.compute_machine_type
    environment          = local.environment
  }
  
}

# =============================================================================
# PRE-VALIDATION: AUTOSCALING CONFIGURATION
# =============================================================================

resource "null_resource" "pre_validate_autoscaling" {
  count = var.enable_validation && var.enable_autoscaling ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.pre_validation_results.autoscaling_config_valid
      error_message = "Autoscaling configuration invalid: min_replicas (${var.min_replicas}) must be <= max_replicas (${var.max_replicas}) and >= 1."
    }
  }
  
  triggers = {
    enable_autoscaling = var.enable_autoscaling
    min_replicas       = var.min_replicas
    max_replicas       = var.max_replicas
    environment        = local.environment
  }
  
}

# =============================================================================
# PRE-VALIDATION: AWS SERVICE QUOTAS
# =============================================================================

resource "null_resource" "pre_validate_quotas" {
  count = var.enable_quota_validation ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=== AWS Service Quota Validation for ${local.environment} Environment ==="
      
      # Source environment variables if export script exists
      ENV_SCRIPT="../../../environments/${local.environment}/export_env.sh"
      if [ -f "$ENV_SCRIPT" ]; then
        echo "Sourcing environment variables from $ENV_SCRIPT"
        source "$ENV_SCRIPT"
      fi
      
      # Check EC2 vCPU limits
      echo "Checking EC2 vCPU quota in region: ${data.aws_region.current.name}"
      
      VCPU_LIMIT=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-34B43A08 \
        --region ${data.aws_region.current.name} \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")
      
      echo "Current vCPU limit: $VCPU_LIMIT"
      echo "Required minimum for ${local.environment}: ${local.current_env_config.min_vcpu_quota}"
      
      if [ "$VCPU_LIMIT" -lt "${local.current_env_config.min_vcpu_quota}" ]; then
        echo "ERROR: EC2 vCPU limit ($VCPU_LIMIT) is below required minimum (${local.current_env_config.min_vcpu_quota}) for ${local.environment} environment"
        exit 1
      fi
      
      echo "✅ AWS quota validation passed for ${local.environment}"
    EOT
  }
  
  triggers = {
    region            = data.aws_region.current.name
    min_vcpu_quota    = local.current_env_config.min_vcpu_quota
    environment       = local.environment
    validation_time   = timestamp()
  }
  
}

# =============================================================================
# PRE-VALIDATION: ROSA CLI PREREQUISITES
# =============================================================================

resource "null_resource" "pre_validate_rosa_cli" {
  count = var.enable_rosa_validation ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=== ROSA CLI Prerequisites Validation for ${local.environment} Environment ==="
      
      # Source environment variables if export script exists
      ENV_SCRIPT="../../../environments/${local.environment}/export_env.sh"
      if [ -f "$ENV_SCRIPT" ]; then
        echo "Sourcing environment variables from $ENV_SCRIPT"
        source "$ENV_SCRIPT"
      fi
      
      # Check if ROSA CLI is installed
      if ! command -v rosa &> /dev/null; then
        echo "ERROR: ROSA CLI is not installed"
        echo "Install with: curl -L https://github.com/openshift/rosa/releases/latest/download/rosa-linux.tar.gz | tar -xz && sudo mv rosa /usr/local/bin/"
        exit 1
      fi
      
      # Check ROSA CLI version
      ROSA_VERSION=$(rosa version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
      echo "ROSA CLI version: $ROSA_VERSION"
      
      # Check AWS CLI
      if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI is not installed"
        exit 1
      fi
      
      AWS_VERSION=$(aws --version 2>&1 | head -n1)
      echo "AWS CLI version: $AWS_VERSION"
      
      # Verify AWS credentials
      echo "Verifying AWS credentials..."
      AWS_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null || echo "{}")
      AWS_ACCOUNT=$(echo "$AWS_IDENTITY" | jq -r '.Account // "unknown"')
      AWS_USER=$(echo "$AWS_IDENTITY" | jq -r '.Arn // "unknown"')
      
      if [ "$AWS_ACCOUNT" = "unknown" ]; then
        echo "ERROR: AWS credentials not configured or invalid"
        exit 1
      fi
      
      echo "AWS Account: $AWS_ACCOUNT"
      echo "AWS Identity: $AWS_USER"
      
      # Verify ROSA quota (if enabled)
      if [ "${var.verify_rosa_quota}" = "true" ]; then
        echo "Verifying ROSA quota for region: ${data.aws_region.current.name}"
        rosa verify quota --region=${data.aws_region.current.name} || {
          echo "ERROR: ROSA quota verification failed"
          exit 1
        }
      fi
      
      # Verify AWS permissions (if enabled and not in dev environment)
      if [ "${var.verify_aws_permissions}" = "true" ] && [ "${local.environment}" != "dev" ]; then
        echo "Verifying AWS permissions..."
        rosa verify permissions || {
          echo "WARNING: AWS permissions verification failed (may be expected in ${local.environment})"
          if [ "${local.current_env_config.enable_strict_validation}" = "true" ]; then
            exit 1
          fi
        }
      fi
      
      echo "✅ ROSA CLI validation passed for ${local.environment}"
    EOT
  }
  
  triggers = {
    region                   = data.aws_region.current.name
    verify_rosa_quota        = var.verify_rosa_quota
    verify_aws_permissions   = var.verify_aws_permissions
    environment              = local.environment
    validation_time          = timestamp()
  }
  
}

# =============================================================================
# PRE-VALIDATION: ENVIRONMENT READINESS CHECK
# =============================================================================

resource "null_resource" "pre_validate_environment" {
  count = var.enable_validation ? 1 : 0
  
  depends_on = [
    null_resource.pre_validate_region,
    null_resource.pre_validate_availability_zones,
    null_resource.pre_validate_cluster_config,
    null_resource.pre_validate_autoscaling,
    null_resource.pre_validate_quotas,
    null_resource.pre_validate_rosa_cli
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Pre-Validation Summary for ${local.environment} Environment ==="
      echo "✅ Region validation: ${data.aws_region.current.name}"
      echo "✅ Availability zones: ${length(data.aws_availability_zones.available.names)} (required: ${local.current_env_config.required_az_count})"
      echo "✅ Cluster configuration: ${var.cluster_name}"
      echo "✅ OpenShift version: ${var.openshift_version}"
      echo "✅ Instance type: ${var.compute_machine_type}"
      echo "✅ Environment: ${local.environment}"
      echo ""
      echo "🎉 All pre-validation checks passed for ${local.environment} environment!"
      echo "Ready to proceed with infrastructure creation."
    EOT
  }
  
  triggers = {
    validation_complete = timestamp()
    environment        = local.environment
  }
  
}