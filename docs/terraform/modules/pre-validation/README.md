# ROSA Pre-Validation Module

## Overview

The Pre-Validation Module is a standalone Terraform module designed to validate all prerequisites before creating any AWS infrastructure for ROSA (Red Hat OpenShift Service on AWS). It provides environment-aware validation with customizable strictness levels for dev, staging, and production environments.

## Features

- **Environment-Aware Validation**: Different validation criteria for dev/staging/prod
- **AWS Prerequisites**: Region support, availability zones, service quotas
- **ROSA CLI Validation**: Installation, version, permissions, quotas
- **Cluster Configuration**: Name format, OpenShift version, instance types
- **Autoscaling Validation**: Min/max replica configuration
- **Cost Optimization**: Environment-specific resource requirements
- **Comprehensive Outputs**: Detailed validation results and next steps

## Module Structure

```
modules/pre-validation/
├── main.tf           # Core validation logic
├── variables.tf      # Input variables and validation
└── outputs.tf        # Validation results and information
```

## Environment Integration

The module integrates with environment-specific folders to load customizations:

```
environments/
├── dev/
│   ├── main.tf           # Uses pre-validation module
│   └── export_env.sh     # Environment variables
├── staging/
└── prod/
```

## Validation Types

### 1. AWS Infrastructure Prerequisites
- **Region Support**: Validates AWS region is ROSA-compatible
- **Availability Zones**: Ensures sufficient AZs (env-dependent)
- **Service Quotas**: Checks EC2 vCPU limits

### 2. ROSA CLI Prerequisites
- **Installation**: Verifies ROSA CLI is installed
- **Version Check**: Reports ROSA CLI version
- **AWS Credentials**: Validates AWS authentication
- **Permissions**: Checks AWS permissions (environment-dependent)
- **ROSA Quotas**: Validates ROSA service quotas

### 3. Cluster Configuration
- **Cluster Name**: Format and length validation
- **OpenShift Version**: Version format validation
- **Instance Types**: ROSA-compatible instance validation
- **Autoscaling**: Min/max replica consistency

### 4. Environment Validation
- **Environment Type**: Validates environment (dev/staging/prod)
- **Configuration**: Environment-specific settings

## Environment-Specific Behavior

| Validation | Dev | Staging | Prod |
|------------|-----|---------|------|
| Required AZs | 2 | 3 | 3 |
| Min vCPU Quota | 25 | 100 | 200 |
| Strict Validation | ❌ | ✅ | ✅ |
| AWS Permissions Check | ❌ | ✅ | ✅ |
| ROSA Quota Check | Optional | Required | Required |
| Timeout | 30 min | 40 min | 60 min |

## Quick Start

### 1. Source Environment Variables

```bash
# Navigate to dev environment
cd environments/dev

# Source environment-specific variables
source export_env.sh
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Run Pre-Validation

```bash
# Plan pre-validation
terraform plan -target=module.pre_validation

# Apply pre-validation
terraform apply -target=module.pre_validation
```

### 4. Review Results

```bash
# View validation outputs
terraform output pre_validation_results
terraform output validation_status
terraform output next_steps
```

## Detailed Usage Guide

### Step 1: Environment Setup

```bash
# Clone repository and navigate to environment
cd terraform/environments/dev

# Source environment variables
source export_env.sh

# This sets:
# - AWS_PROFILE, AWS_REGION
# - TF_VAR_* variables
# - Environment customizations
```

### Step 2: Customize Configuration (Optional)

Edit `main.tf` to customize validation behavior:

```hcl
module "pre_validation" {
  source = "../../modules/pre-validation"
  
  # Override default environment settings
  environment_overrides = {
    min_vcpu_quota           = 50    # Custom quota requirement
    required_az_count        = 2     # Custom AZ requirement
    enable_strict_validation = false # Relax validation
  }
  
  # Control validation types
  enable_quota_validation = true
  enable_rosa_validation  = true
  verify_rosa_quota      = false  # Skip for dev
}
```

### Step 3: Execute Validation

```bash
# Initialize Terraform
terraform init

# Plan (dry run)
terraform plan -target=module.pre_validation

# Apply validation
terraform apply -target=module.pre_validation
```

### Step 4: Analyze Results

```bash
# Check overall status
terraform output validation_status

# View specific validation results
terraform output pre_validation_results

# Get environment information
terraform output environment_info

# See next steps
terraform output next_steps
```

## Variable Reference

### Core Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | string | - | Environment (dev/staging/prod) |
| `cluster_name` | string | - | ROSA cluster name |
| `openshift_version` | string | "4.14" | OpenShift version |
| `compute_machine_type` | string | "m5.xlarge" | EC2 instance type |

### Autoscaling Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_autoscaling` | bool | true | Enable autoscaling |
| `min_replicas` | number | 2 | Minimum worker nodes |
| `max_replicas` | number | 10 | Maximum worker nodes |

### Validation Control

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_validation` | bool | true | Enable pre-validation |
| `enable_quota_validation` | bool | true | Enable quota checks |
| `enable_rosa_validation` | bool | true | Enable ROSA CLI checks |
| `verify_rosa_quota` | bool | true | Verify ROSA quotas |
| `verify_aws_permissions` | bool | false | Verify AWS permissions |

## Output Reference

### Validation Results

```hcl
# Overall validation status
output "validation_status" {
  value = {
    overall_status = "PASSED"  # or "FAILED"
    environment   = "dev"
  }
}

# Detailed validation results
output "pre_validation_results" {
  value = {
    region_valid            = true
    az_count_sufficient     = true
    cluster_name_valid      = true
    openshift_version_valid = true
    instance_type_valid     = true
    autoscaling_config_valid = true
    environment_valid       = true
  }
}
```

### Environment Information

```hcl
output "environment_info" {
  value = {
    environment       = "dev"
    region           = "us-east-1"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    az_count         = 3
    required_az_count = 2
  }
}
```

### Next Steps

```hcl
output "next_steps" {
  value = [
    "✅ Pre-validation completed successfully",
    "▶️  Next: Create infrastructure with terraform apply -target=module.networking",
    "▶️  Then: Run infra-validation phase"
  ]
}
```

## Troubleshooting

### Common Issues

#### 1. Region Not Supported
```
Error: Region us-west-3 is not supported for ROSA
```
**Solution**: Use a supported region (us-east-1, us-west-2, eu-west-1, etc.)

#### 2. Insufficient Availability Zones
```
Error: Region must have at least 3 availability zones for prod environment
```
**Solution**: 
- Choose region with more AZs for prod
- Use dev environment (requires only 2 AZs)

#### 3. vCPU Quota Too Low
```
Error: EC2 vCPU limit (20) is below required minimum (100)
```
**Solution**: 
- Request quota increase in AWS Service Quotas
- Use dev environment (lower requirements)

#### 4. ROSA CLI Not Found
```
Error: ROSA CLI is not installed
```
**Solution**: Install ROSA CLI:
```bash
curl -L https://github.com/openshift/rosa/releases/latest/download/rosa-linux.tar.gz | tar -xz
sudo mv rosa /usr/local/bin/
```

#### 5. AWS Permissions Issues
```
Error: AWS permissions verification failed
```
**Solution**:
- Check AWS credentials: `aws sts get-caller-identity`
- Verify IAM permissions for ROSA
- Use `verify_aws_permissions = false` for dev

### Debug Mode

Enable verbose output:

```bash
# Set debug environment variables
export TF_LOG=DEBUG
export DEV_ENABLE_DEBUG=true

# Run validation with detailed logging
terraform apply -target=module.pre_validation
```

## Advanced Configuration

### Custom Environment Overrides

```hcl
module "pre_validation" {
  source = "../../modules/pre-validation"
  
  environment_overrides = {
    min_vcpu_quota           = 25    # Lower for cost optimization
    cluster_ready_timeout    = 1800  # 30 minutes
    required_az_count        = 2     # Relaxed requirement
    enable_strict_validation = false # Dev-friendly
  }
}
```

### Selective Validation

```hcl
module "pre_validation" {
  source = "../../modules/pre-validation"
  
  # Run only basic validation
  enable_quota_validation = false
  enable_rosa_validation  = false
  verify_rosa_quota      = false
}
```

### Multi-Environment Usage

```bash
# Dev environment
cd environments/dev
terraform apply -target=module.pre_validation

# Staging environment
cd ../staging
terraform apply -target=module.pre_validation

# Production environment
cd ../prod
terraform apply -target=module.pre_validation
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: ROSA Pre-Validation
on: [push, pull_request]

jobs:
  pre-validation:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Source Environment
        run: |
          cd terraform/environments/${{ matrix.environment }}
          source export_env.sh
          
      - name: Run Pre-Validation
        run: |
          cd terraform/environments/${{ matrix.environment }}
          terraform init
          terraform plan -target=module.pre_validation
          terraform apply -target=module.pre_validation -auto-approve
```

## Best Practices

### 1. Environment Isolation
- Use separate AWS accounts for dev/staging/prod
- Configure different IAM roles per environment
- Use environment-specific state backends

### 2. Validation Strategy
- Run pre-validation before any infrastructure changes
- Include validation in CI/CD pipelines
- Use relaxed validation for development
- Enable strict validation for production

### 3. Cost Optimization
- Use smaller instance types in dev
- Reduce quota requirements for dev
- Consider single-AZ deployments for dev

### 4. Security
- Store sensitive variables in AWS Secrets Manager
- Use IAM roles instead of access keys
- Enable CloudTrail for audit logging

## Examples

### Development Environment
```bash
cd environments/dev
source export_env.sh
terraform init
terraform apply -target=module.pre_validation
```

### Staging Environment
```bash
cd environments/staging
source export_env.sh
terraform init
terraform apply -target=module.pre_validation
```

### Production Environment
```bash
cd environments/prod
source export_env.sh
terraform init
terraform apply -target=module.pre_validation
```

## Support

For issues and questions:
1. Check troubleshooting section above
2. Review Terraform logs with `TF_LOG=DEBUG`
3. Validate AWS credentials and permissions
4. Ensure ROSA CLI is properly installed
5. Check AWS service quotas in target region

## Next Steps

After successful pre-validation:
1. **Infrastructure Phase**: Create VPC, subnets, security groups
2. **Infra-Validation Phase**: Validate created infrastructure
3. **ROSA Deployment Phase**: Create ROSA cluster
4. **Post-Validation Phase**: Validate deployed cluster

See [VALIDATION_PHASES.md](../../../VALIDATION_PHASES.md) for complete workflow.