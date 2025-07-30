# CF-DB Role - Complete Newbie Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Role Structure](#role-structure)
4. [Step-by-Step Implementation Guide](#step-by-step-implementation-guide)
5. [Testing and Validation](#testing-and-validation)
6. [Troubleshooting](#troubleshooting)

## Overview

This guide will help you create the CF-DB Ansible role from scratch. The role creates an Aurora PostgreSQL cluster with cross-VPC access capability for ROSA (Red Hat OpenShift Service on AWS) environments.

### What This Role Does
- Creates private subnets across multiple Availability Zones
- Sets up NAT Gateway and routing for internet access
- Configures security groups for cross-VPC database access
- Deploys Aurora PostgreSQL cluster with writer and reader instances

### Architecture
```
┌─────────────────────────────────────────────────────────┐
│                        VPC                              │
│  ┌─────────────────┐  ┌─────────────────┐             │
│  │ Private Subnet  │  │ Private Subnet  │             │
│  │   us-west-1a    │  │   us-west-1c    │             │
│  │                 │  │                 │             │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │             │
│  │ │Aurora Writer│ │  │ │Aurora Reader│ │             │
│  │ └─────────────┘ │  │ └─────────────┘ │             │
│  └─────────────────┘  └─────────────────┘             │
│           │                     │                      │
│  ┌─────────────────────────────────────────┐           │
│  │        Aurora PostgreSQL Cluster        │           │
│  │     Cross-VPC Security Groups          │           │
│  └─────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘
             │
    ┌─────────────────┐
    │   NAT Gateway   │
    │ (Public Subnet) │
    └─────────────────┘
             │
        Internet Gateway
```

## Prerequisites

### Required Tools
- Ansible 2.9+
- AWS CLI configured with appropriate credentials
- Python boto3 library
- ansible-collection amazon.aws

### AWS Requirements
- AWS account with appropriate permissions
- Existing VPC with public subnet (for NAT Gateway)
- AWS profile configured (e.g., 'svktek')

### Permissions Required
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "rds:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Role Structure

The final role structure will look like this:
```
roles/cf-db/
├── docs/
│   ├── README.md (this file)
│   ├── 01-role-setup.md
│   ├── 02-defaults-configuration.md
│   ├── 03-environment-configuration.md
│   ├── 04-private-subnets-task.md
│   ├── 05-nat-gateway-task.md
│   ├── 06-security-groups-task.md
│   ├── 07-aurora-cluster-task.md
│   ├── 08-main-orchestration.md
│   └── 09-testing-validation.md
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── private_subnets.yml
│   ├── nat_gateway.yml
│   ├── security_groups.yml
│   └── db_cluster.yml
├── vars/
│   └── main.yml
└── executions/
    └── dev/
        └── execution-log-YYYY-MM-DD.md
```

## Step-by-Step Implementation Guide

### Phase 1: Initial Setup
1. **[Role Setup](01-role-setup.md)** - Create basic role structure and directories
2. **[Defaults Configuration](02-defaults-configuration.md)** - Define default variables and settings

### Phase 2: Configuration
3. **[Environment Configuration](03-environment-configuration.md)** - Create environment-specific configurations

### Phase 3: Task Implementation
4. **[Private Subnets Task](04-private-subnets-task.md)** - Create multi-AZ private subnets
5. **[NAT Gateway Task](05-nat-gateway-task.md)** - Setup NAT Gateway and routing
6. **[Security Groups Task](06-security-groups-task.md)** - Configure cross-VPC security groups
7. **[Aurora Cluster Task](07-aurora-cluster-task.md)** - Deploy Aurora PostgreSQL cluster

### Phase 4: Integration
8. **[Main Orchestration](08-main-orchestration.md)** - Create main task orchestration
9. **[Testing & Validation](09-testing-validation.md)** - Test individual tasks and full role

## Quick Start Commands

Once you complete the implementation:

```bash
# Test individual tasks
ansible-playbook playbooks/main.yml -t private-subnets
ansible-playbook playbooks/main.yml -t nat-gateway  
ansible-playbook playbooks/main.yml -t security-groups
ansible-playbook playbooks/main.yml -t db-cluster

# Run complete role
ansible-playbook playbooks/main.yml -t cf-db

# Run specific networking tasks
ansible-playbook playbooks/main.yml -t networking

# Run only database tasks
ansible-playbook playbooks/main.yml -t database
```

## Expected Outcomes

After completing this guide, you will have:
- ✅ A fully functional Aurora PostgreSQL cluster
- ✅ Cross-VPC database access capability
- ✅ Multi-AZ deployment for high availability  
- ✅ Proper security group configurations
- ✅ NAT Gateway for internet access from private subnets
- ✅ Environment-specific configurations (dev/test/prod)
- ✅ Individual task execution capability
- ✅ Dependency resolution and validation

## Next Steps

1. Start with **[01-role-setup.md](01-role-setup.md)** to begin implementation
2. Follow each guide in sequence
3. Test each component as you build it
4. Refer to troubleshooting section if you encounter issues

## Support

If you encounter issues:
1. Check the troubleshooting section in each guide
2. Verify AWS credentials and permissions
3. Ensure all prerequisites are met
4. Check AWS console for resource creation status

---

**Time Estimate**: 4-6 hours for complete implementation
**Difficulty Level**: Intermediate
**Prerequisites Knowledge**: Basic Ansible, AWS fundamentals