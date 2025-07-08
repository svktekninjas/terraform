# Security Module for ROSA CLI Integration
# Creates KMS key that can be passed to ROSA CLI via --kms-key-arn

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
      Module = "security"
      Purpose = "ROSA-Encryption"
    }
  )
}

# =============================================================================
# KMS KEY FOR ROSA CLUSTER ENCRYPTION
# =============================================================================

resource "aws_kms_key" "rosa_kms_key" {
  count = var.create_kms_key ? 1 : 0
  
  description             = "KMS key for ROSA cluster ${var.cluster_name} encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ROSA Service Access"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ebs.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-kms-key"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "rosa_kms_alias" {
  count = var.create_kms_key ? 1 : 0
  
  name          = "alias/${var.cluster_name}-rosa-key"
  target_key_id = aws_kms_key.rosa_kms_key[0].key_id
}

# =============================================================================
# ADDITIONAL SECURITY GROUPS (Optional)
# =============================================================================

# Additional security group for custom requirements
resource "aws_security_group" "rosa_additional_sg" {
  count = var.create_additional_security_group ? 1 : 0
  
  name_prefix = "${var.cluster_name}-additional-"
  vpc_id      = var.vpc_id
  description = "Additional security group for ROSA cluster ${var.cluster_name}"
  
  # Custom ingress rules
  dynamic "ingress" {
    for_each = var.additional_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }
  
  # Default egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-additional-sg"
  })
}