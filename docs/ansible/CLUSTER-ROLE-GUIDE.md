# ROSA Cluster Creation Role - Step-by-Step Guide

## Overview

This guide provides comprehensive instructions for creating and using the ROSA cluster creation Ansible role. The cluster role extends the existing aws-setup, rosa-cli, and validation roles to provide complete ROSA cluster lifecycle management.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Role Structure](#role-structure)
3. [Environment Configuration](#environment-configuration)
4. [Variable Configuration](#variable-configuration)
5. [Usage Instructions](#usage-instructions)
6. [Task Breakdown](#task-breakdown)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

## Prerequisites

Before using the cluster role, ensure the following prerequisites are met:

### 1. Completed Setup Roles
- **aws-setup role**: AWS CLI configuration and service account validation
- **rosa-cli role**: ROSA CLI installation and authentication
- **validation role**: Environment and prerequisite validation

### 2. Required Environment Variables
The role depends on environment-specific variables created by previous roles:
- AWS credentials and region configuration
- ROSA CLI authentication tokens
- Validated service account permissions

### 3. Cluster Environment Structure
```
environments/
├── dev/
│   ├── cluster-config.yml
│   └── .env
├── test/
│   ├── cluster-config.yml
│   └── .env
└── prod/
    ├── cluster-config.yml
    └── .env
```

## Role Structure

The cluster role follows Ansible best practices with the following structure:

```
roles/cluster/
├── defaults/
│   └── main.yml                    # Default values referencing variables
├── vars/
│   └── cluster-variables.yml       # Supported versions, regions, timeouts
├── tasks/
│   ├── main.yml                    # Main orchestrator
│   ├── check_existing_cluster.yml  # Existing cluster handling
│   ├── create_account_roles.yml    # ROSA account roles creation
│   ├── create_oidc_configuration.yml # OIDC configuration setup
│   ├── create_rosa_cluster.yml     # Main cluster creation
│   ├── monitor_cluster_status.yml  # Cluster readiness monitoring
│   ├── configure_cluster_access.yml # Admin users and access
│   └── update_cluster_environment.yml # Environment file updates
└── meta/
    └── main.yml                    # Role dependencies and metadata
```

## Environment Configuration

### Step 1: Create Environment-Specific Cluster Configurations

#### Development Environment (`environments/dev/cluster-config.yml`)
```yaml
---
# Development Environment Cluster Configuration
cluster_name_prefix: "rosa-cluster"
target_environment: "dev"

# Compute Configuration
compute_nodes: 2
compute_machine_type: "m5n.xlarge"
enable_autoscaling: true
min_replicas: 2
max_replicas: 4

# Network Configuration
machine_cidr: "10.0.0.0/16"
service_cidr: "172.30.0.0/16"
pod_cidr: "10.128.0.0/14"
host_prefix: 23
multi_az: false

# Security and Features
private_cluster: false
privatelink_enabled: false
enable_fips: false
enable_etcd_encryption: false

# Access Configuration
create_admin_user: true
dedicated_admin_user: ""

# Identity Provider (optional)
identity_provider:
  enabled: false
  type: "github"
  name: "github-idp"
  client_id: ""
  client_secret: ""
  organizations: []
```

#### Test Environment (`environments/test/cluster-config.yml`)
```yaml
---
# Test Environment Cluster Configuration
cluster_name_prefix: "rosa-cluster"
target_environment: "test"

# Compute Configuration
compute_nodes: 3
compute_machine_type: "m5n.xlarge"
enable_autoscaling: true
min_replicas: 3
max_replicas: 6

# Network Configuration
machine_cidr: "10.1.0.0/16"
service_cidr: "172.31.0.0/16"
pod_cidr: "10.129.0.0/14"
host_prefix: 23
multi_az: true

# Security and Features
private_cluster: false
privatelink_enabled: false
enable_fips: false
enable_etcd_encryption: true

# Access Configuration
create_admin_user: true
dedicated_admin_user: "test-admin@company.com"

# Identity Provider
identity_provider:
  enabled: true
  type: "github"
  name: "github-test"
  client_id: "your-github-client-id"
  client_secret: "your-github-client-secret"
  organizations: ["your-org"]
```

#### Production Environment (`environments/prod/cluster-config.yml`)
```yaml
---
# Production Environment Cluster Configuration
cluster_name_prefix: "rosa-cluster"
target_environment: "prod"

# Compute Configuration
compute_nodes: 6
compute_machine_type: "m5n.2xlarge"
enable_autoscaling: true
min_replicas: 6
max_replicas: 12

# Network Configuration
machine_cidr: "10.2.0.0/16"
service_cidr: "172.32.0.0/16"
pod_cidr: "10.130.0.0/14"
host_prefix: 23
multi_az: true

# Security and Features
private_cluster: true
privatelink_enabled: true
enable_fips: true
enable_etcd_encryption: true

# Access Configuration
create_admin_user: true
dedicated_admin_user: "prod-admin@company.com"

# Identity Provider
identity_provider:
  enabled: true
  type: "google"
  name: "google-sso"
  client_id: "your-google-client-id"
  client_secret: "your-google-client-secret"
  hosted_domain: "company.com"
```

### Step 2: Variable Configuration

#### Cluster Variables (`roles/cluster/vars/cluster-variables.yml`)
```yaml
---
# Supported OpenShift versions
supported_openshift_versions:
  - "4.17.34"
  - "4.18.19"
  - "4.19.2"

# Supported AWS regions
supported_aws_regions:
  - "us-east-1"
  - "us-west-2"
  - "eu-west-1"
  - "ap-southeast-1"

# Supported instance types by category
compute_instance_types:
  small: ["m5.large", "m5.xlarge"]
  medium: ["m5.xlarge", "m5.2xlarge"]
  large: ["m5.2xlarge", "m5.4xlarge"]

# Timeout configurations
cluster_creation_timeout_minutes: 60
cluster_deletion_timeout_minutes: 30

# Default network configurations
default_network_config:
  machine_cidr: "10.0.0.0/16"
  service_cidr: "172.30.0.0/16"
  pod_cidr: "10.128.0.0/14"
  host_prefix: 23

# ROSA modes
supported_modes:
  - "auto"
  - "manual"

# Feature flags
default_feature_flags:
  validate_cluster_config: true
  validate_prerequisites: false  # Already done by validation role
  wait_for_cluster_ready: true
  create_admin_user: true
```

#### Default Values (`roles/cluster/defaults/main.yml`)
```yaml
---
# Default cluster configuration values
openshift_version: "{{ supported_openshift_versions[-1] }}"
aws_region: "{{ supported_aws_regions[0] }}"
mode: "auto"

# Network defaults
machine_cidr: "{{ default_network_config.machine_cidr }}"
service_cidr: "{{ default_network_config.service_cidr }}"
pod_cidr: "{{ default_network_config.pod_cidr }}"
host_prefix: "{{ default_network_config.host_prefix }}"

# Compute defaults
compute_nodes: 3
compute_machine_type: "m5n.xlarge"
enable_autoscaling: true
min_replicas: 3
max_replicas: 6

# Feature defaults
multi_az: false
private_cluster: false
privatelink_enabled: false
enable_fips: false
enable_etcd_encryption: false

# Access defaults
create_admin_user: "{{ default_feature_flags.create_admin_user }}"

# Timeout defaults
cluster_creation_timeout_minutes: "{{ cluster_creation_timeout_minutes }}"

# Environment path variable
ansible_env_path: "{{ playbook_dir }}/environments/{{ target_environment }}"
```

## Usage Instructions

### Step 1: Set Target Environment
```bash
export ANSIBLE_TARGET_ENV=dev  # or test, prod
```

### Step 2: Run Complete Setup (Recommended)
```bash
# Run all roles including cluster creation
ansible-playbook playbooks/main.yml -e target_environment=dev

# Or with specific tags
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster"
```

### Step 3: Run Cluster Role Only
```bash
# If prerequisites are already met
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster" --skip-tags "aws,rosa,validation"
```

### Step 4: Environment-Specific Deployment
```bash
# Development
ansible-playbook playbooks/main.yml -e target_environment=dev

# Test
ansible-playbook playbooks/main.yml -e target_environment=test

# Production
ansible-playbook playbooks/main.yml -e target_environment=prod
```

### Step 5: Specific Task Execution
```bash
# Only check existing clusters
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster-check"

# Only create account roles and OIDC
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster-setup"

# Only monitor cluster status
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster-monitor"
```

## Task Breakdown

### 1. Main Orchestrator (`main.yml`)
- Loads cluster variables and configuration
- Orchestrates all cluster creation tasks
- Provides environment-specific execution flow

### 2. Existing Cluster Check (`check_existing_cluster.yml`)
- **Purpose**: Handles existing cluster conflicts intelligently
- **Features**:
  - Detects existing clusters with same name
  - Prompts user for action: use existing, delete/recreate, or abort
  - Sets flags for subsequent tasks based on user choice
- **User Interaction**: 
  ```
  ⚠️  Cluster 'rosa-cluster-dev' already exists!
  
  What would you like to do?
  1. Use existing cluster (skip creation)
  2. Delete existing cluster and recreate
  3. Abort (exit without changes)
  
  Please enter your choice (1/2/3): 
  ```

### 3. Account Roles Creation (`create_account_roles.yml`)
- **Purpose**: Creates ROSA account-wide STS roles and policies
- **Features**:
  - Checks for existing account roles
  - Creates only if missing
  - Supports both auto and manual modes

### 4. OIDC Configuration (`create_oidc_configuration.yml`)
- **Purpose**: Sets up OpenID Connect configuration for cluster authentication
- **Features**:
  - Creates OIDC configuration if none exists
  - Lists OIDC configurations to extract ID after creation
  - Properly handles existing OIDC configurations with fallback logic
  - Uses robust ID extraction from ROSA CLI output

### 5. Cluster Creation (`create_rosa_cluster.yml`)
- **Purpose**: Main ROSA cluster creation logic
- **Features**:
  - Handles cluster deletion if requested
  - Skips creation if using existing cluster
  - Uses proper ROSA CLI syntax with `--cluster-name` and `--replicas` parameters
  - Updated for latest ROSA CLI command deprecations
  - Comprehensive parameter handling for all cluster options
  - Environment-specific configuration loading

### 6. Status Monitoring (`monitor_cluster_status.yml`)
- **Purpose**: Monitors cluster creation progress until ready
- **Features**:
  - Polls cluster status every 60 seconds
  - Configurable timeout (default: 60 minutes)
  - Progress display with elapsed time
  - Extracts final cluster information (API URL, Console URL)

### 7. Access Configuration (`configure_cluster_access.yml`)
- **Purpose**: Sets up cluster access and admin users
- **Features**:
  - Creates operator roles for cluster
  - Creates cluster admin user with credentials
  - Grants dedicated admin access if specified
  - Configures identity providers (GitHub, Google, etc.)

### 8. Environment Updates (`update_cluster_environment.yml`)
- **Purpose**: Updates environment files with cluster information
- **Features**:
  - Updates environment-specific .env files
  - Creates cluster info markdown summary
  - Generates kubectl connection scripts
  - Maintains global cluster inventory

## Troubleshooting

### Common Issues and Solutions

#### 1. Cluster Already Exists
**Problem**: Cluster with same name exists
**Solution**: Use the interactive prompt to choose action:
- Option 1: Use existing cluster
- Option 2: Delete and recreate
- Option 3: Abort and change configuration

#### 2. Account Roles Missing
**Problem**: Account roles not found
**Solution**: Role automatically creates required account roles

#### 3. OIDC Configuration Issues
**Problem**: OIDC configuration ID extraction fails
**Solution**: The role now uses `rosa list oidc-config` to reliably extract OIDC configuration IDs. If issues persist, check AWS permissions and ROSA CLI version.

#### 4. Cluster Creation Timeout
**Problem**: Cluster takes longer than expected
**Solution**: Increase timeout in cluster-variables.yml:
```yaml
cluster_creation_timeout_minutes: 90
```

#### 4. Cluster Creation Command Issues
**Problem**: ROSA cluster creation fails with command syntax errors or deprecated parameter warnings
**Solution**: The role now uses proper ROSA CLI syntax with `--cluster-name` and conditional `--replicas` parameters (replacing deprecated `--compute-nodes`). When autoscaling is enabled, `--replicas` is omitted to avoid conflicts. Ensure ROSA CLI is updated to latest version and OpenShift versions are current.

#### 5. Instance Type Issues
**Problem**: Machine type not supported by ROSA
**Solution**: Use ROSA-supported instance types. Tested working types:
```yaml
compute_machine_type: "m5n.xlarge"    # Recommended for dev/test
compute_machine_type: "m5n.2xlarge"   # Recommended for production
compute_machine_type: "m5n.4xlarge"   # High-performance workloads
```

#### 6. Network Configuration Conflicts
**Problem**: CIDR conflicts with existing VPCs
**Solution**: Update network configuration in environment config:
```yaml
machine_cidr: "10.1.0.0/16"  # Change to non-conflicting range
```

### Debug Mode
```bash
# Run with verbose output
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster" -vvv

# Check specific task results
ansible-playbook playbooks/main.yml -e target_environment=dev --tags "cluster-check" -vvv
```

### Manual Verification
```bash
# Check cluster status
rosa describe cluster rosa-cluster-dev

# List account roles
rosa list account-roles

# Check OIDC configurations
rosa list oidc-config
```

## Advanced Configuration

### Custom Instance Types
Modify cluster-variables.yml to add custom instance types:
```yaml
compute_instance_types:
  custom: ["c5.large", "c5.xlarge", "c5.2xlarge"]
```

### Multi-Region Deployment
Create environment configs for different regions:
```yaml
# environments/prod-west/cluster-config.yml
aws_region: "us-west-2"
cluster_name_prefix: "rosa-cluster-west"
```

### Private Cluster Configuration
```yaml
# Enhanced security configuration
private_cluster: true
privatelink_enabled: true
enable_fips: true
enable_etcd_encryption: true
```

### Identity Provider Integration
```yaml
# GitHub Enterprise integration
identity_provider:
  enabled: true
  type: "github"
  name: "github-enterprise"
  client_id: "your-enterprise-client-id"
  client_secret: "your-enterprise-client-secret"
  organizations: ["company-org"]
  teams: ["platform-team", "devops-team"]
```

## File Outputs

After successful execution, the role creates:

1. **Environment Files**: `.env` files with cluster variables
2. **Cluster Info**: Markdown summary with all cluster details
3. **Connection Scripts**: Shell scripts for kubectl/oc login
4. **Global Inventory**: Master list of all clusters
5. **Backup Files**: Automatic backups of modified files

## Security Considerations

1. **Credentials**: Admin passwords are displayed once during creation
2. **Private Clusters**: Use private clusters for production workloads
3. **FIPS**: Enable FIPS mode for compliance requirements
4. **ETCD Encryption**: Enable for sensitive data protection
5. **Identity Providers**: Configure SSO for centralized access management

---

**Note**: This role is designed to work seamlessly with the existing aws-setup, rosa-cli, and validation roles. Always run the complete playbook for new environments to ensure all prerequisites are met.