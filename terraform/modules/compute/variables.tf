# Variables for Compute Module (ROSA CLI Integration)

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region for ROSA deployment"
  type        = string
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster"
  type        = string
}

variable "multi_az" {
  description = "Deploy cluster across multiple availability zones"
  type        = bool
}

# =============================================================================
# COMPUTE CONFIGURATION
# =============================================================================

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
}

variable "compute_nodes" {
  description = "Number of worker nodes"
  type        = number
}

variable "enable_autoscaling" {
  description = "Enable autoscaling for worker nodes"
  type        = bool
}

variable "min_replicas" {
  description = "Minimum number of worker nodes for autoscaling"
  type        = number
}

variable "max_replicas" {
  description = "Maximum number of worker nodes for autoscaling"
  type        = number
}

# =============================================================================
# NETWORKING CONFIGURATION
# =============================================================================

variable "subnet_ids" {
  description = "List of subnet IDs for ROSA cluster"
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "host_prefix" {
  description = "Subnet prefix length for node IP assignment"
  type        = number
  default     = 23
}

variable "machine_cidr" {
  description = "CIDR block for machines"
  type        = string
  default     = ""
}

variable "service_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = ""
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = ""
}

variable "private" {
  description = "Create private cluster"
  type        = bool
}

variable "private_link" {
  description = "Use AWS PrivateLink for cluster connectivity"
  type        = bool
}

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

variable "enable_sts" {
  description = "Use AWS Security Token Service (STS)"
  type        = bool
}

variable "auto_create_roles" {
  description = "Automatically create IAM roles via ROSA CLI"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of the AWS IAM role for ROSA installer"
  type        = string
  default     = ""
}

variable "support_role_arn" {
  description = "ARN of the AWS IAM role for Red Hat support"
  type        = string
  default     = ""
}

variable "operator_roles_prefix" {
  description = "Prefix for operator IAM roles"
  type        = string
  default     = ""
}

variable "oidc_config_id" {
  description = "OpenID Connect configuration ID"
  type        = string
  default     = ""
}

variable "enable_fips" {
  description = "Enable FIPS mode for cluster"
  type        = bool
}

variable "enable_etcd_encryption" {
  description = "Enable additional etcd encryption"
  type        = bool
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = ""
}

variable "disable_scp_checks" {
  description = "Disable Service Control Policy checks"
  type        = bool
  default     = false
}

# =============================================================================
# CLUSTER FEATURES
# =============================================================================

variable "disable_user_workload_monitoring" {
  description = "Disable user workload monitoring"
  type        = bool
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
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = ""
}

variable "admin_password" {
  description = "Admin password"
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
}

variable "dry_run" {
  description = "Perform dry run without creating cluster"
  type        = bool
}

variable "watch" {
  description = "Watch cluster installation progress"
  type        = bool
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
}

# =============================================================================
# OUTPUT CONFIGURATION
# =============================================================================

variable "output_dir" {
  description = "Directory to store ROSA outputs"
  type        = string
}

variable "save_cluster_info" {
  description = "Save cluster information to file"
  type        = bool
}