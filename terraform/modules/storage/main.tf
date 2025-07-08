# Storage Module for ROSA CLI Integration
# Creates S3 bucket for image registry (ROSA CLI can automatically configure this)

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Generate unique bucket suffix
  bucket_suffix = substr(sha256("${var.cluster_name}-${data.aws_caller_identity.current.account_id}"), 0, 8)
  bucket_name = "${var.cluster_name}-registry-${local.bucket_suffix}"
  
  common_tags = merge(
    var.tags,
    {
      Module = "storage"
      Purpose = "ROSA-ImageRegistry"
    }
  )
}

# =============================================================================
# S3 BUCKET FOR IMAGE REGISTRY (Optional)
# =============================================================================

resource "aws_s3_bucket" "rosa_image_registry" {
  count = var.create_image_registry_bucket ? 1 : 0
  
  bucket        = local.bucket_name
  force_destroy = var.force_destroy_bucket
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-image-registry"
    Type = "ImageRegistry"
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "rosa_registry_versioning" {
  count = var.create_image_registry_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_image_registry[0].id
  
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "rosa_registry_encryption" {
  count = var.create_image_registry_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_image_registry[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }
    bucket_key_enabled = var.kms_key_id != "" ? true : false
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "rosa_registry_pab" {
  count = var.create_image_registry_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_image_registry[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "rosa_registry_lifecycle" {
  count = var.create_image_registry_bucket && var.enable_lifecycle_policy ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_image_registry[0].id
  
  rule {
    id     = "image_cleanup"
    status = "Enabled"
    
    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    
    # Transition old versions to IA after 30 days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
    
    # Delete old versions after lifecycle retention period
    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_retention_days
    }
    
    # Optional: Transition current objects to IA after specified days
    dynamic "transition" {
      for_each = var.transition_to_ia_days > 0 ? [1] : []
      content {
        days          = var.transition_to_ia_days
        storage_class = "STANDARD_IA"
      }
    }
  }
}

# =============================================================================
# S3 BUCKET FOR BACKUPS (Optional)
# =============================================================================

resource "aws_s3_bucket" "rosa_backup_bucket" {
  count = var.create_backup_bucket ? 1 : 0
  
  bucket        = "${var.cluster_name}-backups-${local.bucket_suffix}"
  force_destroy = var.force_destroy_bucket
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-backups"
    Type = "Backup"
  })
}

# Backup Bucket Versioning
resource "aws_s3_bucket_versioning" "rosa_backup_versioning" {
  count = var.create_backup_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_backup_bucket[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Backup Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "rosa_backup_encryption" {
  count = var.create_backup_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_backup_bucket[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
    }
    bucket_key_enabled = var.kms_key_id != "" ? true : false
  }
}

# Backup Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "rosa_backup_pab" {
  count = var.create_backup_bucket ? 1 : 0
  
  bucket = aws_s3_bucket.rosa_backup_bucket[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}