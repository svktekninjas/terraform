# Step 1: Role Setup and Directory Structure

## Overview
This guide walks you through creating the basic directory structure and initial files for the CF-DB Ansible role.

## Prerequisites
- Basic understanding of Ansible roles
- Access to a terminal/command line
- Text editor of your choice

## Step 1.1: Create Role Directory Structure

### 1. Navigate to your roles directory
```bash
cd /path/to/your/ansible/project/roles
```

### 2. Create the cf-db role directory
```bash
mkdir -p cf-db
cd cf-db
```

### 3. Create the standard Ansible role subdirectories
```bash
mkdir -p {tasks,defaults,vars,handlers,templates,files,meta,docs,executions}
```

### 4. Create environment-specific directories
```bash
mkdir -p ../../environments/{dev,test,prod}
```

### 5. Verify the structure
```bash
tree -L 2
```

Expected output:
```
cf-db/
├── defaults/
├── docs/
├── executions/
├── files/
├── handlers/
├── meta/
├── tasks/
├── templates/
├── tests/
└── vars/
```

## Step 1.2: Create Initial Files

### 1. Create the main task file
```bash
touch tasks/main.yml
```

### 2. Create individual task files
```bash
touch tasks/private_subnets.yml
touch tasks/nat_gateway.yml
touch tasks/security_groups.yml
touch tasks/db_cluster.yml
```

### 3. Create configuration files
```bash
touch defaults/main.yml
touch vars/main.yml
```

### 4. Create environment configuration files
```bash
touch ../../environments/dev/cf-db.yml
touch ../../environments/test/cf-db.yml
touch ../../environments/prod/cf-db.yml
```

## Step 1.3: Create Basic Meta Information

### 1. Create meta/main.yml
```bash
cat > meta/main.yml << 'EOF'
---
galaxy_info:
  author: Infrastructure Team
  description: Aurora PostgreSQL cluster with cross-VPC access for ROSA
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: Amazon
      versions:
        - all
  galaxy_tags:
    - aws
    - rds
    - aurora
    - postgresql
    - rosa
    - database

dependencies: []
EOF
```

### 2. Create a basic README for the role
```bash
cat > README.md << 'EOF'
# CF-DB Role

Creates Aurora PostgreSQL cluster with cross-VPC access for ROSA environments.

## Features
- Multi-AZ private subnets
- NAT Gateway and routing
- Cross-VPC security groups
- Aurora PostgreSQL cluster (writer + reader)

## Usage
```yaml
- name: Deploy Aurora PostgreSQL cluster
  include_role:
    name: cf-db
  vars:
    cf_db_environment: dev
```

## Tags
- `cf-db`: Run entire role
- `private-subnets`: Create private subnets only
- `nat-gateway`: Setup NAT Gateway only
- `security-groups`: Create security groups only
- `db-cluster`: Deploy database cluster only
EOF
```

## Step 1.4: Create Execution Tracking Structure

### 1. Create execution directory for dev environment
```bash
mkdir -p executions/dev
```

### 2. Create execution log template
```bash
cat > executions/dev/execution-template.md << 'EOF'
# CF-DB Role Execution Log

**Date**: YYYY-MM-DD
**Environment**: dev
**Executed By**: [Your Name]
**Ansible Version**: [version]

## Pre-execution Checklist
- [ ] AWS credentials configured
- [ ] VPC and public subnet exist
- [ ] Required permissions verified
- [ ] Environment variables set

## Task Execution Results

### Task 1: Private Subnets
- **Status**: [ ] Success / [ ] Failed
- **Duration**: ___ minutes
- **Resources Created**:
  - Subnet 1: subnet-xxxxxxxxx (us-west-1a)
  - Subnet 2: subnet-xxxxxxxxx (us-west-1c)
- **Notes**: 

### Task 2: NAT Gateway
- **Status**: [ ] Success / [ ] Failed
- **Duration**: ___ minutes
- **Resources Created**:
  - NAT Gateway: nat-xxxxxxxxx
  - Elastic IP: eip-xxxxxxxxx
  - Route Table: rtb-xxxxxxxxx
- **Notes**: 

### Task 3: Security Groups
- **Status**: [ ] Success / [ ] Failed
- **Duration**: ___ minutes
- **Resources Created**:
  - Security Group: sg-xxxxxxxxx
- **Notes**: 

### Task 4: Aurora Cluster
- **Status**: [ ] Success / [ ] Failed
- **Duration**: ___ minutes
- **Resources Created**:
  - DB Subnet Group: cf-private-db-subnet-group-dev
  - Aurora Cluster: cf-aurora-pg-cluster-dev
  - Writer Instance: cf-aurora-pg-writer-dev
  - Reader Instance: cf-aurora-pg-reader-dev
- **Notes**: 

## Connection Details
- **Writer Endpoint**: 
- **Reader Endpoint**: 
- **Database Name**: cfdb_dev
- **Username**: cfadmin
- **Port**: 5432

## Post-execution Verification
- [ ] Cluster is accessible
- [ ] Writer instance is available
- [ ] Reader instance is available
- [ ] Security groups allow access
- [ ] Cross-VPC connectivity tested

## Issues Encountered
[Document any issues and their resolutions]

## Total Execution Time
**Start**: [timestamp]
**End**: [timestamp]
**Duration**: ___ minutes
EOF
```

## Step 1.5: Verify Setup

### 1. Check directory structure
```bash
find . -type f -name "*.yml" -o -name "*.md" | sort
```

Expected output:
```
./README.md
./defaults/main.yml
./executions/dev/execution-template.md
./meta/main.yml
./tasks/db_cluster.yml
./tasks/main.yml
./tasks/nat_gateway.yml
./tasks/private_subnets.yml
./tasks/security_groups.yml
./vars/main.yml
```

### 2. Check environment files
```bash
ls -la ../../environments/dev/cf-db.yml
ls -la ../../environments/test/cf-db.yml
ls -la ../../environments/prod/cf-db.yml
```

## Troubleshooting

### Common Issues

1. **Permission denied when creating directories**
   ```bash
   # Solution: Check directory permissions
   ls -la ../
   # Ensure you have write permissions
   ```

2. **Files not created properly**
   ```bash
   # Solution: Verify files exist and have content
   ls -la tasks/
   cat meta/main.yml
   ```

3. **Environment directories not accessible**
   ```bash
   # Solution: Check relative path
   pwd
   ls -la ../../environments/
   ```

## Next Steps

1. ✅ Basic role structure created
2. ✅ Initial files created
3. ✅ Meta information configured
4. ✅ Execution tracking setup

**Next**: Continue to **[02-defaults-configuration.md](02-defaults-configuration.md)** to configure default variables.

## Summary

You have successfully:
- Created the complete directory structure for the cf-db role
- Set up initial task files
- Created meta information
- Established execution tracking structure
- Verified the setup

The role is now ready for configuration and implementation.