# Variables for Security Module

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "create_kms_key" {
  description = "Create a KMS key for ROSA cluster encryption"
  type        = bool
  default     = true
}

variable "kms_deletion_window" {
  description = "Number of days before KMS key deletion (7-30)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for security groups (optional)"
  type        = string
  default     = ""
}

variable "create_additional_security_group" {
  description = "Create additional security group for custom requirements"
  type        = bool
  default     = false
}

variable "additional_ingress_rules" {
  description = "Additional ingress rules for security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all security resources"
  type        = map(string)
  default     = {}
}