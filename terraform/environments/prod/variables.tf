# Production Environment Variables
# Inherits from master variables with production-specific defaults

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
  default     = "rosa-prod-cluster"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "rosa-production"
}

variable "owner" {
  description = "Resource owner"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

variable "aws_region" {
  description = "AWS region for ROSA deployment"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "backup_region" {
  description = "AWS region for cross-region backup"
  type        = string
  default     = "us-west-2"
}

# =============================================================================
# ROSA CONFIGURATION
# =============================================================================

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster"
  type        = string
  default     = "4.14"
}

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "m5.xlarge"
}

# =============================================================================
# NETWORKING CONFIGURATION
# =============================================================================

variable "subnet_ids" {
  description = "List of subnet IDs for ROSA cluster (leave empty to create new VPC)"
  type        = list(string)
  default     = []
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

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "host_prefix" {
  description = "Subnet prefix length for node IP assignment"
  type        = number
  default     = 23
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
  default     = "auto"
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

# =============================================================================
# MONITORING CONFIGURATION
# =============================================================================

variable "enable_alerts" {
  description = "Enable monitoring alerts"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

variable "backup_schedule" {
  description = "Backup schedule (cron format)"
  type        = string
  default     = "cron(0 2 * * * *)"
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 90
}

variable "enable_etcd_backup" {
  description = "Enable etcd backup"
  type        = bool
  default     = true
}

# =============================================================================
# OUTPUT CONFIGURATION
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