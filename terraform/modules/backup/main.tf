# Backup Module for ROSA CLI Integration
# Creates AWS Backup resources for ROSA cluster data protection

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Module = "backup"
      Purpose = "ROSA-DataProtection"
    }
  )
}

# =============================================================================
# AWS BACKUP VAULT
# =============================================================================

resource "aws_backup_vault" "rosa_backup_vault" {
  count = var.enable_backup ? 1 : 0
  
  name        = "${var.cluster_name}-backup-vault"
  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-backup-vault"
  })
}

# =============================================================================
# AWS BACKUP PLAN
# =============================================================================

resource "aws_backup_plan" "rosa_backup_plan" {
  count = var.enable_backup ? 1 : 0
  
  name = "${var.cluster_name}-backup-plan"
  
  # Daily backup rule
  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.rosa_backup_vault[0].name
    schedule          = var.backup_schedule
    
    start_window      = var.backup_start_window
    completion_window = var.backup_completion_window
    
    lifecycle {
      cold_storage_after = var.backup_cold_storage_after
      delete_after       = var.backup_retention_days
    }
    
    recovery_point_tags = merge(local.common_tags, {
      BackupType = "Daily"
    })
  }
  
  # Weekly backup rule (if enabled)
  dynamic "rule" {
    for_each = var.enable_weekly_backup ? [1] : []
    content {
      rule_name         = "weekly_backup"
      target_vault_name = aws_backup_vault.rosa_backup_vault[0].name
      schedule          = var.weekly_backup_schedule
      
      start_window      = var.backup_start_window
      completion_window = var.backup_completion_window
      
      lifecycle {
        cold_storage_after = var.weekly_backup_cold_storage_after
        delete_after       = var.weekly_backup_retention_days
      }
      
      recovery_point_tags = merge(local.common_tags, {
        BackupType = "Weekly"
      })
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-backup-plan"
  })
}

# =============================================================================
# IAM ROLE FOR AWS BACKUP
# =============================================================================

resource "aws_iam_role" "backup_role" {
  count = var.enable_backup ? 1 : 0
  
  name = "${var.cluster_name}-backup-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-backup-role"
  })
}

# Attach AWS managed policy for backup service
resource "aws_iam_role_policy_attachment" "backup_policy" {
  count = var.enable_backup ? 1 : 0
  
  role       = aws_iam_role.backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Attach policy for restoring resources
resource "aws_iam_role_policy_attachment" "restore_policy" {
  count = var.enable_backup ? 1 : 0
  
  role       = aws_iam_role.backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# =============================================================================
# BACKUP SELECTION
# =============================================================================

resource "aws_backup_selection" "rosa_backup_selection" {
  count = var.enable_backup ? 1 : 0
  
  iam_role_arn = aws_iam_role.backup_role[0].arn
  name         = "${var.cluster_name}-backup-selection"
  plan_id      = aws_backup_plan.rosa_backup_plan[0].id
  
  # Resources to backup based on tags
  resources = var.backup_resource_arns
  
  # Backup selection by tags
  dynamic "condition" {
    for_each = length(var.backup_selection_tags) > 0 ? [1] : []
    content {
      dynamic "string_equals" {
        for_each = var.backup_selection_tags
        content {
          key   = string_equals.key
          value = string_equals.value
        }
      }
    }
  }
}

# =============================================================================
# CROSS-REGION BACKUP VAULT (Optional)
# =============================================================================

resource "aws_backup_vault" "rosa_cross_region_vault" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup_region
  
  name        = "${var.cluster_name}-backup-vault-dr"
  kms_key_arn = var.cross_region_kms_key_arn != "" ? var.cross_region_kms_key_arn : null
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-backup-vault-dr"
    Type = "CrossRegion"
  })
}

# =============================================================================
# BACKUP COPY CONFIGURATION
# =============================================================================

resource "aws_backup_plan" "rosa_cross_region_plan" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup_region
  
  name = "${var.cluster_name}-cross-region-backup-plan"
  
  rule {
    rule_name         = "cross_region_backup"
    target_vault_name = aws_backup_vault.rosa_cross_region_vault[0].name
    schedule          = var.cross_region_backup_schedule
    
    start_window      = var.backup_start_window
    completion_window = var.backup_completion_window
    
    # Copy from primary region
    copy_action {
      destination_vault_arn = aws_backup_vault.rosa_backup_vault[0].arn
      
      lifecycle {
        cold_storage_after = var.backup_cold_storage_after
        delete_after       = var.backup_retention_days
      }
    }
    
    lifecycle {
      cold_storage_after = var.cross_region_cold_storage_after
      delete_after       = var.cross_region_retention_days
    }
    
    recovery_point_tags = merge(local.common_tags, {
      BackupType = "CrossRegion"
    })
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cross-region-backup-plan"
  })
}

# =============================================================================
# ETCD BACKUP CONFIGURATION (S3 Based)
# =============================================================================

resource "aws_s3_bucket" "etcd_backup_bucket" {
  count = var.enable_etcd_backup ? 1 : 0
  
  bucket        = "${var.cluster_name}-etcd-backups-${substr(sha256("${var.cluster_name}-${data.aws_caller_identity.current.account_id}"), 0, 8)}"
  force_destroy = var.force_destroy_backup_bucket
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-etcd-backups"
    Type = "ETCDBackup"
  })
}

# ETCD Backup bucket versioning
resource "aws_s3_bucket_versioning" "etcd_backup_versioning" {
  count = var.enable_etcd_backup ? 1 : 0
  
  bucket = aws_s3_bucket.etcd_backup_bucket[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# ETCD Backup bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "etcd_backup_encryption" {
  count = var.enable_etcd_backup ? 1 : 0
  
  bucket = aws_s3_bucket.etcd_backup_bucket[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

# ETCD Backup lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "etcd_backup_lifecycle" {
  count = var.enable_etcd_backup ? 1 : 0
  
  bucket = aws_s3_bucket.etcd_backup_bucket[0].id
  
  rule {
    id     = "etcd_backup_lifecycle"
    status = "Enabled"
    
    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    # Delete after retention period
    expiration {
      days = var.etcd_backup_retention_days
    }
    
    # Delete old versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}