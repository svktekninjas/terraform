# Variables for Storage Module

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
}

variable "create_image_registry_bucket" {
  description = "Create S3 bucket for image registry (ROSA can auto-create this)"
  type        = bool
  default     = false
}

variable "create_backup_bucket" {
  description = "Create S3 bucket for backups"
  type        = bool
  default     = false
}

variable "force_destroy_bucket" {
  description = "Allow bucket to be destroyed even if not empty (use with caution)"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption (leave empty for AES256)"
  type        = string
  default     = ""
}

variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "lifecycle_retention_days" {
  description = "Number of days to retain old versions"
  type        = number
  default     = 90
  
  validation {
    condition     = var.lifecycle_retention_days >= 1 && var.lifecycle_retention_days <= 365
    error_message = "Lifecycle retention days must be between 1 and 365."
  }
}

variable "transition_to_ia_days" {
  description = "Days after which to transition objects to IA storage class (0 to disable)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.transition_to_ia_days >= 0
    error_message = "Transition to IA days must be >= 0."
  }
}

variable "tags" {
  description = "Tags to apply to all storage resources"
  type        = map(string)
  default     = {}
}