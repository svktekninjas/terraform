# Development Environment Configuration for ROSA
# Uses pre-validation module with dev-specific customizations

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  
  # Optional: Configure backend for dev environment
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket-dev"
  #   key            = "rosa/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locks-dev"
  # }
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Environment-specific configuration
  environment = "dev"
  
  # Common tags for all resources
  common_tags = {
    Project     = "ROSA"
    Environment = local.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Purpose     = "Development"
  }
  
  # Dev-specific cluster configuration
  dev_cluster_config = {
    cluster_name         = "${var.cluster_name}-${local.environment}"
    openshift_version    = var.openshift_version
    compute_machine_type = var.compute_machine_type
    enable_autoscaling   = var.enable_autoscaling
    min_replicas        = var.min_replicas
    max_replicas        = var.max_replicas
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# PRE-VALIDATION MODULE
# =============================================================================

module "pre_validation" {
  source = "../../modules/pre-validation"
  
  # Core configuration
  environment              = local.environment
  cluster_name            = local.dev_cluster_config.cluster_name
  openshift_version       = local.dev_cluster_config.openshift_version
  compute_machine_type    = local.dev_cluster_config.compute_machine_type
  
  # Autoscaling configuration
  enable_autoscaling = local.dev_cluster_config.enable_autoscaling
  min_replicas      = local.dev_cluster_config.min_replicas
  max_replicas      = local.dev_cluster_config.max_replicas
  
  # Validation control (dev-friendly)
  enable_validation        = var.enable_pre_validation
  enable_quota_validation  = var.enable_quota_validation
  enable_rosa_validation   = var.enable_rosa_validation
  verify_rosa_quota       = var.verify_rosa_quota
  verify_aws_permissions  = false  # Relaxed for dev environment
  
  # Dev-specific overrides
  environment_overrides = {
    min_vcpu_quota           = 25   # Lower requirement for dev
    cluster_ready_timeout    = 1800 # 30 minutes for dev
    required_az_count        = 2    # Relaxed AZ requirement for dev
    enable_strict_validation = false # Less strict for dev
  }
  
  # Tags
  tags = merge(local.common_tags, {
    Module = "pre-validation"
    Phase  = "pre-deployment"
  })
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "aws_region" {
  description = "AWS region for ROSA deployment"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Base name of the ROSA cluster (environment will be appended)"
  type        = string
  default     = "rosa-cluster"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 45
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, and be <= 45 characters (to allow for environment suffix)."
  }
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster"
  type        = string
  default     = "4.14"
}

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "m5.large"  # Smaller for dev environment
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for worker nodes"
  type        = bool
  default     = true
}

variable "min_replicas" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 2  # Smaller for dev
}

variable "max_replicas" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 5  # Smaller for dev
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevTeam"
}

# Validation control variables
variable "enable_pre_validation" {
  description = "Enable pre-deployment validation"
  type        = bool
  default     = true
}

variable "enable_quota_validation" {
  description = "Enable AWS quota validation"
  type        = bool
  default     = true
}

variable "enable_rosa_validation" {
  description = "Enable ROSA CLI validation"
  type        = bool
  default     = true
}

variable "verify_rosa_quota" {
  description = "Verify ROSA quota using rosa CLI"
  type        = bool
  default     = false  # Optional for dev
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "pre_validation_results" {
  description = "Results of pre-validation checks"
  value       = module.pre_validation.pre_validation_results
}

output "validation_status" {
  description = "Overall validation status"
  value       = module.pre_validation.validation_status
}

output "environment_info" {
  description = "Environment information"
  value       = module.pre_validation.environment_info
}

output "cluster_config" {
  description = "Cluster configuration to be used"
  value       = module.pre_validation.cluster_config
}

output "aws_info" {
  description = "AWS account information"
  value       = module.pre_validation.aws_info
}

output "next_steps" {
  description = "Next steps based on validation results"
  value       = module.pre_validation.next_steps
}

output "dev_environment_summary" {
  description = "Development environment summary"
  value = {
    environment     = local.environment
    cluster_name    = local.dev_cluster_config.cluster_name
    region         = var.aws_region
    instance_type  = var.compute_machine_type
    cost_optimized = true
    dev_features = [
      "Relaxed AZ requirements (2 instead of 3)",
      "Lower vCPU quota requirements",
      "Smaller instance types",
      "Reduced validation strictness",
      "Optional ROSA quota verification"
    ]
  }
}