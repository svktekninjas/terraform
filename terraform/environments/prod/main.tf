# Production Environment Configuration for ROSA
# Integrates all modules to create a complete ROSA cluster with infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Configure backend for production
  backend "s3" {
    # bucket         = "your-terraform-state-bucket"
    # key            = "rosa/prod/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-state-locks"
  }
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Provider for backup region (if cross-region backup enabled)
provider "aws" {
  alias  = "backup_region"
  region = var.backup_region != "" ? var.backup_region : var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Environment-specific configuration
  environment = "prod"
  
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = local.environment
    ClusterName = var.cluster_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Region      = var.aws_region
  }
  
  # Production-specific overrides
  prod_config = {
    worker_node_count               = 6
    enable_autoscaling             = true
    min_replicas                   = 6
    max_replicas                   = 20
    multi_az                       = true
    enable_fips                    = true
    enable_etcd_encryption         = true
    enable_backup                  = true
    enable_cross_region_backup     = true
    cloudwatch_log_retention_days  = 90
    single_nat_gateway             = false
    create_kms_key                 = true
    enable_audit_logs              = true
  }
}

# =============================================================================
# VALIDATION MODULE
# =============================================================================

module "validation" {
  source = "../../modules/validation"
  
  # Cluster configuration
  cluster_name         = var.cluster_name
  openshift_version    = var.openshift_version
  compute_machine_type = var.compute_machine_type
  enable_autoscaling   = local.prod_config.enable_autoscaling
  min_replicas         = local.prod_config.min_replicas
  max_replicas         = local.prod_config.max_replicas
  
  # Networking configuration
  vpc_cidr      = var.machine_cidr
  subnet_ids    = var.subnet_ids
  private       = var.private
  private_link  = var.private_link
  enable_proxy  = var.enable_proxy
  http_proxy    = var.http_proxy
  https_proxy   = var.https_proxy
  
  # Validation settings
  enable_pre_validation   = true
  enable_post_validation  = true
  enable_quota_validation = true
  enable_rosa_validation  = true
  
  # Production requirements
  min_node_count = local.prod_config.worker_node_count
}

# =============================================================================
# NETWORKING MODULE
# =============================================================================

module "networking" {
  source = "../../modules/networking"
  
  # Only create VPC if no subnet IDs provided
  count = length(var.subnet_ids) == 0 ? 1 : 0
  
  cluster_name         = var.cluster_name
  vpc_cidr            = var.machine_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = local.prod_config.single_nat_gateway
  enable_s3_endpoint   = true
  enable_private_endpoints = var.private
  
  tags = local.common_tags
  
  depends_on = [module.validation]
}

# =============================================================================
# SECURITY MODULE
# =============================================================================

module "security" {
  source = "../../modules/security"
  
  cluster_name                    = var.cluster_name
  create_kms_key                 = local.prod_config.create_kms_key
  kms_deletion_window            = 30
  enable_key_rotation            = true
  vpc_id                         = length(module.networking) > 0 ? module.networking[0].vpc_id : ""
  create_additional_security_group = false
  additional_ingress_rules       = []
  
  tags = local.common_tags
  
  depends_on = [module.validation]
}

# =============================================================================
# STORAGE MODULE
# =============================================================================

module "storage" {
  source = "../../modules/storage"
  
  cluster_name                 = var.cluster_name
  create_image_registry_bucket = false  # Let ROSA create this
  create_backup_bucket         = false  # Use backup module instead
  force_destroy_bucket         = false
  enable_versioning           = true
  kms_key_id                  = module.security.kms_key_id
  enable_lifecycle_policy     = true
  lifecycle_retention_days    = 90
  transition_to_ia_days       = 30
  
  tags = local.common_tags
  
  depends_on = [module.security]
}

# =============================================================================
# COMPUTE MODULE (ROSA CLUSTER)
# =============================================================================

module "compute" {
  source = "../../modules/compute"
  
  # Cluster configuration
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  openshift_version = var.openshift_version
  multi_az          = local.prod_config.multi_az
  
  # Compute configuration
  compute_machine_type = var.compute_machine_type
  compute_nodes        = local.prod_config.worker_node_count
  enable_autoscaling   = local.prod_config.enable_autoscaling
  min_replicas         = local.prod_config.min_replicas
  max_replicas         = local.prod_config.max_replicas
  
  # Networking configuration
  subnet_ids         = length(var.subnet_ids) > 0 ? var.subnet_ids : (length(module.networking) > 0 ? module.networking[0].private_subnet_ids : [])
  availability_zones = var.availability_zones
  host_prefix        = var.host_prefix
  machine_cidr       = var.machine_cidr
  service_cidr       = var.service_cidr
  pod_cidr          = var.pod_cidr
  private           = var.private
  private_link      = var.private_link
  
  # Security configuration
  enable_sts                = var.enable_sts
  auto_create_roles        = true
  role_arn                 = var.role_arn
  support_role_arn         = var.support_role_arn
  operator_roles_prefix    = var.operator_roles_prefix
  oidc_config_id          = var.oidc_config_id
  enable_fips             = local.prod_config.enable_fips
  enable_etcd_encryption  = local.prod_config.enable_etcd_encryption
  kms_key_arn            = module.security.kms_key_arn
  disable_scp_checks     = var.disable_scp_checks
  
  # Cluster features
  disable_user_workload_monitoring = var.disable_user_workload_monitoring
  enable_proxy                    = var.enable_proxy
  http_proxy                      = var.http_proxy
  https_proxy                     = var.https_proxy
  no_proxy                        = var.no_proxy
  additional_trust_bundle         = var.additional_trust_bundle
  
  # Admin user configuration
  create_admin_user = var.create_admin_user
  admin_username    = var.admin_username
  admin_password    = var.admin_password
  
  # Installation configuration
  mode     = var.mode
  dry_run  = var.dry_run
  watch    = var.watch
  tags     = local.common_tags
  
  # Output configuration
  output_dir         = var.output_dir
  save_cluster_info  = var.save_cluster_info
  
  depends_on = [
    module.validation,
    module.networking,
    module.security,
    module.storage
  ]
}

# =============================================================================
# MONITORING MODULE
# =============================================================================

module "monitoring" {
  source = "../../modules/monitoring"
  
  cluster_name                   = var.cluster_name
  enable_cloudwatch_logging      = true
  log_retention_days             = local.prod_config.cloudwatch_log_retention_days
  enable_audit_logs              = local.prod_config.enable_audit_logs
  audit_log_retention_days       = 365
  enable_application_logs        = false
  application_log_retention_days = 30
  kms_key_id                     = module.security.kms_key_id
  enable_alerts                  = var.enable_alerts
  alert_email                    = var.alert_email
  alarm_evaluation_periods       = 2
  alarm_period                   = 300
  error_rate_threshold           = 10
  create_dashboard               = true
  enable_metric_stream           = false
  
  tags = local.common_tags
  
  depends_on = [module.compute]
}

# =============================================================================
# BACKUP MODULE
# =============================================================================

module "backup" {
  source = "../../modules/backup"
  
  providers = {
    aws.backup_region = aws.backup_region
  }
  
  cluster_name               = var.cluster_name
  enable_backup             = local.prod_config.enable_backup
  kms_key_arn              = module.security.kms_key_arn
  backup_schedule          = var.backup_schedule
  backup_start_window      = 60
  backup_completion_window = 480
  backup_retention_days    = var.backup_retention_days
  backup_cold_storage_after = 30
  
  # Weekly backup configuration
  enable_weekly_backup              = true
  weekly_backup_schedule           = "cron(0 3 ? * SUN *)"
  weekly_backup_retention_days     = 365
  weekly_backup_cold_storage_after = 90
  
  # Backup selection
  backup_resource_arns     = []
  backup_selection_tags    = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  
  # Cross-region backup
  enable_cross_region_backup     = local.prod_config.enable_cross_region_backup
  cross_region_kms_key_arn      = ""
  cross_region_backup_schedule  = "cron(0 4 ? * * *)"
  cross_region_retention_days   = 365
  cross_region_cold_storage_after = 90
  
  # ETCD backup
  enable_etcd_backup           = var.enable_etcd_backup
  etcd_backup_retention_days   = 30
  force_destroy_backup_bucket  = false
  
  tags = local.common_tags
  
  depends_on = [module.compute]
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================

module "post_validation" {
  source = "../../modules/validation"
  
  # Cluster configuration
  cluster_name         = var.cluster_name
  openshift_version    = var.openshift_version
  compute_machine_type = var.compute_machine_type
  enable_autoscaling   = local.prod_config.enable_autoscaling
  min_replicas         = local.prod_config.min_replicas
  max_replicas         = local.prod_config.max_replicas
  
  # Networking configuration
  vpc_cidr      = var.machine_cidr
  subnet_ids    = length(var.subnet_ids) > 0 ? var.subnet_ids : (length(module.networking) > 0 ? module.networking[0].private_subnet_ids : [])
  private       = var.private
  private_link  = var.private_link
  enable_proxy  = var.enable_proxy
  http_proxy    = var.http_proxy
  https_proxy   = var.https_proxy
  
  # Post-deployment validation only
  enable_pre_validation      = false
  enable_post_validation     = true
  enable_quota_validation    = false
  enable_rosa_validation     = false
  
  # Wait for cluster creation
  cluster_creation_dependency = module.compute
  cluster_ready_timeout       = 3600
  min_node_count             = local.prod_config.worker_node_count
  
  depends_on = [module.compute]
}