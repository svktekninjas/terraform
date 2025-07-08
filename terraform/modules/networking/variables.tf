# Variables for Networking Module
# Receives inputs from master variables.tf

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (where ROSA nodes will be deployed)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Must specify at least 2 private subnet CIDRs for ROSA."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (for load balancers and NAT gateways)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "Must specify at least 2 public subnet CIDRs."
  }
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets (cost optimization for dev/test)"
  type        = bool
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Enable S3 VPC endpoint (recommended for ROSA)"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private VPC endpoints (required for private ROSA clusters)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all networking resources"
  type        = map(string)
  default     = {}
}