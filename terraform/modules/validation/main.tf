# Validation Module for ROSA CLI Integration
# Validates prerequisites and performs post-deployment checks

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Validation results
  validation_results = {
    region_valid                = contains(var.supported_regions, data.aws_region.current.name)
    az_count_sufficient         = length(data.aws_availability_zones.available.names) >= 3
    vpc_cidr_valid             = var.vpc_cidr != "" ? can(cidrhost(var.vpc_cidr, 0)) : true
    subnet_count_sufficient    = length(var.subnet_ids) >= 2 || length(var.subnet_ids) == 0
    cluster_name_valid         = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 54
    openshift_version_valid    = can(regex("^4\\.[0-9]+$", var.openshift_version))
    instance_type_valid        = contains(var.supported_instance_types, var.compute_machine_type)
    autoscaling_config_valid   = !var.enable_autoscaling || (var.min_replicas <= var.max_replicas)
    networking_config_valid    = !var.private_link || var.private
    proxy_config_valid         = !var.enable_proxy || (var.http_proxy != "" || var.https_proxy != "")
  }
  
  # Overall validation status
  all_validations_passed = alltrue(values(local.validation_results))
  
  # Failed validations
  failed_validations = [
    for key, value in local.validation_results : key if !value
  ]
}

# =============================================================================
# PRE-DEPLOYMENT VALIDATION
# =============================================================================

# Check AWS region support
resource "null_resource" "validate_region" {
  count = var.enable_pre_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.region_valid
      error_message = "Region ${data.aws_region.current.name} is not supported for ROSA. Supported regions: ${join(", ", var.supported_regions)}"
    }
  }
  
  triggers = {
    region = data.aws_region.current.name
  }
}

# Check availability zones
resource "null_resource" "validate_availability_zones" {
  count = var.enable_pre_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.az_count_sufficient
      error_message = "Region must have at least 3 availability zones. Current region has ${length(data.aws_availability_zones.available.names)} AZs."
    }
  }
  
  triggers = {
    az_count = length(data.aws_availability_zones.available.names)
  }
}

# Check cluster configuration
resource "null_resource" "validate_cluster_config" {
  count = var.enable_pre_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.cluster_name_valid
      error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
    }
    
    precondition {
      condition     = local.validation_results.openshift_version_valid
      error_message = "OpenShift version must be in format 4.x (e.g., 4.14)."
    }
    
    precondition {
      condition     = local.validation_results.instance_type_valid
      error_message = "Compute machine type ${var.compute_machine_type} is not supported. Supported types: ${join(", ", var.supported_instance_types)}"
    }
  }
  
  triggers = {
    cluster_name         = var.cluster_name
    openshift_version    = var.openshift_version
    compute_machine_type = var.compute_machine_type
  }
}

# Check networking configuration
resource "null_resource" "validate_networking" {
  count = var.enable_pre_validation ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.vpc_cidr_valid
      error_message = "VPC CIDR must be a valid CIDR block."
    }
    
    precondition {
      condition     = local.validation_results.subnet_count_sufficient
      error_message = "Must provide at least 2 subnet IDs for ROSA cluster."
    }
    
    precondition {
      condition     = local.validation_results.networking_config_valid
      error_message = "PrivateLink can only be enabled when private is true."
    }
  }
  
  triggers = {
    vpc_cidr      = var.vpc_cidr
    subnet_count  = length(var.subnet_ids)
    private       = var.private
    private_link  = var.private_link
  }
}

# Check autoscaling configuration
resource "null_resource" "validate_autoscaling" {
  count = var.enable_pre_validation && var.enable_autoscaling ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.autoscaling_config_valid
      error_message = "min_replicas (${var.min_replicas}) must be less than or equal to max_replicas (${var.max_replicas})."
    }
  }
  
  triggers = {
    enable_autoscaling = var.enable_autoscaling
    min_replicas       = var.min_replicas
    max_replicas       = var.max_replicas
  }
}

# Check proxy configuration
resource "null_resource" "validate_proxy" {
  count = var.enable_pre_validation && var.enable_proxy ? 1 : 0
  
  lifecycle {
    precondition {
      condition     = local.validation_results.proxy_config_valid
      error_message = "http_proxy or https_proxy must be specified when enable_proxy is true."
    }
  }
  
  triggers = {
    enable_proxy  = var.enable_proxy
    http_proxy    = var.http_proxy
    https_proxy   = var.https_proxy
  }
}

# =============================================================================
# AWS QUOTA VALIDATION
# =============================================================================

# Validate AWS service quotas (if enabled)
resource "null_resource" "validate_quotas" {
  count = var.enable_quota_validation ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking AWS service quotas..."
      
      # Check EC2 vCPU limits
      VCPU_LIMIT=$(aws service-quotas get-service-quota \
        --service-code ec2 \
        --quota-code L-34B43A08 \
        --region ${data.aws_region.current.name} \
        --query 'Quota.Value' \
        --output text 2>/dev/null || echo "0")
      
      if [ "$VCPU_LIMIT" -lt "${var.min_vcpu_quota}" ]; then
        echo "ERROR: EC2 vCPU limit ($VCPU_LIMIT) is below required minimum (${var.min_vcpu_quota})"
        exit 1
      fi
      
      echo "AWS quotas validation passed"
    EOT
  }
  
  triggers = {
    region         = data.aws_region.current.name
    min_vcpu_quota = var.min_vcpu_quota
  }
}

# =============================================================================
# ROSA CLI VALIDATION
# =============================================================================

# Validate ROSA CLI prerequisites
resource "null_resource" "validate_rosa_cli" {
  count = var.enable_rosa_validation ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating ROSA CLI prerequisites..."
      
      # Check if ROSA CLI is installed
      if ! command -v rosa &> /dev/null; then
        echo "ERROR: ROSA CLI is not installed"
        exit 1
      fi
      
      # Check ROSA CLI version
      ROSA_VERSION=$(rosa version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
      echo "ROSA CLI version: $ROSA_VERSION"
      
      # Verify ROSA quota
      if [ "${var.verify_rosa_quota}" = "true" ]; then
        echo "Verifying ROSA quota..."
        rosa verify quota --region=${data.aws_region.current.name} || {
          echo "ERROR: ROSA quota verification failed"
          exit 1
        }
      fi
      
      # Verify AWS permissions
      if [ "${var.verify_aws_permissions}" = "true" ]; then
        echo "Verifying AWS permissions..."
        rosa verify permissions || {
          echo "ERROR: AWS permissions verification failed"
          exit 1
        }
      fi
      
      echo "ROSA CLI validation passed"
    EOT
  }
  
  triggers = {
    region                   = data.aws_region.current.name
    verify_rosa_quota        = var.verify_rosa_quota
    verify_aws_permissions   = var.verify_aws_permissions
  }
}

# =============================================================================
# POST-DEPLOYMENT VALIDATION
# =============================================================================

# Wait for cluster to be ready (if enabled)
resource "null_resource" "wait_for_cluster" {
  count = var.enable_post_validation ? 1 : 0
  
  depends_on = [var.cluster_creation_dependency]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster ${var.cluster_name} to be ready..."
      
      TIMEOUT=${var.cluster_ready_timeout}
      ELAPSED=0
      
      while [ $ELAPSED -lt $TIMEOUT ]; do
        STATUS=$(rosa describe cluster --cluster=${var.cluster_name} --output=json 2>/dev/null | jq -r '.state // "unknown"')
        
        case "$STATUS" in
          "ready")
            echo "Cluster is ready!"
            exit 0
            ;;
          "error"|"failed")
            echo "ERROR: Cluster creation failed with status: $STATUS"
            exit 1
            ;;
          "installing"|"pending"|"validating")
            echo "Cluster status: $STATUS (waiting...)"
            sleep 60
            ELAPSED=$((ELAPSED + 60))
            ;;
          *)
            echo "Unknown cluster status: $STATUS"
            sleep 30
            ELAPSED=$((ELAPSED + 30))
            ;;
        esac
      done
      
      echo "ERROR: Timeout waiting for cluster to be ready"
      exit 1
    EOT
  }
  
  triggers = {
    cluster_name = var.cluster_name
    timestamp    = timestamp()
  }
}

# Validate cluster components
resource "null_resource" "validate_cluster_components" {
  count = var.enable_post_validation ? 1 : 0
  
  depends_on = [null_resource.wait_for_cluster]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating cluster components..."
      
      # Get cluster info
      CLUSTER_INFO=$(rosa describe cluster --cluster=${var.cluster_name} --output=json)
      
      # Check API URL is accessible
      API_URL=$(echo "$CLUSTER_INFO" | jq -r '.api.url // ""')
      if [ -n "$API_URL" ]; then
        echo "API URL: $API_URL"
        # Basic connectivity test (don't require authentication)
        curl -sSf --connect-timeout 10 "$API_URL/healthz" > /dev/null || {
          echo "WARNING: API endpoint not accessible (may be expected for private clusters)"
        }
      fi
      
      # Check console URL
      CONSOLE_URL=$(echo "$CLUSTER_INFO" | jq -r '.console.url // ""')
      if [ -n "$CONSOLE_URL" ]; then
        echo "Console URL: $CONSOLE_URL"
      fi
      
      # Check cluster version
      CLUSTER_VERSION=$(echo "$CLUSTER_INFO" | jq -r '.openshift_version // ""')
      echo "Cluster version: $CLUSTER_VERSION"
      
      # Check node count
      NODE_COUNT=$(echo "$CLUSTER_INFO" | jq -r '.nodes.compute // 0')
      echo "Compute nodes: $NODE_COUNT"
      
      if [ "$NODE_COUNT" -lt "${var.min_node_count}" ]; then
        echo "ERROR: Node count ($NODE_COUNT) is below minimum required (${var.min_node_count})"
        exit 1
      fi
      
      echo "Cluster validation completed successfully"
    EOT
  }
  
  triggers = {
    cluster_name    = var.cluster_name
    min_node_count  = var.min_node_count
  }
}