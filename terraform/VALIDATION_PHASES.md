# ROSA Validation Phases

The validation module has been restructured to support three distinct validation phases that can be executed at different stages of the Terraform deployment using targeted apply commands.

## Validation Phases Overview

### 1. **PRE-VALIDATION** (Before Infrastructure)
Validates basic prerequisites and configuration before creating any AWS resources.

**What it validates:**
- AWS region support for ROSA
- Availability zone count (≥3 required)
- Cluster name format and length
- OpenShift version format
- Instance type support
- Autoscaling configuration
- AWS service quotas (vCPU limits)
- ROSA CLI installation and permissions

**When to run:** Before any infrastructure creation

### 2. **INFRA-VALIDATION** (After Infrastructure Creation)
Validates infrastructure resources after VPC, subnets, and networking components are created.

**What it validates:**
- VPC CIDR validity
- Subnet count and configuration
- Private/PrivateLink networking setup
- Proxy configuration

**When to run:** After networking module but before ROSA cluster creation

### 3. **POST-VALIDATION** (After Cluster Deployment)
Validates the deployed ROSA cluster and its components.

**What it validates:**
- Cluster readiness status
- API and Console URL accessibility
- Node count verification
- Component health checks

**When to run:** After ROSA cluster deployment

## Terraform Commands by Phase

### Phase 1: Pre-Validation
```bash
# Run only pre-validation checks
terraform plan -target="module.validation.null_resource.pre_validate_region" \
               -target="module.validation.null_resource.pre_validate_availability_zones" \
               -target="module.validation.null_resource.pre_validate_cluster_config" \
               -target="module.validation.null_resource.pre_validate_autoscaling" \
               -target="module.validation.null_resource.pre_validate_quotas" \
               -target="module.validation.null_resource.pre_validate_rosa_cli"

terraform apply -target="module.validation.null_resource.pre_validate_region" \
                -target="module.validation.null_resource.pre_validate_availability_zones" \
                -target="module.validation.null_resource.pre_validate_cluster_config" \
                -target="module.validation.null_resource.pre_validate_autoscaling" \
                -target="module.validation.null_resource.pre_validate_quotas" \
                -target="module.validation.null_resource.pre_validate_rosa_cli"
```

### Phase 2: Infrastructure Creation + Infra-Validation
```bash
# Create networking infrastructure
terraform plan -target="module.networking" \
               -target="module.security" \
               -target="module.storage"

terraform apply -target="module.networking" \
                -target="module.security" \
                -target="module.storage"

# Run infrastructure validation
terraform plan -target="module.validation.null_resource.infra_validate_networking" \
               -target="module.validation.null_resource.infra_validate_proxy"

terraform apply -target="module.validation.null_resource.infra_validate_networking" \
                -target="module.validation.null_resource.infra_validate_proxy"
```

### Phase 3: ROSA Cluster Creation + Post-Validation
```bash
# Create ROSA cluster
terraform plan -target="module.compute" \
               -target="module.monitoring" \
               -target="module.backup"

terraform apply -target="module.compute" \
                -target="module.monitoring" \
                -target="module.backup"

# Run post-deployment validation
terraform plan -target="module.validation.null_resource.post_wait_for_cluster" \
               -target="module.validation.null_resource.post_validate_cluster_components"

terraform apply -target="module.validation.null_resource.post_wait_for_cluster" \
                -target="module.validation.null_resource.post_validate_cluster_components"
```

## Simplified Commands Using Wildcards

### Pre-Validation Only
```bash
# Note: Wildcards don't work directly with -target, but you can use them in scripts
terraform apply -target="module.validation" -var="enable_infra_validation=false" -var="enable_post_validation=false"
```

### All Phases Sequentially
```bash
# 1. Pre-validation
terraform apply -target="module.validation" -var="enable_infra_validation=false" -var="enable_post_validation=false"

# 2. Infrastructure + Infra-validation
terraform apply -target="module.networking" -target="module.security" -target="module.storage"
terraform apply -target="module.validation" -var="enable_pre_validation=false" -var="enable_post_validation=false"

# 3. ROSA Cluster + Post-validation
terraform apply -target="module.compute" -target="module.monitoring" -target="module.backup"
terraform apply -target="module.validation" -var="enable_pre_validation=false" -var="enable_infra_validation=false"
```

## Configuration Variables

Control which validation phases are enabled:

```hcl
# In your terraform.tfvars or main.tf
enable_pre_validation   = true   # Region, quotas, ROSA CLI validation
enable_infra_validation = true   # VPC, subnet, networking validation
enable_post_validation  = true   # Cluster readiness and component validation
enable_quota_validation = true   # AWS service quota checks
enable_rosa_validation  = true   # ROSA CLI prerequisites
```

## Validation Resource Tags

All validation resources are tagged with:
- `ValidationPhase`: "pre", "infra", or "post"
- `ValidationType`: Specific validation type (e.g., "region", "networking", "cluster_readiness")

## Benefits of Phased Validation

1. **Early Issue Detection**: Catch configuration issues before infrastructure creation
2. **Resource Efficiency**: Don't create expensive resources if basic validation fails
3. **Debugging**: Easier to identify which phase is causing issues
4. **Flexibility**: Run only specific validation phases as needed
5. **CI/CD Integration**: Different pipeline stages can run different validation phases

## Example Workflow

```bash
# 1. Start with pre-validation
terraform init
terraform apply -target="module.validation" -var="enable_infra_validation=false" -var="enable_post_validation=false"

# 2. If pre-validation passes, create infrastructure
terraform apply -target="module.networking" -target="module.security" -target="module.storage"

# 3. Validate infrastructure
terraform apply -target="module.validation" -var="enable_pre_validation=false" -var="enable_post_validation=false"

# 4. If infra validation passes, create ROSA cluster
terraform apply -target="module.compute" -target="module.monitoring" -target="module.backup"

# 5. Final post-deployment validation
terraform apply -target="module.validation" -var="enable_pre_validation=false" -var="enable_infra_validation=false"
```

This approach ensures each phase is validated before proceeding to the next, reducing deployment failures and improving debugging capabilities.