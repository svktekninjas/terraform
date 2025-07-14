# Variables for Pre-Validation Module
# Environment-aware ROSA prerequisites validation

# =============================================================================
# CORE CONFIGURATION
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod) - determines validation strictness"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 54
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
  }
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster (format: 4.x)"
  type        = string
  default     = "4.14"
  
  validation {
    condition     = can(regex("^4\\.[0-9]+$", var.openshift_version))
    error_message = "OpenShift version must be in format 4.x (e.g., 4.14)."
  }
}

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "m5.xlarge"
}

# =============================================================================
# AUTOSCALING CONFIGURATION
# =============================================================================

variable "enable_autoscaling" {
  description = "Enable autoscaling for worker nodes"
  type        = bool
  default     = true
}

variable "min_replicas" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 2
  
  validation {
    condition     = var.min_replicas >= 1 && var.min_replicas <= 100
    error_message = "min_replicas must be between 1 and 100."
  }
}

variable "max_replicas" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 100
    error_message = "max_replicas must be between 1 and 100."
  }
}

# =============================================================================
# VALIDATION CONTROL
# =============================================================================

variable "enable_validation" {
  description = "Enable pre-validation checks"
  type        = bool
  default     = true
}

variable "enable_quota_validation" {
  description = "Enable AWS service quota validation"
  type        = bool
  default     = true
}

variable "enable_rosa_validation" {
  description = "Enable ROSA CLI prerequisites validation"
  type        = bool
  default     = true
}

variable "verify_rosa_quota" {
  description = "Verify ROSA quota using rosa CLI"
  type        = bool
  default     = true
}

variable "verify_aws_permissions" {
  description = "Verify AWS permissions using rosa CLI (strict validation)"
  type        = bool
  default     = false  # Default to false, enable for staging/prod
}

# =============================================================================
# SUPPORTED VALUES (Environment-aware)
# =============================================================================

variable "supported_regions" {
  description = "List of AWS regions supported by ROSA"
  type        = list(string)
  default = [
    # US Regions
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    # Canada
    "ca-central-1",
    # Europe
    "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3",
    # Asia Pacific
    "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
    "ap-south-1",
    # South America
    "sa-east-1"
  ]
}

variable "supported_instance_types" {
  description = "List of EC2 instance types supported by ROSA"
  type        = list(string)
  default = [
    # M5 Family - General Purpose
    "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
    # M5a Family - AMD Processors
    "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
    # M5d Family - NVMe SSD
    "m5d.large", "m5d.xlarge", "m5d.2xlarge", "m5d.4xlarge", "m5d.8xlarge", "m5d.12xlarge", "m5d.16xlarge", "m5d.24xlarge",
    # C5 Family - Compute Optimized
    "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
    # C5a Family - AMD Compute Optimized
    "c5a.large", "c5a.xlarge", "c5a.2xlarge", "c5a.4xlarge", "c5a.8xlarge", "c5a.12xlarge", "c5a.16xlarge", "c5a.24xlarge",
    # R5 Family - Memory Optimized
    "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge", "r5.12xlarge", "r5.16xlarge", "r5.24xlarge",
    # R5a Family - AMD Memory Optimized
    "r5a.large", "r5a.xlarge", "r5a.2xlarge", "r5a.4xlarge", "r5a.8xlarge", "r5a.12xlarge", "r5a.16xlarge", "r5a.24xlarge"
  ]
}

# =============================================================================
# ENVIRONMENT-SPECIFIC OVERRIDES
# =============================================================================

variable "environment_overrides" {
  description = "Environment-specific configuration overrides"
  type = object({
    min_vcpu_quota           = optional(number)
    cluster_ready_timeout    = optional(number)
    required_az_count        = optional(number)
    enable_strict_validation = optional(bool)
  })
  default = {}
}

# =============================================================================
# TAGS
# =============================================================================

variable "tags" {
  description = "Tags to apply to validation resources"
  type        = map(string)
  default = {
    Project   = "ROSA"
    ManagedBy = "Terraform"
  }
}