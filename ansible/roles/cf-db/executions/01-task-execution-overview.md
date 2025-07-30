# Task Execution Overview

## Overview
This guide provides a comprehensive overview of executing CF-DB role tasks. It covers prerequisites, execution patterns, and general best practices for newbies.

## Prerequisites Checklist

### 🔧 Environment Setup
```bash
# Verify Ansible installation
ansible --version
# Expected: ansible [core 2.12.0] or higher

# Verify AWS CLI
aws --version
# Expected: aws-cli/2.x.x or higher

# Test AWS profile configuration
aws sts get-caller-identity --profile svktek
# Expected: Should return account info without errors
```

### 📁 Project Structure Verification
```bash
# Navigate to project root
cd /path/to/your/ansible/project

# Verify role structure exists
ls -la roles/cf-db/
# Expected: defaults/ docs/ executions/ tasks/ vars/

# Verify environment configurations exist
ls -la environments/dev/cf-db.yml environments/test/cf-db.yml environments/prod/cf-db.yml
# Expected: All three files should exist
```

### 🔑 AWS Permissions Verification
```bash
# Test EC2 permissions
aws ec2 describe-vpcs --profile svktek --region us-west-1
# Expected: Should list VPCs without permission errors

# Test RDS permissions
aws rds describe-db-clusters --profile svktek --region us-west-1
# Expected: Should complete without permission errors (may return empty list)
```

## Execution Patterns

### 1. Individual Task Execution
**Best for**: Learning, debugging, incremental deployment

```bash
# Pattern: ansible-playbook playbooks/main.yml -t <task-tag>
ansible-playbook playbooks/main.yml -t private-subnets
ansible-playbook playbooks/main.yml -t nat-gateway
ansible-playbook playbooks/main.yml -t security-groups
ansible-playbook playbooks/main.yml -t db-cluster
```

**Benefits**:
- Easy to debug issues
- Faster execution for single components
- Good for learning each component
- Can run tasks independently

### 2. Sequential Task Execution
**Best for**: Controlled deployment, understanding dependencies

```bash
# Execute tasks in dependency order
ansible-playbook playbooks/main.yml -t private-subnets
# Wait and verify success before proceeding
ansible-playbook playbooks/main.yml -t nat-gateway
# Wait and verify success before proceeding
ansible-playbook playbooks/main.yml -t security-groups
# Wait and verify success before proceeding
ansible-playbook playbooks/main.yml -t db-cluster
```

### 3. Multiple Task Execution
**Best for**: Deploying related components together

```bash
# Execute networking tasks together
ansible-playbook playbooks/main.yml -t networking

# Execute database-related tasks together
ansible-playbook playbooks/main.yml -t database

# Execute security-related tasks
ansible-playbook playbooks/main.yml -t security
```

### 4. Complete Role Execution
**Best for**: Full deployment, production deployment

```bash
# Execute entire role
ansible-playbook playbooks/main.yml -t cf-db

# Execute with specific environment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev
```

## Execution Safety

### 1. Always Start with Check Mode
```bash
# Dry run - shows what would be changed without making changes
ansible-playbook playbooks/main.yml -t private-subnets --check

# Dry run with verbose output
ansible-playbook playbooks/main.yml -t private-subnets --check -v
```

### 2. Validate Syntax First
```bash
# Check playbook syntax
ansible-playbook playbooks/main.yml --syntax-check

# Check specific environment configuration
ansible-playbook playbooks/main.yml --syntax-check -e cf_db_environment=dev
```

### 3. Start with Development Environment
```bash
# Always test in dev first
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev

# Only proceed to test after dev success
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=test

# Production only after thorough testing
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=prod
```

## Execution Monitoring

### 1. Verbose Output Levels
```bash
# Standard output
ansible-playbook playbooks/main.yml -t private-subnets

# Verbose output (recommended for learning)
ansible-playbook playbooks/main.yml -t private-subnets -v

# Very verbose (detailed task info)
ansible-playbook playbooks/main.yml -t private-subnets -vv

# Debug level (maximum detail)
ansible-playbook playbooks/main.yml -t private-subnets -vvv
```

### 2. Real-time AWS Monitoring
```bash
# Monitor subnet creation
watch "aws ec2 describe-subnets --filters 'Name=tag:Component,Values=Database' --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,AvailabilityZone]' --output table"

# Monitor NAT Gateway creation
watch "aws ec2 describe-nat-gateways --filter 'Name=tag:Environment,Values=dev' --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State]' --output table"

# Monitor Aurora cluster creation
watch "aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[*].[DBClusterIdentifier,Status]' --output table"
```

## Error Handling

### 1. Common Error Patterns
```bash
# Permission denied errors
TASK [cf-db : Create private subnets] ***
fatal: [localhost]: FAILED! => {"msg": "An error occurred (UnauthorizedOperation)"}

# Solution: Check AWS credentials and permissions
aws sts get-caller-identity --profile svktek
```

```bash
# Resource already exists errors
TASK [cf-db : Create Security Group] ***
fatal: [localhost]: FAILED! => {"msg": "group sg-xxxxxxxxx already exists"}

# Solution: Tasks are idempotent, this shouldn't happen. Check for naming conflicts.
```

```bash
# CIDR block conflicts
TASK [cf-db : Create private subnets] ***
fatal: [localhost]: FAILED! => {"msg": "The CIDR '10.0.2.0/24' conflicts with another subnet"}

# Solution: Check existing subnets and adjust CIDR blocks
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0642a6fba47ae2a28" --profile svktek
```

### 2. Recovery Strategies

#### Partial Deployment Recovery
```bash
# If execution fails partway through, check what was created
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1

# Continue from where it left off
ansible-playbook playbooks/main.yml -t nat-gateway,security-groups,db-cluster
```

#### Complete Rollback (if needed)
```bash
# Identify resources to clean up
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1

# Clean up in reverse order (Aurora → Security Groups → NAT Gateway → Subnets)
# Note: Manual cleanup may be required as role doesn't include deletion tasks
```

## Environment-Specific Considerations

### Development Environment
```bash
# Quick deployment for testing
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev

# Expected resources:
# - 2x private subnets (t3.medium instances)
# - 1x NAT Gateway 
# - 1x security group
# - 1x Aurora cluster with writer + reader
```

### Test Environment
```bash
# More robust deployment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=test

# Expected resources:
# - 2x private subnets (r6g.large instances)
# - Enhanced backup retention
# - Deletion protection enabled
```

### Production Environment
```bash
# Full production deployment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=prod

# Expected resources:
# - 2x private subnets (r6g.xlarge instances)
# - Maximum backup retention
# - Full deletion protection
# - Production-grade configurations
```

## Success Indicators

### Task Completion Success
```
PLAY RECAP *********************************************************
localhost                  : ok=20   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### AWS Resource Verification
```bash
# Verify all components exist and are healthy
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,AvailabilityZone]' --output table

aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State]' --output table

aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[*].[DBClusterIdentifier,Status,Endpoint]' --output table
```

## Timing Expectations

### Individual Task Timing
- **Private Subnets**: 1-2 minutes
- **NAT Gateway**: 3-5 minutes (includes EIP allocation)
- **Security Groups**: 30 seconds - 1 minute
- **Aurora Cluster**: 10-15 minutes (cluster + instances)

### Complete Role Timing
- **Total Execution**: 15-25 minutes
- **Development**: Faster due to smaller instances
- **Production**: Slower due to larger instances and additional validation

## Next Steps

Now that you understand the execution patterns, proceed to execute individual tasks:

1. **[Private Subnets Execution](02-private-subnets-execution.md)** - Create the network foundation
2. **[NAT Gateway Execution](03-nat-gateway-execution.md)** - Enable internet access
3. **[Security Groups Execution](04-security-groups-execution.md)** - Configure access control
4. **[Aurora Cluster Execution](05-aurora-cluster-execution.md)** - Deploy the database
5. **[Full Role Execution](06-full-role-execution.md)** - Complete deployment
6. **[Validation and Testing](07-validation-and-testing.md)** - Verify everything works

## Emergency Contacts / Resources

- **AWS Support**: Check AWS Console for service health
- **Ansible Documentation**: https://docs.ansible.com/
- **AWS RDS Documentation**: https://docs.aws.amazon.com/rds/
- **Project Documentation**: `roles/cf-db/docs/` directory

---

**Remember**: Always start with development environment and verify each step before proceeding!