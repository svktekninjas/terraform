# ROSA Validation Role - Learning Module

## Overview
The `validation` role performs comprehensive pre-validation checks before ROSA (Red Hat OpenShift Service on AWS) infrastructure creation. This role ensures that all prerequisites are met for successful ROSA cluster deployment across different environments (dev, test, prod).

## Role Structure
```
roles/validation/
├── tasks/
│   ├── main.yml                           # Orchestrates all validation tasks
│   ├── validate_aws_region.yml            # AWS region support validation
│   ├── validate_availability_zones.yml    # Availability zones validation
│   ├── validate_cluster_config.yml        # Cluster configuration validation
│   ├── validate_autoscaling_config.yml    # Autoscaling configuration validation
│   ├── validate_aws_quotas.yml           # AWS service quotas validation
│   └── validate_rosa_prerequisites.yml    # ROSA-specific prerequisites
├── defaults/                              # (Not used - relies on environment variables)
├── vars/
├── templates/
├── handlers/
├── meta/
└── README.md                              # Role documentation
```

## Environment Configuration Files
```
environments/
├── dev/dev.yml      # Development environment variables
├── test/test.yml    # Test environment variables
└── prod/prod.yml    # Production environment variables
```

## Step-by-Step Role Creation Guide

### Step 1: Create Role Directory Structure
```bash
# Navigate to ansible directory
cd /path/to/ansible

# Create validation role directories
mkdir -p roles/validation/{tasks,defaults,vars,templates,handlers,meta}

# Create environment directories
mkdir -p environments/{dev,test,prod}
```

**Important Notes:**
- The validation role does NOT use `defaults/main.yml` - it relies entirely on environment-specific variables
- The role must run AFTER aws-setup and rosa-cli roles for proper credential access
- All validation tasks include proper data type handling for string/integer comparisons

### Step 2: Create Environment-Specific Variable Files

#### Development Environment (`environments/dev/dev.yml`)
```yaml
---
environment_name: "dev"
aws_region: "us-east-1"
supported_aws_regions:
  - "us-east-1"
  - "us-east-2"
  - "us-west-1"
  - "us-west-2"
  - "ca-central-1"
  - "eu-central-1"
  - "eu-west-1"
  - "eu-west-2"
  - "eu-west-3"
  - "ap-northeast-1"
  - "ap-northeast-2"
  - "ap-southeast-1"
  - "ap-southeast-2"
  - "ap-south-1"
  - "sa-east-1"

required_availability_zones: 2
validate_availability_zones: true

cluster_name: "rosa-cluster"
openshift_version: "4.14"
instance_type: "m5.large"
supported_instance_types:
  - "m5.large"
  - "m5.xlarge"
  - "m5.2xlarge"
  - "c5.large"
  - "c5.xlarge"
  - "r5.large"
  - "r5.xlarge"

enable_autoscaling: true
min_replicas: 2
max_replicas: 5

min_vcpu_quota: 25
validate_service_quotas: true

validate_rosa_cli: true
validate_aws_cli: true
validate_aws_credentials: true
verify_rosa_quota: false
verify_aws_permissions: false

strict_validation: false
fail_fast: true
enable_debug_logging: true
log_validation_results: true
```

#### Test Environment (`environments/test/test.yml`)
```yaml
---
environment_name: "test"
# ... similar structure with test-specific values
required_availability_zones: 3
min_vcpu_quota: 100
instance_type: "m5.xlarge"
min_replicas: 3
max_replicas: 8
verify_rosa_quota: true
verify_aws_permissions: true
strict_validation: true
```

#### Production Environment (`environments/prod/prod.yml`)
```yaml
---
environment_name: "prod"
# ... similar structure with prod-specific values
required_availability_zones: 3
min_vcpu_quota: 200
instance_type: "m5.2xlarge"
min_replicas: 5
max_replicas: 15
verify_rosa_quota: true
verify_aws_permissions: true
strict_validation: true
enable_debug_logging: false
```

### Step 3: Create Validation Task Files

#### AWS Region Validation (`roles/validation/tasks/validate_aws_region.yml`)
```yaml
# AWS Region validation tasks
---
- name: "Get current AWS region"
  shell: aws configure get region
  register: current_aws_region
  changed_when: false
  failed_when: current_aws_region.rc != 0

- name: "Validate AWS region is supported for ROSA"
  assert:
    that:
      - current_aws_region.stdout in supported_aws_regions
    fail_msg: "❌ Region {{ current_aws_region.stdout }} is NOT supported for ROSA. Supported regions: {{ supported_aws_regions | join(', ') }}"
    success_msg: "✅ Region {{ current_aws_region.stdout }} is supported for ROSA"

- name: "Log AWS region validation result"
  debug:
    msg: "✅ AWS Region validation passed: {{ current_aws_region.stdout }}"
  when: enable_debug_logging | default(false)
```

#### Availability Zones Validation (`roles/validation/tasks/validate_availability_zones.yml`)
```yaml
# Availability Zones validation tasks
---
- name: "Get available availability zones"
  shell: aws ec2 describe-availability-zones --query 'length(AvailabilityZones[?State==`available`])' --output text
  register: available_az_count
  changed_when: false
  failed_when: available_az_count.rc != 0

- name: "Convert AZ count to integer"
  set_fact:
    az_count: "{{ available_az_count.stdout | int }}"

- name: "Validate sufficient availability zones for {{ environment_name }} environment"
  assert:
    that:
      - az_count | int >= required_availability_zones | int
    fail_msg: "❌ Insufficient AZs: {{ az_count }} (required: {{ required_availability_zones }}) for {{ environment_name }} environment"
    success_msg: "✅ Sufficient AZs: {{ az_count }} (required: {{ required_availability_zones }}) for {{ environment_name }} environment"

- name: "Log availability zones validation result"
  debug:
    msg: "✅ Availability Zones validation passed: {{ az_count }} AZs available (required: {{ required_availability_zones }})"
  when: enable_debug_logging | default(false)
```

**Important:** Always use `| int` filters when comparing numeric values to ensure proper data type handling in Ansible.

#### Cluster Configuration Validation (`roles/validation/tasks/validate_cluster_config.yml`)
```yaml
# Cluster configuration validation tasks
---
- name: "Set full cluster name with environment suffix"
  set_fact:
    full_cluster_name: "{{ cluster_name }}-{{ environment_name }}"

- name: "Validate cluster name format (alphanumeric and hyphens only)"
  assert:
    that:
      - full_cluster_name | regex_search('^[a-z0-9-]+$')
      - full_cluster_name | length <= 54
    fail_msg: "❌ Invalid cluster name: {{ full_cluster_name }}. Must be alphanumeric with hyphens only and ≤54 characters"
    success_msg: "✅ Cluster name valid: {{ full_cluster_name }}"

- name: "Validate OpenShift version format"
  assert:
    that:
      - openshift_version | regex_search('^4\.[0-9]+$')
    fail_msg: "❌ Invalid OpenShift version: {{ openshift_version }}. Must be in format 4.x"
    success_msg: "✅ OpenShift version valid: {{ openshift_version }}"

- name: "Validate instance type is supported"
  assert:
    that:
      - instance_type in supported_instance_types
    fail_msg: "❌ Instance type not supported: {{ instance_type }}. Supported types: {{ supported_instance_types | join(', ') }}"
    success_msg: "✅ Instance type supported: {{ instance_type }}"

- name: "Log cluster configuration validation result"
  debug:
    msg: 
      - "✅ Cluster configuration validation passed:"
      - "  - Cluster name: {{ full_cluster_name }}"
      - "  - OpenShift version: {{ openshift_version }}"
      - "  - Instance type: {{ instance_type }}"
  when: enable_debug_logging | default(false)
```

#### Autoscaling Configuration Validation (`roles/validation/tasks/validate_autoscaling_config.yml`)
```yaml
# Autoscaling configuration validation tasks
---
- name: "Validate autoscaling configuration when enabled"
  block:
    - name: "Validate min replicas is at least 1"
      assert:
        that:
          - min_replicas >= 1
        fail_msg: "❌ Minimum replicas must be ≥ 1, got: {{ min_replicas }}"
        success_msg: "✅ Minimum replicas valid: {{ min_replicas }}"

    - name: "Validate max replicas is greater than or equal to min replicas"
      assert:
        that:
          - max_replicas >= min_replicas
        fail_msg: "❌ Maximum replicas ({{ max_replicas }}) must be ≥ minimum replicas ({{ min_replicas }})"
        success_msg: "✅ Autoscaling range valid: {{ min_replicas }}-{{ max_replicas }} replicas"

    - name: "Log autoscaling configuration validation result"
      debug:
        msg: "✅ Autoscaling configuration validation passed: {{ min_replicas }}-{{ max_replicas }} replicas"
      when: enable_debug_logging | default(false)

  when: enable_autoscaling | default(false)

- name: "Log autoscaling disabled"
  debug:
    msg: "✅ Autoscaling is disabled for this configuration"
  when: 
    - not (enable_autoscaling | default(false))
    - enable_debug_logging | default(false)
```

#### AWS Service Quotas Validation (`roles/validation/tasks/validate_aws_quotas.yml`)
```yaml
# AWS Service Quotas validation tasks
---
- name: "Get EC2 vCPU quota for running On-Demand instances"
  shell: |
    aws service-quotas get-service-quota \
      --service-code ec2 \
      --quota-code L-34B43A08 \
      --query 'Quota.Value' \
      --output text 2>/dev/null || echo "0"
  register: vcpu_quota_result
  changed_when: false
  failed_when: false

- name: "Convert vCPU quota to integer"
  set_fact:
    current_vcpu_quota: "{{ vcpu_quota_result.stdout | int }}"

- name: "Display current vCPU quota and requirements"
  debug:
    msg:
      - "Current vCPU limit: {{ current_vcpu_quota }}"
      - "Required minimum for {{ environment_name }}: {{ min_vcpu_quota }}"
  when: enable_debug_logging | default(false)

- name: "Validate vCPU quota meets environment requirements"
  assert:
    that:
      - current_vcpu_quota | int >= min_vcpu_quota | int
    fail_msg: "❌ EC2 vCPU limit ({{ current_vcpu_quota }}) below required minimum ({{ min_vcpu_quota }}) for {{ environment_name }} environment"
    success_msg: "✅ vCPU quota sufficient: {{ current_vcpu_quota }} (required: {{ min_vcpu_quota }}) for {{ environment_name }} environment"

- name: "Log AWS quotas validation result"
  debug:
    msg: "✅ AWS quota validation passed for {{ environment_name }} environment: {{ current_vcpu_quota }} vCPUs available"
  when: enable_debug_logging | default(false)
```

**Note:** The `| int` filter ensures both values are treated as integers for proper comparison.

#### ROSA Prerequisites Validation (`roles/validation/tasks/validate_rosa_prerequisites.yml`)
```yaml
# ROSA-specific prerequisites validation tasks
# Note: AWS CLI, ROSA CLI installation, and admin access are validated by other roles
---
- name: "Verify ROSA quota for environment"
  shell: rosa verify quota --region={{ aws_region }}
  register: rosa_quota_result
  changed_when: false
  failed_when: false
  when: verify_rosa_quota | default(false)

- name: "Fail if ROSA quota verification failed"
  fail:
    msg: "❌ ROSA quota verification failed for {{ environment_name }} environment in region {{ aws_region }}"
  when: 
    - verify_rosa_quota | default(false)
    - rosa_quota_result.rc != 0

- name: "Verify ROSA-specific AWS permissions"
  shell: rosa verify permissions
  register: rosa_permissions_result
  changed_when: false
  failed_when: false
  when: verify_aws_permissions | default(false)

- name: "Fail if ROSA AWS permissions verification failed"
  fail:
    msg: "❌ ROSA-specific AWS permissions verification failed for {{ environment_name }} environment"
  when: 
    - verify_aws_permissions | default(false)
    - rosa_permissions_result.rc != 0

- name: "Log ROSA prerequisites validation results"
  debug:
    msg:
      - "✅ ROSA prerequisites validation passed:"
      - "  - ROSA quota verified: {{ verify_rosa_quota | default(false) }}"
      - "  - ROSA AWS permissions verified: {{ verify_aws_permissions | default(false) }}"
      - "  - Environment: {{ environment_name }}"
      - "  - Region: {{ aws_region }}"
  when: enable_debug_logging | default(false)
```

### Step 4: Create Main Tasks Orchestrator (`roles/validation/tasks/main.yml`)
```yaml
# Main tasks file for validation role
---
- name: "Start ROSA Pre-Validation for {{ environment_name }} environment"
  debug:
    msg: "🔍 Starting ROSA Pre-Validation for {{ environment_name }} environment"

- name: Include AWS region validation tasks
  include_tasks: validate_aws_region.yml
  tags:
    - validation
    - aws-region

- name: Include availability zones validation tasks
  include_tasks: validate_availability_zones.yml
  when: validate_availability_zones | default(true)
  tags:
    - validation
    - availability-zones

- name: Include cluster configuration validation tasks
  include_tasks: validate_cluster_config.yml
  tags:
    - validation
    - cluster-config

- name: Include autoscaling configuration validation tasks
  include_tasks: validate_autoscaling_config.yml
  when: enable_autoscaling | default(false)
  tags:
    - validation
    - autoscaling

- name: Include AWS service quotas validation tasks
  include_tasks: validate_aws_quotas.yml
  when: validate_service_quotas | default(true)
  tags:
    - validation
    - aws-quotas

- name: Include ROSA prerequisites validation tasks
  include_tasks: validate_rosa_prerequisites.yml
  when: verify_rosa_quota | default(false) or verify_aws_permissions | default(false)
  tags:
    - validation
    - rosa-prerequisites

- name: "Complete ROSA Pre-Validation for {{ environment_name }} environment"
  debug:
    msg: "✅ All ROSA Pre-Validation checks PASSED for {{ environment_name }} environment!"
```

### Step 5: Update Main Playbook (`playbooks/main.yml`)
```yaml
- name: ROSA Infrastructure Setup
  hosts: localhost
  connection: local
  gather_facts: yes
  
  pre_tasks:
    - name: Display playbook start
      debug:
        msg: "Starting ROSA infrastructure setup process"
  
  roles:
    - role: aws-setup
      tags: ['aws', 'setup']
    - role: rosa-cli
      tags: ['rosa', 'cli']
    - role: validation
      tags: ['validation', 'pre-checks']
  
  post_tasks:
    - name: Display playbook completion
      debug:
        msg: "ROSA infrastructure setup completed successfully"
```

**Important:** The validation role runs **after** aws-setup and rosa-cli roles because it requires:
- AWS credentials and CLI configuration (from aws-setup role)
- ROSA CLI installation and authentication (from rosa-cli role)

### Environment Files Created by Roles
After running the aws-setup and rosa-cli roles, environment-specific .env files are created:

```
environments/
├── dev/
│   ├── dev.yml     # Ansible variables
│   └── .env        # AWS and ROSA environment variables
├── test/
│   ├── test.yml    # Ansible variables  
│   └── .env        # AWS and ROSA environment variables
└── prod/
│   ├── prod.yml    # Ansible variables
│   └── .env        # AWS and ROSA environment variables
```

The .env files contain:
- AWS_PROFILE and AWS_REGION (from aws-setup role)
- ROSA_TOKEN (from rosa-cli role)
- ENVIRONMENT and TERRAFORM_WORKSPACE variables

## Role Execution Order
1. **aws-setup** - Configures AWS CLI, creates .env file with AWS credentials
2. **rosa-cli** - Installs ROSA CLI, adds ROSA_TOKEN to .env file  
3. **validation** - Validates all prerequisites using AWS and ROSA CLIs

## Usage Examples

### Prerequisites
Before running validation, ensure the following roles have been executed successfully:
1. **aws-setup** role - Sets up AWS credentials and creates .env file
2. **rosa-cli** role - Installs ROSA CLI and adds authentication token

### Step-by-Step Execution
```bash
# Step 1: Run AWS setup
ansible-playbook playbooks/main.yml --tags aws -e "target_environment=dev" -e "aws_profile=svktek" -e "aws_region=us-east-1"

# Step 2: Run ROSA CLI setup (requires ROSA auth token)
ansible-playbook playbooks/main.yml --tags rosa -e "target_environment=dev" -e "rosa_auth_token=YOUR_ROSA_TOKEN"

# Step 3: Run validation (uses environment variables from previous steps)
ansible-playbook playbooks/main.yml --tags validation -e @environments/dev/dev.yml
```

### Basic Execution
```bash
# Run all validations for dev environment (after aws-setup and rosa-cli)
ansible-playbook playbooks/main.yml --tags validation -e @environments/dev/dev.yml

# Run all validations for prod environment
ansible-playbook playbooks/main.yml --tags validation -e @environments/prod/prod.yml
```

### Tag-Based Execution
```bash
# Run only validation role
ansible-playbook -i inventory playbooks/main.yml -e @environments/dev/dev.yml --tags validation

# Run specific validation
ansible-playbook -i inventory playbooks/main.yml -e @environments/dev/dev.yml --tags aws-region

# Run multiple specific validations
ansible-playbook -i inventory playbooks/main.yml -e @environments/dev/dev.yml --tags "aws-region,cluster-config"
```

### Environment-Specific Execution
```bash
# Development with minimal checks
ansible-playbook -i inventory playbooks/main.yml -e @environments/dev/dev.yml --tags validation

# Test with strict validation
ansible-playbook -i inventory playbooks/main.yml -e @environments/test/test.yml --tags validation

# Production with all checks
ansible-playbook -i inventory playbooks/main.yml -e @environments/prod/prod.yml --tags validation
```

## Available Tags
- `validation` - All validation tasks
- `pre-checks` - Alias for validation
- `aws-region` - AWS region validation only
- `availability-zones` - AZ validation only
- `cluster-config` - Cluster configuration validation only
- `autoscaling` - Autoscaling configuration validation only
- `aws-quotas` - AWS service quotas validation only
- `rosa-prerequisites` - ROSA-specific prerequisites only

## Validation Tasks Summary

| Task | Purpose | Environment Variables |
|------|---------|----------------------|
| AWS Region | Validate region support | `supported_aws_regions` |
| Availability Zones | Check AZ count | `required_availability_zones` |
| Cluster Config | Validate cluster settings | `cluster_name`, `openshift_version`, `instance_type` |
| Autoscaling | Check replica settings | `min_replicas`, `max_replicas` |
| AWS Quotas | Check vCPU quotas | `min_vcpu_quota` |
| ROSA Prerequisites | ROSA-specific checks | `verify_rosa_quota`, `verify_aws_permissions` |

## Environment Comparison

| Setting | Dev | Test | Prod |
|---------|-----|------|------|
| Required AZs | 2 | 3 | 3 |
| Min vCPU Quota | 25 | 100 | 200 |
| Instance Type | m5.large | m5.xlarge | m5.2xlarge |
| Min Replicas | 2 | 3 | 5 |
| Max Replicas | 5 | 8 | 15 |
| Verify ROSA Quota | false | true | true |
| Verify AWS Permissions | false | true | true |
| Strict Validation | false | true | true |
| Debug Logging | true | true | false |

## Best Practices for Implementation

### Key Implementation Guidelines

#### 1. Data Type Handling in Assertions
Always use `| int` filters when comparing numeric values from shell commands:
```yaml
# Correct approach for numeric comparisons
assert:
  that:
    - shell_output | int >= environment_requirement | int
```

#### 2. Role Execution Dependencies
The validation role requires these roles to run first:
1. **aws-setup** - Creates AWS credentials and .env file
2. **rosa-cli** - Adds ROSA authentication token

#### 3. Environment Variable Structure
Use consistent variable naming across environments:
- `environment_name` - Environment identifier (dev/test/prod)
- `required_availability_zones` - Number of AZs needed
- `min_vcpu_quota` - Minimum vCPU quota required

### Configuration Validation
When creating environment files, ensure:
1. **AWS Region**: Use only ROSA-supported regions
2. **Cluster Name**: Alphanumeric + hyphens only, ≤54 characters  
3. **Resource Quotas**: Match your AWS account limits
4. **Instance Types**: Use only supported EC2 instance types

### Debug and Logging
Enable comprehensive logging for development:
```yaml
enable_debug_logging: true
log_validation_results: true
```

## Learning Objectives
After completing this module, you should understand:
1. How to structure Ansible roles with modular task files
2. Environment-specific variable management
3. Ansible assertions and error handling
4. Tag-based task execution
5. Role integration in playbooks
6. ROSA infrastructure prerequisites
7. AWS service validation techniques