# Full Role Execution Guide

## Overview
This guide walks you through executing the complete CF-DB role, which deploys the entire Aurora PostgreSQL infrastructure in a single command. This includes all components: private subnets, NAT Gateway, security groups, and Aurora cluster.

## Prerequisites

### ✅ Pre-execution Checklist
- [ ] Complete role implementation finished (following all docs/01-05 guides)
- [ ] All individual task files created and tested
- [ ] Environment configuration files created (dev/test/prod)
- [ ] AWS CLI configured with 'svktek' profile
- [ ] All required AWS permissions verified
- [ ] VPC and public subnet exist and are available

### 🔍 Verify Prerequisites
```bash
# 1. Verify role structure is complete
ls -la roles/cf-db/tasks/
# Expected: main.yml, private_subnets.yml, nat_gateway.yml, security_groups.yml, db_cluster.yml

# 2. Verify environment configurations exist
ls -la environments/dev/cf-db.yml environments/test/cf-db.yml environments/prod/cf-db.yml
# Expected: All three files should exist

# 3. Test AWS connectivity and permissions
aws sts get-caller-identity --profile svktek
aws ec2 describe-vpcs --vpc-ids vpc-0642a6fba47ae2a28 --profile svktek --region us-west-1
aws rds describe-db-clusters --profile svktek --region us-west-1
# Expected: All commands should complete without errors

# 4. Verify playbook syntax
ansible-playbook playbooks/main.yml --syntax-check
# Expected: "playbook: playbooks/main.yml"
```

## Execution Strategies

### Strategy 1: Complete Infrastructure Deployment (Recommended)
**Best for**: Production deployment, complete environment setup

```bash
# Execute entire CF-DB role
ansible-playbook playbooks/main.yml -t cf-db
```

### Strategy 2: Environment-Specific Deployment
**Best for**: Deploying to specific environments with custom configurations

```bash
# Deploy to development environment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev

# Deploy to test environment  
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=test

# Deploy to production environment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=prod
```

### Strategy 3: Dry Run First (Highly Recommended)
**Best for**: Verification before actual deployment

```bash
# Execute in check mode to see what would be created
ansible-playbook playbooks/main.yml -t cf-db --check -v
```

## Step-by-Step Full Deployment

### Step 1: Pre-deployment Validation
```bash
# Navigate to project root
cd /path/to/your/ansible/project

# Validate syntax
ansible-playbook playbooks/main.yml --syntax-check

# Check mode execution (dry run)
ansible-playbook playbooks/main.yml -t cf-db --check -v
```

### Step 2: Execute Full Role
```bash
# Execute complete CF-DB role for development environment
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev -v
```

**💡 What to Expect:**
- **Duration**: 15-25 minutes total
- **Task Order**: Private Subnets → NAT Gateway → Security Groups → Aurora Cluster
- **Most Time-Consuming**: Aurora cluster creation (10-15 minutes)

### Step 3: Monitor Deployment Progress

#### Option A: Real-time AWS Monitoring
```bash
# Terminal 1: Monitor subnet creation
watch "aws ec2 describe-subnets --filters 'Name=tag:Component,Values=Database' --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,State,AvailabilityZone]' --output table"

# Terminal 2: Monitor NAT Gateway
watch "aws ec2 describe-nat-gateways --filter 'Name=tag:Environment,Values=dev' --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State]' --output table"

# Terminal 3: Monitor Aurora cluster
watch "aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[*].[DBClusterIdentifier,Status]' --output table"
```

#### Option B: Ansible Verbose Output
```bash
# Run with verbose output to see detailed progress
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev -vv
```

## Expected Execution Flow

### 📋 Task Execution Sequence

#### Phase 1: Environment Setup (1-2 minutes)
```
TASK [cf-db : Load environment-specific configuration]
TASK [cf-db : Validate required variables]
TASK [cf-db : Display role execution summary]
```

#### Phase 2: Private Subnets (1-2 minutes)  
```
TASK [cf-db : Create private subnets]
  → Validate VPC exists
  → Create 2 private subnets across AZs
  → Extract subnet IDs
  → Display creation results
```

#### Phase 3: NAT Gateway (3-5 minutes)
```
TASK [cf-db : Setup NAT Gateway and routing]
  → Check private subnet dependencies
  → Allocate Elastic IP
  → Create NAT Gateway
  → Create route table with NAT route
  → Associate private subnets
```

#### Phase 4: Security Groups (30 seconds - 1 minute)
```
TASK [cf-db : Create security groups]
  → Validate VPC for security group creation
  → Create Aurora DB security group
  → Configure cross-VPC access rules
  → Display security group information
```

#### Phase 5: Aurora Cluster (10-15 minutes)
```
TASK [cf-db : Create Aurora DB cluster]
  → Validate dependencies (subnets, security groups)
  → Create DB subnet group
  → Create Aurora PostgreSQL cluster
  → Create writer instance
  → Create reader instance
  → Display cluster information
```

## Expected Results

### ✅ Successful Execution Output
```
PLAY RECAP *********************************************************
localhost                  : ok=35   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 📊 Complete Infrastructure Created

#### 1. Networking Components
```bash
# Private Subnets
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,State]' --output table

# NAT Gateway
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[*].[NatGatewayId,State,NatGatewayAddresses[0].PublicIp]' --output table

# Security Groups
aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'SecurityGroups[*].[GroupId,GroupName]' --output table
```

#### 2. Database Components
```bash
# Aurora Cluster
aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[?starts_with(DBClusterIdentifier, `cf-aurora-pg-cluster-dev`)].[DBClusterIdentifier,Status,Endpoint,ReaderEndpoint]' --output table

# Aurora Instances  
aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, `cf-aurora-pg`) && contains(DBInstanceIdentifier, `dev`)].[DBInstanceIdentifier,DBInstanceStatus,AvailabilityZone,DBInstanceClass]' --output table
```

### 🎯 Complete Infrastructure Summary

**Expected Infrastructure (Development Environment):**
- ✅ 2x Private Subnets (10.0.2.0/24, 10.0.3.0/24) across us-west-1a and us-west-1c
- ✅ 1x NAT Gateway with Elastic IP in public subnet
- ✅ 1x Route Table with default route to NAT Gateway
- ✅ 1x Security Group with cross-VPC access rules (ports 5432)
- ✅ 1x Aurora PostgreSQL Cluster (cf-aurora-pg-cluster-dev)
- ✅ 1x Aurora Writer Instance (cf-aurora-pg-writer-dev) - db.t3.medium
- ✅ 1x Aurora Reader Instance (cf-aurora-pg-reader-dev) - db.t3.medium
- ✅ 1x DB Subnet Group spanning both private subnets

## Verification and Testing

### 🔍 Complete Infrastructure Verification

#### 1. End-to-End Connectivity Test
```bash
# Get Aurora endpoints
WRITER_ENDPOINT=$(aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[?starts_with(DBClusterIdentifier, `cf-aurora-pg-cluster-dev`)].Endpoint' --output text)
READER_ENDPOINT=$(aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[?starts_with(DBClusterIdentifier, `cf-aurora-pg-cluster-dev`)].ReaderEndpoint' --output text)

echo "Writer Endpoint: $WRITER_ENDPOINT"
echo "Reader Endpoint: $READER_ENDPOINT"
```

#### 2. Cross-VPC Access Verification
```bash
# Verify security group allows cross-VPC access
aws ec2 describe-security-groups --filters "Name=group-name,Values=cf-aurora-db-sg-dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpRanges[*].CidrIp]' --output table
# Expected: Port 5432 access from 10.0.0.0/16, 172.16.0.0/16, 192.168.0.0/16
```

#### 3. High Availability Verification
```bash
# Verify multi-AZ deployment
aws rds describe-db-instances --profile svktek --region us-west-1 --query 'DBInstances[?starts_with(DBInstanceIdentifier, `cf-aurora-pg`) && contains(DBInstanceIdentifier, `dev`)].[DBInstanceIdentifier,AvailabilityZone,DBInstanceStatus]' --output table
# Expected: Writer and reader in different AZs, both available
```

### 📋 Complete Success Checklist
- [ ] All Ansible tasks completed without failures
- [ ] 2 private subnets created across multiple AZs
- [ ] NAT Gateway operational with public IP
- [ ] Route table configured for internet access
- [ ] Security group allows cross-VPC access on port 5432
- [ ] Aurora cluster status = 'available'
- [ ] Aurora writer instance status = 'available'  
- [ ] Aurora reader instance status = 'available'
- [ ] All resources properly tagged
- [ ] Database endpoints accessible

## Environment-Specific Considerations

### Development Environment (dev)
```bash
# Deploy development infrastructure
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=dev

# Expected characteristics:
# - db.t3.medium instances (cost-effective)
# - 7-day backup retention
# - No deletion protection
# - Estimated cost: ~$50-100/month
```

### Test Environment (test)
```bash
# Deploy test infrastructure
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=test

# Expected characteristics:
# - db.r6g.large instances (better performance)
# - 14-day backup retention
# - Deletion protection enabled
# - Estimated cost: ~$200-400/month
```

### Production Environment (prod)
```bash
# Deploy production infrastructure (be careful!)
ansible-playbook playbooks/main.yml -t cf-db -e cf_db_environment=prod

# Expected characteristics:
# - db.r6g.xlarge instances (high performance)
# - 30-day backup retention
# - Full deletion protection
# - Estimated cost: ~$500-1000/month
```

## Troubleshooting

### ❌ Common Issues During Full Deployment

#### 1. Partial Deployment Failure
**Problem**: One task fails, leaving infrastructure partially deployed

**Solution**:
```bash
# Check what was created
aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" --profile svktek --region us-west-1
aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1
aws rds describe-db-clusters --profile svktek --region us-west-1

# Continue deployment from where it failed
ansible-playbook playbooks/main.yml -t cf-db --start-at-task "Create Aurora DB cluster"
```

#### 2. Aurora Cluster Timeout
**Problem**: Aurora cluster creation times out

**Solution**:
```bash
# Check cluster status manually
aws rds describe-db-clusters --profile svktek --region us-west-1

# If cluster is still creating, wait and check instances
aws rds describe-db-instances --profile svktek --region us-west-1

# If needed, run only the remaining tasks
ansible-playbook playbooks/main.yml -t db-cluster
```

#### 3. Resource Limit Exceeded
**Problem**: AWS service limits exceeded during deployment

**Solution**:
```bash
# Check current resource usage
aws ec2 describe-account-attributes --profile svktek --region us-west-1
aws rds describe-account-attributes --profile svktek --region us-west-1

# Request limit increases through AWS Console if needed
```

### 🔧 Debug Commands for Full Deployment
```bash
# Maximum verbosity for troubleshooting
ansible-playbook playbooks/main.yml -t cf-db -vvv

# Run specific phases
ansible-playbook playbooks/main.yml -t networking    # Subnets + NAT Gateway
ansible-playbook playbooks/main.yml -t security     # Security Groups
ansible-playbook playbooks/main.yml -t database     # Aurora Cluster

# Check specific task
ansible-playbook playbooks/main.yml -t cf-db --start-at-task "Create Aurora PostgreSQL Cluster"
```

## Post-Deployment Actions

### ✅ Success Documentation
Create comprehensive execution log:

```bash
# Gather all resource information
SUBNET_INFO=$(aws ec2 describe-subnets --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output text)
NAT_INFO=$(aws ec2 describe-nat-gateways --filter "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'NatGateways[0].[NatGatewayId,NatGatewayAddresses[0].PublicIp]' --output text)
SG_INFO=$(aws ec2 describe-security-groups --filters "Name=tag:Component,Values=Database" "Name=tag:Environment,Values=dev" --profile svktek --region us-west-1 --query 'SecurityGroups[0].[GroupId,GroupName]' --output text)
CLUSTER_INFO=$(aws rds describe-db-clusters --profile svktek --region us-west-1 --query 'DBClusters[?starts_with(DBClusterIdentifier, `cf-aurora-pg-cluster-dev`)].[DBClusterIdentifier,Endpoint,ReaderEndpoint]' --output text)

# Create comprehensive execution log
cat > executions/dev/full-role-execution-$(date +%Y-%m-%d).md << EOF
# CF-DB Full Role Execution Log

**Date**: $(date)
**Environment**: dev
**Executed By**: [Your Name]
**Status**: SUCCESS
**Total Duration**: ~20 minutes

## Complete Infrastructure Deployed

### Networking Components
- **Private Subnets**: 
$SUBNET_INFO
- **NAT Gateway**: $NAT_INFO
- **Security Group**: $SG_INFO

### Database Components
- **Aurora Cluster**: $CLUSTER_INFO
- **Instance Class**: db.t3.medium (writer + reader)
- **Backup Retention**: 7 days
- **Multi-AZ**: Yes (us-west-1a, us-west-1c)

## Connection Information
- **Writer Endpoint**: $(echo $CLUSTER_INFO | cut -f2)
- **Reader Endpoint**: $(echo $CLUSTER_INFO | cut -f3)
- **Database Name**: cfdb_dev
- **Username**: cfadmin
- **Port**: 5432

## Cross-VPC Access
- Current VPC: 10.0.0.0/16
- ROSA Cluster VPC: 172.16.0.0/16  
- Additional VPC: 192.168.0.0/16

## Monthly Cost Estimate
- Aurora Cluster: ~\$50-75
- NAT Gateway: ~\$45
- EIP: ~\$3.65
- **Total**: ~\$98-123/month

## Post-Deployment Tasks
- [ ] Test database connectivity
- [ ] Configure application connection strings
- [ ] Set up monitoring and alerting
- [ ] Configure backup verification
- [ ] Document connection details for applications

## Notes
- Full infrastructure deployed successfully
- Cross-VPC access configured for ROSA integration
- High availability across multiple AZs
- Ready for application deployment
EOF
```

### 🔄 Next Steps After Deployment

#### 1. Database Configuration
```bash
# Connect to database and create application schemas
# psql -h $(echo $CLUSTER_INFO | cut -f2) -U cfadmin -d cfdb_dev -p 5432

# Create application users and permissions
# Setup database schemas and initial data
```

#### 2. Application Integration
```bash
# Update application configurations with new endpoints
# Test connectivity from ROSA clusters
# Configure database connection pooling
```

#### 3. Monitoring Setup
```bash
# Enable RDS Performance Insights
# Configure CloudWatch alarms
# Set up backup monitoring
```

## Clean Up (If Needed)

⚠️ **WARNING**: This will destroy all created infrastructure

```bash
# Clean up in reverse order (Aurora → Security Groups → NAT Gateway → Subnets)
# This requires manual steps as the role doesn't include cleanup tasks

# 1. Delete Aurora instances and cluster
# 2. Delete security groups  
# 3. Delete NAT Gateway
# 4. Release Elastic IP
# 5. Delete route table
# 6. Delete private subnets
```

## Key Takeaways

✅ **Full Role Execution Benefits:**
- **Complete Infrastructure**: All components deployed together
- **Dependency Management**: Automatic resolution of inter-task dependencies
- **Consistency**: Uniform configuration across all components
- **Efficiency**: Single command deployment
- **Validation**: Comprehensive checks at each phase

✅ **Production Readiness:**
- **High Availability**: Multi-AZ deployment across availability zones
- **Security**: Private subnets with controlled cross-VPC access
- **Scalability**: Aurora auto-scaling and read replicas
- **Backup**: Automated backup and point-in-time recovery
- **Monitoring**: CloudWatch integration and performance insights

The full role execution provides a complete, production-ready Aurora PostgreSQL infrastructure that supports cross-VPC access for ROSA clusters while maintaining security and high availability best practices.