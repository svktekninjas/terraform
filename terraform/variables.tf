# ROSA CLI Variables File
# Focused on inputs for ROSA CLI cluster creation and management

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
  default     = "rosa-cluster"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 54
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
  }
}

variable "aws_region" {
  description = "AWS region for ROSA deployment"
  type        = string
  default     = "us-east-1"
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster"
  type        = string
  default     = "4.14"
}

variable "multi_az" {
  description = "Deploy cluster across multiple availability zones"
  type        = bool
  default     = true
}

# =============================================================================
# COMPUTE CONFIGURATION
# =============================================================================

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "m5.xlarge"
  
  validation {
    condition = contains([
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge"
    ], var.compute_machine_type)
    error_message = "Compute machine type must be ROSA-compatible."
  }
}

variable "compute_nodes" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
  
  validation {
    condition     = var.compute_nodes >= 2 && var.compute_nodes <= 100
    error_message = "Worker node count must be between 2 and 100."
  }
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for worker nodes"
  type        = bool
  default     = true
}

variable "min_replicas" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
  default     = 3
}

variable "max_replicas" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
  default     = 10
}

# =============================================================================
# NETWORKING CONFIGURATION
# =============================================================================

variable "subnet_ids" {
  description = "List of subnet IDs for ROSA cluster (leave empty for ROSA to create VPC)"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "List of availability zones (leave empty for ROSA to select)"
  type        = list(string)
  default     = []
}

variable "host_prefix" {
  description = "Subnet prefix length for node IP assignment"
  type        = number
  default     = 23
  
  validation {
    condition     = var.host_prefix >= 23 && var.host_prefix <= 26
    error_message = "Host prefix must be between 23 and 26."
  }
}

variable "machine_cidr" {
  description = "CIDR block for machines"
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = "172.30.0.0/16"
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.128.0.0/14"
}

variable "private" {
  description = "Create private cluster"
  type        = bool
  default     = false
}

variable "private_link" {
  description = "Use AWS PrivateLink for cluster connectivity"
  type        = bool
  default     = false
}

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

variable "enable_sts" {
  description = "Use AWS Security Token Service (STS)"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of the AWS IAM role for ROSA installer (leave empty for ROSA to create)"
  type        = string
  default     = ""
}

variable "support_role_arn" {
  description = "ARN of the AWS IAM role for Red Hat support (leave empty for ROSA to create)"
  type        = string
  default     = ""
}

variable "operator_roles_prefix" {
  description = "Prefix for operator IAM roles"
  type        = string
  default     = ""
}

variable "oidc_config_id" {
  description = "OpenID Connect configuration ID (leave empty for ROSA to create)"
  type        = string
  default     = ""
}

variable "enable_fips" {
  description = "Enable FIPS mode for cluster"
  type        = bool
  default     = false
}

variable "enable_etcd_encryption" {
  description = "Enable additional etcd encryption"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (leave empty for default)"
  type        = string
  default     = ""
}

variable "disable_scp_checks" {
  description = "Disable Service Control Policy checks"
  type        = bool
  default     = false
}

variable "enable_external_oidc" {
  description = "Enable external OIDC configuration"
  type        = bool
  default     = false
}

# =============================================================================
# CLUSTER FEATURES
# =============================================================================

variable "disable_user_workload_monitoring" {
  description = "Disable user workload monitoring"
  type        = bool
  default     = false
}

variable "enable_proxy" {
  description = "Enable HTTP/HTTPS proxy"
  type        = bool
  default     = false
}

variable "http_proxy" {
  description = "HTTP proxy URL"
  type        = string
  default     = ""
}

variable "https_proxy" {
  description = "HTTPS proxy URL"
  type        = string
  default     = ""
}

variable "no_proxy" {
  description = "No proxy domains"
  type        = string
  default     = ""
}

variable "additional_trust_bundle" {
  description = "Path to additional trust bundle file"
  type        = string
  default     = ""
}

# =============================================================================
# ADMIN USER CONFIGURATION
# =============================================================================

variable "create_admin_user" {
  description = "Create cluster admin user"
  type        = bool
  default     = true
}

variable "admin_username" {
  description = "Admin username (leave empty for default 'cluster-admin')"
  type        = string
  default     = ""
}

variable "admin_password" {
  description = "Admin password (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# INSTALLATION CONFIGURATION
# =============================================================================

variable "mode" {
  description = "Installation mode"
  type        = string
  default     = "auto"
  
  validation {
    condition     = contains(["auto", "manual"], var.mode)
    error_message = "Mode must be either 'auto' or 'manual'."
  }
}

variable "dry_run" {
  description = "Perform dry run without creating cluster"
  type        = bool
  default     = false
}

variable "watch" {
  description = "Watch cluster installation progress"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for installation"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

# =============================================================================
# ADDITIONAL CONFIGURATION
# =============================================================================

variable "properties" {
  description = "Additional cluster properties"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default = {
    Project     = "ROSA"
    Environment = "dev"
    ManagedBy   = "ROSA-CLI"
  }
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
  default     = ""
}

variable "marketplace_type" {
  description = "Marketplace type for ROSA"
  type        = string
  default     = "aws"
  
  validation {
    condition     = contains(["aws", "gcp"], var.marketplace_type)
    error_message = "Marketplace type must be either 'aws' or 'gcp'."
  }
}

# =============================================================================
# ENVIRONMENT-SPECIFIC OVERRIDES
# =============================================================================

variable "environment" {
  description = "Environment name (affects some defaults)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# =============================================================================
# OUTPUTS CONFIGURATION
# =============================================================================

variable "output_dir" {
  description = "Directory to store ROSA outputs"
  type        = string
  default     = "./rosa-outputs"
}

variable "save_cluster_info" {
  description = "Save cluster information to file"
  type        = bool
  default     = true
}

# =============================================================================
# LOCAL VALUES FOR ROSA CLI COMMAND CONSTRUCTION
# =============================================================================

locals {
  # Environment-specific defaults
  env_defaults = {
    dev = {
      compute_nodes = 2
      min_replicas  = 2
      max_replicas  = 5
      multi_az      = false
    }
    staging = {
      compute_nodes = 3
      min_replicas  = 3
      max_replicas  = 8
      multi_az      = true
    }
    prod = {
      compute_nodes = 6
      min_replicas  = 6
      max_replicas  = 20
      multi_az      = true
    }
  }
  
  # Apply environment-specific defaults
  final_compute_nodes = var.environment == "dev" ? local.env_defaults.dev.compute_nodes : 
                       var.environment == "staging" ? local.env_defaults.staging.compute_nodes : 
                       var.environment == "prod" ? local.env_defaults.prod.compute_nodes : 
                       var.compute_nodes
  
  final_min_replicas = var.environment == "dev" ? local.env_defaults.dev.min_replicas : 
                      var.environment == "staging" ? local.env_defaults.staging.min_replicas : 
                      var.environment == "prod" ? local.env_defaults.prod.min_replicas : 
                      var.min_replicas
  
  final_max_replicas = var.environment == "dev" ? local.env_defaults.dev.max_replicas : 
                      var.environment == "staging" ? local.env_defaults.staging.max_replicas : 
                      var.environment == "prod" ? local.env_defaults.prod.max_replicas : 
                      var.max_replicas
  
  final_multi_az = var.environment == "dev" ? local.env_defaults.dev.multi_az : 
                  var.environment == "staging" ? local.env_defaults.staging.multi_az : 
                  var.environment == "prod" ? local.env_defaults.prod.multi_az : 
                  var.multi_az
  
  # Construct ROSA CLI commands
  rosa_create_cluster_cmd = join(" ", compact([
    "rosa create cluster",
    "--cluster-name=${var.cluster_name}",
    "--region=${var.aws_region}",
    "--version=${var.openshift_version}",
    "--compute-machine-type=${var.compute_machine_type}",
    var.enable_autoscaling ? "--enable-autoscaling" : "--replicas=${local.final_compute_nodes}",
    var.enable_autoscaling ? "--min-replicas=${local.final_min_replicas}" : "",
    var.enable_autoscaling ? "--max-replicas=${local.final_max_replicas}" : "",
    local.final_multi_az ? "--multi-az" : "",
    var.enable_sts ? "--sts" : "",
    var.enable_fips ? "--fips" : "",
    var.enable_etcd_encryption ? "--etcd-encryption" : "",
    var.private ? "--private" : "",
    var.private_link ? "--private-link" : "",
    var.disable_user_workload_monitoring ? "--disable-user-workload-monitoring" : "",
    var.mode == "manual" ? "--mode=manual" : "--mode=auto",
    var.dry_run ? "--dry-run" : "",
    var.watch ? "--watch" : "",
    length(var.subnet_ids) > 0 ? "--subnet-ids=${join(",", var.subnet_ids)}" : "",
    length(var.availability_zones) > 0 ? "--availability-zones=${join(",", var.availability_zones)}" : "",
    var.host_prefix != 23 ? "--host-prefix=${var.host_prefix}" : "",
    var.machine_cidr != "10.0.0.0/16" ? "--machine-cidr=${var.machine_cidr}" : "",
    var.service_cidr != "172.30.0.0/16" ? "--service-cidr=${var.service_cidr}" : "",
    var.pod_cidr != "10.128.0.0/14" ? "--pod-cidr=${var.pod_cidr}" : "",
    var.role_arn != "" ? "--role-arn=${var.role_arn}" : "",
    var.support_role_arn != "" ? "--support-role-arn=${var.support_role_arn}" : "",
    var.operator_roles_prefix != "" ? "--operator-roles-prefix=${var.operator_roles_prefix}" : "",
    var.oidc_config_id != "" ? "--oidc-config-id=${var.oidc_config_id}" : "",
    var.kms_key_arn != "" ? "--kms-key-arn=${var.kms_key_arn}" : "",
    var.disable_scp_checks ? "--disable-scp-checks" : "",
    var.enable_external_oidc ? "--external-oidc" : "",
    var.enable_proxy ? "--http-proxy=${var.http_proxy}" : "",
    var.enable_proxy ? "--https-proxy=${var.https_proxy}" : "",
    var.enable_proxy && var.no_proxy != "" ? "--no-proxy=${var.no_proxy}" : "",
    var.additional_trust_bundle != "" ? "--additional-trust-bundle=${var.additional_trust_bundle}" : "",
    var.billing_account != "" ? "--billing-account=${var.billing_account}" : "",
    "--tags=${join(",", [for k, v in var.tags : "${k}=${v}"])}",
    "--yes"
  ]))
  
  rosa_create_admin_cmd = var.create_admin_user ? join(" ", compact([
    "rosa create admin",
    "--cluster=${var.cluster_name}",
    var.admin_username != "" ? "--username=${var.admin_username}" : "",
    var.admin_password != "" ? "--password=${var.admin_password}" : ""
  ])) : ""
  
  # Additional ROSA management commands
  rosa_create_account_roles_cmd = var.enable_sts ? join(" ", compact([
    "rosa create account-roles",
    "--mode=auto",
    "--yes"
  ])) : ""
  
  rosa_create_operator_roles_cmd = var.enable_sts ? join(" ", compact([
    "rosa create operator-roles",
    "--cluster=${var.cluster_name}",
    "--mode=auto",
    "--yes"
  ])) : ""
  
  rosa_create_oidc_provider_cmd = var.enable_sts ? join(" ", compact([
    "rosa create oidc-provider",
    "--cluster=${var.cluster_name}",
    "--mode=auto",
    "--yes"
  ])) : ""
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# VALIDATION LOCALS
# =============================================================================

locals {
  # Validate autoscaling configuration
  autoscaling_valid = !var.enable_autoscaling || (var.min_replicas <= var.max_replicas)
  
  # Validate networking configuration
  networking_valid = !var.private_link || var.private
  
  # Validate proxy configuration
  proxy_valid = !var.enable_proxy || (var.http_proxy != "" || var.https_proxy != "")
}

# Validation checks
resource "null_resource" "validate_config" {
  count = 1
  
  lifecycle {
    precondition {
      condition     = local.autoscaling_valid
      error_message = "min_replicas must be less than or equal to max_replicas when autoscaling is enabled."
    }
    
    precondition {
      condition     = local.networking_valid
      error_message = "private_link can only be enabled when private is true."
    }
    
    precondition {
      condition     = local.proxy_valid
      error_message = "http_proxy or https_proxy must be specified when enable_proxy is true."
    }
  }
}