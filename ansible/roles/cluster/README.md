# ROSA Cluster Role

A comprehensive Ansible role for creating and managing Red Hat OpenShift Service on AWS (ROSA) clusters with STS (Security Token Service) support.

## Quick Start

### Tested Working Command
```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e cluster_name_prefix=svktek-clstr \
  -e dedicated_admin_user=svktek-dev-admin \
  -e openshift_version=4.18.19 \
  -e compute_machine_type=m5n.xlarge \
  --tags "cluster"
```

This command creates a development ROSA cluster with:
- **Cluster Name**: `svktek-clstr-dev`
- **OpenShift Version**: `4.18.19` (latest supported)
- **Instance Type**: `m5n.xlarge` (ROSA-supported)
- **Autoscaling**: Enabled (2-4 replicas)
- **Admin User**: `svktek-dev-admin`

### Prerequisites
- AWS CLI configured with appropriate permissions
- ROSA CLI installed and authenticated
- ROSA service enabled in AWS Console ([Enable here](https://console.aws.amazon.com/rosa/home))
- Completed aws-setup, rosa-cli, and validation roles

## Table of Contents

- [Overview](#overview)
- [Dependencies](#dependencies)
- [Role Variables](#role-variables)
- [Usage Examples](#usage-examples)
- [Variable Override Methods](#variable-override-methods)
- [Environment-Specific Execution](#environment-specific-execution)
- [Tags and Selective Execution](#tags-and-selective-execution)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

## Overview

This role automates the complete ROSA cluster lifecycle including:
- Account roles and OIDC configuration setup
- Existing cluster detection and handling
- Cluster creation with comprehensive parameter support
- Status monitoring and readiness verification
- Admin user creation and access configuration
- Environment file updates and documentation generation

## Dependencies

This role depends on the following roles (executed in order):
1. `aws-setup` - AWS CLI configuration and service account validation
2. `rosa-cli` - ROSA CLI installation and authentication
3. `validation` - Environment and prerequisite validation

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `target_environment` | Target deployment environment | `dev`, `test`, `prod` |
| `cluster_name_prefix` | Prefix for cluster name | `rosa-cluster` |

### Core Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `openshift_version` | `4.19.2` | OpenShift version to deploy |
| `aws_region` | `us-east-1` | AWS region for cluster deployment |
| `compute_nodes` | `3` | Number of compute nodes |
| `compute_machine_type` | `m5n.xlarge` | EC2 instance type for compute nodes |
| `mode` | `auto` | ROSA deployment mode (`auto` or `manual`) |

### Network Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `machine_cidr` | `10.0.0.0/16` | CIDR block for machine network |
| `service_cidr` | `172.30.0.0/16` | CIDR block for service network |
| `pod_cidr` | `10.128.0.0/14` | CIDR block for pod network |
| `host_prefix` | `23` | Host prefix for node subnets |

### Autoscaling Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_autoscaling` | `true` | Enable cluster autoscaling |
| `min_replicas` | `3` | Minimum number of compute nodes |
| `max_replicas` | `6` | Maximum number of compute nodes |

### Feature Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `multi_az` | `false` | Deploy across multiple availability zones |
| `private_cluster` | `false` | Create private cluster |
| `privatelink_enabled` | `false` | Enable AWS PrivateLink |
| `enable_fips` | `false` | Enable FIPS mode |
| `enable_etcd_encryption` | `false` | Enable etcd encryption at rest |

### Access Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `create_admin_user` | `true` | Create cluster admin user |
| `dedicated_admin_user` | `""` | Email for dedicated admin access |

### Identity Provider Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `identity_provider.enabled` | `false` | Enable identity provider |
| `identity_provider.type` | `github` | Provider type (`github`, `google`) |
| `identity_provider.name` | `github-idp` | Identity provider name |
| `identity_provider.client_id` | `""` | OAuth client ID |
| `identity_provider.client_secret` | `""` | OAuth client secret |

### Timeout Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_creation_timeout_minutes` | `60` | Cluster creation timeout |
| `wait_for_cluster_ready` | `true` | Wait for cluster to be ready |

## Usage Examples

### Basic Cluster Creation

```bash
# Create development cluster with defaults
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  --tags "cluster"
```

### Override Variables via Command Line

```bash
# Create cluster with custom configuration
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e cluster_name_prefix=my-rosa-cluster \
  -e compute_nodes=6 \
  -e compute_machine_type=m5n.2xlarge \
  -e multi_az=true \
  -e private_cluster=true \
  --tags "cluster"
```

### Production Cluster with Enhanced Security

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e cluster_name_prefix=prod-rosa \
  -e compute_nodes=9 \
  -e compute_machine_type=m5n.4xlarge \
  -e enable_autoscaling=true \
  -e min_replicas=9 \
  -e max_replicas=18 \
  -e multi_az=true \
  -e private_cluster=true \
  -e privatelink_enabled=true \
  -e enable_fips=true \
  -e enable_etcd_encryption=true \
  -e dedicated_admin_user=admin@company.com \
  --tags "cluster"
```

### Custom Network Configuration

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=test \
  -e machine_cidr=10.1.0.0/16 \
  -e service_cidr=172.31.0.0/16 \
  -e pod_cidr=10.129.0.0/14 \
  -e host_prefix=24 \
  --tags "cluster"
```

## Variable Override Methods

### 1. Command Line Variables (Highest Priority)

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e openshift_version=4.17.0 \
  -e aws_region=us-west-2
```

### 2. Extra Variables File

Create a variables file:
```yaml
# cluster-overrides.yml
target_environment: prod
cluster_name_prefix: enterprise-rosa
compute_nodes: 12
compute_machine_type: m5.8xlarge
multi_az: true
private_cluster: true
enable_fips: true
```

Execute with variables file:
```bash
ansible-playbook playbooks/main.yml \
  -e @cluster-overrides.yml \
  --tags "cluster"
```

### 3. Environment-Specific Config Override

```bash
# Override environment config at runtime
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e cluster_name_prefix=custom-dev-cluster \
  -e compute_nodes=4 \
  --tags "cluster"
```

### 4. JSON Format Variables

```bash
ansible-playbook playbooks/main.yml \
  -e '{"target_environment":"prod","compute_nodes":8,"multi_az":true}' \
  --tags "cluster"
```

## Environment-Specific Execution

### Development Environment

```bash
# Minimal development cluster
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e compute_nodes=2 \
  -e compute_machine_type=m5.large \
  -e enable_autoscaling=false \
  --tags "cluster"
```

### Test Environment

```bash
# Test environment with some production features
ansible-playbook playbooks/main.yml \
  -e target_environment=test \
  -e compute_nodes=3 \
  -e compute_machine_type=m5.xlarge \
  -e multi_az=true \
  -e enable_etcd_encryption=true \
  --tags "cluster"
```

### Production Environment

```bash
# Full production cluster
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e compute_nodes=9 \
  -e compute_machine_type=m5.2xlarge \
  -e multi_az=true \
  -e private_cluster=true \
  -e enable_fips=true \
  -e enable_etcd_encryption=true \
  --tags "cluster"
```

## Tags and Selective Execution

### Available Tags

| Tag | Description |
|-----|-------------|
| `cluster` | Execute all cluster tasks |
| `cluster-check` | Only check existing clusters |
| `cluster-setup` | Account roles and OIDC setup |
| `cluster-create` | Cluster creation only |
| `cluster-monitor` | Status monitoring only |
| `cluster-config` | Access configuration only |
| `cluster-env` | Environment file updates only |

### Selective Task Execution

```bash
# Only check if cluster exists
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  --tags "cluster-check"

# Only create account roles and OIDC
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  --tags "cluster-setup"

# Skip monitoring (for faster execution)
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e wait_for_cluster_ready=false \
  --tags "cluster" \
  --skip-tags "cluster-monitor"
```

## Advanced Configuration

### Identity Provider Configuration

#### GitHub Integration

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e identity_provider.enabled=true \
  -e identity_provider.type=github \
  -e identity_provider.name=github-enterprise \
  -e identity_provider.client_id=your-github-client-id \
  -e identity_provider.client_secret=your-github-client-secret \
  -e identity_provider.organizations='["company-org"]' \
  --tags "cluster"
```

#### Google SSO Integration

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e identity_provider.enabled=true \
  -e identity_provider.type=google \
  -e identity_provider.name=google-sso \
  -e identity_provider.client_id=your-google-client-id \
  -e identity_provider.client_secret=your-google-client-secret \
  -e identity_provider.hosted_domain=company.com \
  --tags "cluster"
```

### Custom Timeout Configuration

```bash
# Extend timeout for large clusters
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e cluster_creation_timeout_minutes=90 \
  --tags "cluster"
```

### Skip Certain Features

```bash
# Skip admin user creation
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e create_admin_user=false \
  --tags "cluster"

# Skip cluster readiness wait
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e wait_for_cluster_ready=false \
  --tags "cluster"
```

## Dry Run and Validation

### Check Mode (Dry Run)

```bash
# Dry run to see what would be executed
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  --tags "cluster" \
  --check
```

### Verbose Output

```bash
# Debug mode with verbose output
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  --tags "cluster" \
  -vvv
```

## Variable Precedence Order

Variables are applied in the following order (highest to lowest priority):

1. **Command line variables** (`-e key=value`)
2. **Extra variables files** (`-e @file.yml`)
3. **Environment-specific config** (`environments/{env}/cluster-config.yml`)
4. **Role defaults** (`defaults/main.yml`)
5. **Role variables** (`vars/cluster-variables.yml`)

## Output Files

After successful execution, the role generates:

- `environments/{env}/.env` - Updated environment variables
- `environments/{env}/cluster-info-{env}.md` - Cluster summary
- `environments/{env}/connect-{env}.sh` - Connection script
- `cluster-inventory.txt` - Global cluster inventory

## Troubleshooting

### Common Issues and Solutions

#### Variable Override Not Working

```bash
# Verify variable precedence
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e debug_variables=true \
  --tags "cluster-check"
```

#### Cluster Creation Timeout

```bash
# Increase timeout
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e cluster_creation_timeout_minutes=120 \
  --tags "cluster"
```

#### Network Configuration Conflicts

```bash
# Use different CIDR ranges
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e machine_cidr=10.10.0.0/16 \
  -e service_cidr=172.40.0.0/16 \
  -e pod_cidr=10.140.0.0/14 \
  --tags "cluster"
```

### Debug Commands

```bash
# Check current cluster status
rosa describe cluster rosa-cluster-dev

# List account roles
rosa list account-roles

# Verify OIDC configuration
rosa list oidc-config

# Check AWS credentials
aws sts get-caller-identity
```

## Examples for Different Use Cases

### Minimal Development Setup

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=dev \
  -e cluster_name_prefix=dev-cluster \
  -e compute_nodes=1 \
  -e compute_machine_type=m5n.large \
  -e enable_autoscaling=false \
  -e multi_az=false \
  --tags "cluster"
```

### High Availability Production Setup

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=prod \
  -e cluster_name_prefix=prod-ha-cluster \
  -e compute_nodes=9 \
  -e compute_machine_type=m5n.4xlarge \
  -e enable_autoscaling=true \
  -e min_replicas=9 \
  -e max_replicas=27 \
  -e multi_az=true \
  -e private_cluster=true \
  -e enable_fips=true \
  -e enable_etcd_encryption=true \
  --tags "cluster"
```

### Quick Cluster for Testing

```bash
ansible-playbook playbooks/main.yml \
  -e target_environment=test \
  -e cluster_name_prefix=quick-test \
  -e compute_nodes=2 \
  -e wait_for_cluster_ready=false \
  --tags "cluster" \
  --skip-tags "cluster-monitor,cluster-config"
```

---

**Note**: Always test variable overrides in development environment before applying to production. Use `--check` mode for dry runs to validate configuration changes.