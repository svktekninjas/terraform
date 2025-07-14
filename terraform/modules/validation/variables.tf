# Variables for Validation Module

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "openshift_version" {
  description = "OpenShift version for ROSA cluster"
  type        = string
}

variable "compute_machine_type" {
  description = "Instance type for worker nodes"
  type        = string
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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs for ROSA cluster"
  type        = list(string)
  default     = []
}

variable "private" {
  description = "Create private cluster"
  type        = bool
}

variable "private_link" {
  description = "Use AWS PrivateLink for cluster connectivity"
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

# =============================================================================
# VALIDATION CONFIGURATION
# =============================================================================

variable "enable_pre_validation" {
  description = "Enable pre-deployment validation (region, quotas, ROSA CLI, basic config)"
  type        = bool
  default     = true
}

variable "enable_infra_validation" {
  description = "Enable infrastructure validation (VPC, subnets, networking after creation)"
  type        = bool
  default     = true
}

variable "enable_post_validation" {
  description = "Enable post-deployment validation (cluster readiness, components)"
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

# =============================================================================
# SUPPORTED VALUES
# =============================================================================

variable "supported_regions" {
  description = "List of AWS regions supported by ROSA"
  type        = list(string)
  default = [
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "ca-central-1", "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3",
    "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
    "ap-south-1", "sa-east-1"
  ]
}

variable "supported_instance_types" {
  description = "List of EC2 instance types supported by ROSA"
  type        = list(string)
  default = [
    "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge", "m5.8xlarge", "m5.12xlarge", "m5.16xlarge", "m5.24xlarge",
    "m5a.large", "m5a.xlarge", "m5a.2xlarge", "m5a.4xlarge", "m5a.8xlarge", "m5a.12xlarge", "m5a.16xlarge", "m5a.24xlarge",
    "m5ad.large", "m5ad.xlarge", "m5ad.2xlarge", "m5ad.4xlarge", "m5ad.8xlarge", "m5ad.12xlarge", "m5ad.16xlarge", "m5ad.24xlarge",
    "m5d.large", "m5d.xlarge", "m5d.2xlarge", "m5d.4xlarge", "m5d.8xlarge", "m5d.12xlarge", "m5d.16xlarge", "m5d.24xlarge",
    "m5dn.large", "m5dn.xlarge", "m5dn.2xlarge", "m5dn.4xlarge", "m5dn.8xlarge", "m5dn.12xlarge", "m5dn.16xlarge", "m5dn.24xlarge",
    "m5n.large", "m5n.xlarge", "m5n.2xlarge", "m5n.4xlarge", "m5n.8xlarge", "m5n.12xlarge", "m5n.16xlarge", "m5n.24xlarge",
    "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge", "c5.9xlarge", "c5.12xlarge", "c5.18xlarge", "c5.24xlarge",
    "c5a.large", "c5a.xlarge", "c5a.2xlarge", "c5a.4xlarge", "c5a.8xlarge", "c5a.12xlarge", "c5a.16xlarge", "c5a.24xlarge",
    "c5ad.large", "c5ad.xlarge", "c5ad.2xlarge", "c5ad.4xlarge", "c5ad.8xlarge", "c5ad.12xlarge", "c5ad.16xlarge", "c5ad.24xlarge",
    "c5d.large", "c5d.xlarge", "c5d.2xlarge", "c5d.4xlarge", "c5d.9xlarge", "c5d.12xlarge", "c5d.18xlarge", "c5d.24xlarge",
    "c5n.large", "c5n.xlarge", "c5n.2xlarge", "c5n.4xlarge", "c5n.9xlarge", "c5n.18xlarge",
    "r5.large", "r5.xlarge", "r5.2xlarge", "r5.4xlarge", "r5.8xlarge", "r5.12xlarge", "r5.16xlarge", "r5.24xlarge",
    "r5a.large", "r5a.xlarge", "r5a.2xlarge", "r5a.4xlarge", "r5a.8xlarge", "r5a.12xlarge", "r5a.16xlarge", "r5a.24xlarge",
    "r5ad.large", "r5ad.xlarge", "r5ad.2xlarge", "r5ad.4xlarge", "r5ad.8xlarge", "r5ad.12xlarge", "r5ad.16xlarge", "r5ad.24xlarge",
    "r5d.large", "r5d.xlarge", "r5d.2xlarge", "r5d.4xlarge", "r5d.8xlarge", "r5d.12xlarge", "r5d.16xlarge", "r5d.24xlarge",
    "r5dn.large", "r5dn.xlarge", "r5dn.2xlarge", "r5dn.4xlarge", "r5dn.8xlarge", "r5dn.12xlarge", "r5dn.16xlarge", "r5dn.24xlarge",
    "r5n.large", "r5n.xlarge", "r5n.2xlarge", "r5n.4xlarge", "r5n.8xlarge", "r5n.12xlarge", "r5n.16xlarge", "r5n.24xlarge"
  ]
}

# =============================================================================
# QUOTA VALIDATION
# =============================================================================

variable "min_vcpu_quota" {
  description = "Minimum required EC2 vCPU quota"
  type        = number
  default     = 100
}

# =============================================================================
# ROSA CLI VALIDATION
# =============================================================================

variable "verify_rosa_quota" {
  description = "Verify ROSA quota using rosa CLI"
  type        = bool
  default     = true
}

variable "verify_aws_permissions" {
  description = "Verify AWS permissions using rosa CLI"
  type        = bool
  default     = true
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================

variable "cluster_creation_dependency" {
  description = "Resource to depend on for cluster creation (e.g., null_resource.rosa_cluster)"
  type        = any
  default     = null
}

variable "cluster_ready_timeout" {
  description = "Timeout in seconds to wait for cluster to be ready"
  type        = number
  default     = 3600
}

variable "min_node_count" {
  description = "Minimum expected number of worker nodes"
  type        = number
  default     = 2
}