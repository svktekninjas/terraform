# Step-by-Step Guide: ROSA Pre-Validation Module

This guide walks you through creating and executing the ROSA pre-validation module with environment-specific customizations.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Module Creation](#module-creation)
3. [Environment Setup](#environment-setup)
4. [Execution Guide](#execution-guide)
5. [Validation Results](#validation-results)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

```bash
# Required tools
- Terraform >= 1.0
- AWS CLI >= 2.0
- ROSA CLI (latest)
- jq (for JSON parsing)
- bash/zsh shell
```

### AWS Prerequisites

```bash
# 1. AWS Account with appropriate permissions
# 2. AWS CLI configured
aws configure list

# 3. Verify AWS identity
aws sts get-caller-identity
```

### ROSA Prerequisites

```bash
# 1. Install ROSA CLI
curl -L https://github.com/openshift/rosa/releases/latest/download/rosa-linux.tar.gz | tar -xz
sudo mv rosa /usr/local/bin/

# 2. Verify installation
rosa version
```

## Module Creation

### Step 1: Create Module Structure

```bash
# Navigate to your terraform directory
cd terraform/

# Create pre-validation module directory
mkdir -p modules/pre-validation

# Create module files
touch modules/pre-validation/main.tf
touch modules/pre-validation/variables.tf
touch modules/pre-validation/outputs.tf
```

### Step 2: Define Module Variables

Create `modules/pre-validation/variables.tf`:

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the ROSA cluster"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 54
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens, and be <= 54 characters."
  }
}

# ... (additional variables as shown in the module)
```

### Step 3: Implement Validation Logic

Create `modules/pre-validation/main.tf`:

```hcl
# Data sources for AWS information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Environment-specific configuration
locals {
  env_config = {
    dev = {
      min_vcpu_quota           = 25
      required_az_count        = 2
      enable_strict_validation = false
    }
    staging = {
      min_vcpu_quota           = 100
      required_az_count        = 3
      enable_strict_validation = true
    }
    prod = {
      min_vcpu_quota           = 200
      required_az_count        = 3
      enable_strict_validation = true
    }
  }
}

# Validation resources
resource "null_resource" "pre_validate_region" {
  # ... (validation logic as shown in module)
}
```

### Step 4: Define Outputs

Create `modules/pre-validation/outputs.tf`:

```hcl
output "pre_validation_results" {
  description = "Results of all pre-deployment validation checks"
  value       = local.pre_validation_results
}

output "validation_status" {
  description = "Overall validation status"
  value       = local.all_pre_validations_passed ? "PASSED" : "FAILED"
}

# ... (additional outputs as shown in module)
```

## Environment Setup

### Step 1: Create Environment Directory

```bash
# Create dev environment
mkdir -p environments/dev

# Create environment files
touch environments/dev/main.tf
touch environments/dev/export_env.sh
```

### Step 2: Configure Environment Variables

Create `environments/dev/export_env.sh`:

```bash
#!/bin/bash
# Development Environment Export Script

# AWS Configuration
export AWS_PROFILE="your-profile"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"

# Environment Configuration
export ENVIRONMENT="dev"
export TERRAFORM_WORKSPACE="dev"

# Terraform Variables
export TF_VAR_environment="dev"
export TF_VAR_cluster_name="rosa-cluster"
export TF_VAR_openshift_version="4.14"
export TF_VAR_compute_machine_type="m5.large"

# Dev-specific settings
export TF_VAR_min_replicas="2"
export TF_VAR_max_replicas="5"
export TF_VAR_verify_rosa_quota="false"

echo "Dev environment variables set"
```

### Step 3: Create Environment Main Configuration

Create `environments/dev/main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use pre-validation module
module "pre_validation" {
  source = "../../modules/pre-validation"
  
  # Core configuration
  environment           = "dev"
  cluster_name         = var.cluster_name
  openshift_version    = var.openshift_version
  compute_machine_type = var.compute_machine_type
  
  # Autoscaling
  enable_autoscaling = var.enable_autoscaling
  min_replicas      = var.min_replicas
  max_replicas      = var.max_replicas
  
  # Validation control
  enable_validation       = true
  enable_quota_validation = true
  enable_rosa_validation  = true
  verify_rosa_quota      = false  # Relaxed for dev
}

# Variables
variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "rosa-cluster"
}

# ... (additional variables)
```

## Execution Guide

### Step 1: Prepare Environment

```bash
# Navigate to dev environment
cd environments/dev

# Make export script executable
chmod +x export_env.sh

# Source environment variables
source export_env.sh
```

Expected output:
```
==================================================
ROSA Development Environment Variables Set
==================================================
Environment: dev
AWS Region: us-east-1
AWS Profile: your-profile
Terraform workspace: dev
Cluster name: rosa-cluster-dev
Instance type: m5.large
==================================================
```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 3: Plan Pre-Validation

```bash
# Plan validation (dry run)
terraform plan -target=module.pre_validation
```

Expected output:
```
Terraform will perform the following actions:

  # module.pre_validation.null_resource.pre_validate_region[0] will be created
  + resource "null_resource" "pre_validate_region" {
      + id       = (known after apply)
      + triggers = {
          + "environment" = "dev"
          + "region"      = "us-east-1"
        }
    }

  # module.pre_validation.null_resource.pre_validate_availability_zones[0] will be created
  ...

Plan: 6 to add, 0 to change, 0 to destroy.
```

### Step 4: Apply Pre-Validation

```bash
# Apply validation
terraform apply -target=module.pre_validation
```

Monitor the output for validation progress:

```
module.pre_validation.null_resource.pre_validate_region[0]: Creating...
module.pre_validation.null_resource.pre_validate_region[0]: Creation complete

module.pre_validation.null_resource.pre_validate_quotas[0]: Creating...
module.pre_validation.null_resource.pre_validate_quotas[0]: Provisioning with 'local-exec'...
=== AWS Service Quota Validation for dev Environment ===
Checking EC2 vCPU quota in region: us-east-1
Current vCPU limit: 100
Required minimum for dev: 25
✅ AWS quota validation passed for dev

module.pre_validation.null_resource.pre_validate_rosa_cli[0]: Creating...
=== ROSA CLI Prerequisites Validation for dev Environment ===
ROSA CLI version: 1.2.25
AWS CLI version: aws-cli/2.15.0
AWS Account: 123456789012
✅ ROSA CLI validation passed for dev

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### Step 5: Review Validation Results

```bash
# Check overall validation status
terraform output validation_status
```

Output:
```
{
  "environment" = "dev"
  "overall_status" = "PASSED"
  "validation_enabled" = true
}
```

```bash
# View detailed validation results
terraform output pre_validation_results
```

Output:
```
{
  "autoscaling_config_valid" = true
  "az_count_sufficient" = true
  "cluster_name_valid" = true
  "environment_valid" = true
  "instance_type_valid" = true
  "openshift_version_valid" = true
  "region_valid" = true
}
```

```bash
# Get next steps
terraform output next_steps
```

Output:
```
[
  "✅ Pre-validation completed successfully",
  "▶️  Next: Create infrastructure with 'terraform apply -target=module.networking'",
  "▶️  Then: Run infra-validation phase",
  "📖 See documentation: docs/terraform/modules/pre-validation/"
]
```

## Validation Results

### Success Scenario

When all validations pass:

```bash
# Environment information
terraform output environment_info
```

```json
{
  "availability_zones": [
    "us-east-1a",
    "us-east-1b", 
    "us-east-1c"
  ],
  "az_count": 3,
  "environment": "dev",
  "region": "us-east-1",
  "required_az_count": 2
}
```

```bash
# AWS account information
terraform output aws_info
```

```json
{
  "account_id": "123456789012",
  "arn": "arn:aws:iam::123456789012:user/terraform-user",
  "region": "us-east-1",
  "user_id": "AIDAEXAMPLE"
}
```

### Failure Scenario

When validation fails:

```
Error: Region us-west-3 is not supported for ROSA

  with module.pre_validation.null_resource.pre_validate_region[0],
  on ../../modules/pre-validation/main.tf line 47, in resource "null_resource" "pre_validate_region":
  47:     condition     = local.pre_validation_results.region_valid
```

Check failed validations:
```bash
terraform output failed_validations
```

Output:
```
["region_valid"]
```

## Troubleshooting

### Common Issues and Solutions

#### 1. AWS Configuration Issues

**Problem**: AWS credentials not configured
```
Error: failed to configure AWS Provider: no valid credential sources for AWS Provider found
```

**Solution**:
```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Or use AWS profile
export AWS_PROFILE="your-profile"
```

#### 2. ROSA CLI Issues

**Problem**: ROSA CLI not found
```
Error: ROSA CLI is not installed
```

**Solution**:
```bash
# Install ROSA CLI
curl -L https://github.com/openshift/rosa/releases/latest/download/rosa-linux.tar.gz | tar -xz
sudo mv rosa /usr/local/bin/
rosa version
```

#### 3. Region Issues

**Problem**: Unsupported region
```
Error: Region us-west-3 is not supported for ROSA
```

**Solution**:
```bash
# Use supported region
export TF_VAR_aws_region="us-east-1"  # or us-west-2, eu-west-1, etc.
```

#### 4. Availability Zone Issues

**Problem**: Insufficient AZs
```
Error: Region must have at least 3 availability zones for prod environment
```

**Solution**:
```bash
# For dev environment (requires only 2 AZs)
export TF_VAR_environment="dev"

# Or choose region with more AZs
export TF_VAR_aws_region="us-east-1"
```

#### 5. Service Quota Issues

**Problem**: vCPU quota too low
```
Error: EC2 vCPU limit (20) is below required minimum (100)
```

**Solution**:
```bash
# Option 1: Request quota increase in AWS Console
# Service Quotas > EC2 > Running On-Demand instances

# Option 2: Use dev environment (lower requirements)
export TF_VAR_environment="dev"  # Requires only 25 vCPUs

# Option 3: Override requirements
# In main.tf:
environment_overrides = {
  min_vcpu_quota = 20  # Lower requirement
}
```

### Debug Mode

Enable detailed logging:

```bash
# Set Terraform debug mode
export TF_LOG=DEBUG

# Enable dev debug features
export DEV_ENABLE_DEBUG=true

# Run validation with verbose output
terraform apply -target=module.pre_validation
```

### Validation Bypass

For development/testing, you can bypass specific validations:

```bash
# Disable quota validation
export TF_VAR_enable_quota_validation=false

# Disable ROSA CLI validation
export TF_VAR_enable_rosa_validation=false

# Apply with bypassed validations
terraform apply -target=module.pre_validation
```

## Advanced Usage

### Multi-Environment Validation

```bash
# Validate all environments
for env in dev staging prod; do
  echo "Validating $env environment..."
  cd environments/$env
  source export_env.sh
  terraform init
  terraform apply -target=module.pre_validation -auto-approve
  cd ../..
done
```

### CI/CD Integration

```bash
# Automated validation script
#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
cd environments/$ENVIRONMENT

# Source environment
source export_env.sh

# Initialize and validate
terraform init -backend=false  # Skip backend for CI
terraform validate
terraform plan -target=module.pre_validation
terraform apply -target=module.pre_validation -auto-approve

# Check results
if terraform output validation_status | grep -q "PASSED"; then
  echo "✅ Pre-validation passed for $ENVIRONMENT"
  exit 0
else
  echo "❌ Pre-validation failed for $ENVIRONMENT"
  exit 1
fi
```

### Custom Validation Rules

Add custom validation in your environment's main.tf:

```hcl
module "pre_validation" {
  source = "../../modules/pre-validation"
  
  # Custom overrides for specific requirements
  environment_overrides = {
    min_vcpu_quota           = 50    # Custom quota
    required_az_count        = 2     # Custom AZ requirement
    enable_strict_validation = false # Custom strictness
  }
  
  # Custom validation controls
  verify_rosa_quota      = false  # Skip ROSA quota for dev
  verify_aws_permissions = false  # Skip permissions for dev
}

# Additional custom validation
resource "null_resource" "custom_validation" {
  provisioner "local-exec" {
    command = <<-EOT
      # Custom validation script
      echo "Running custom validations..."
      
      # Example: Check custom requirements
      if [ "$CUSTOM_REQUIREMENT" != "met" ]; then
        echo "Custom requirement not met"
        exit 1
      fi
      
      echo "Custom validation passed"
    EOT
  }
}
```

This completes the step-by-step guide for creating and executing the ROSA pre-validation module with environment-specific customizations.